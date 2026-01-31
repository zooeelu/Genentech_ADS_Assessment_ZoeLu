# ------------------------------------------------------------------------------------------------
# Program: question_1_sdtm:01_create_ds_domsain.R
# Purpose: Create SDTM DS (Disposition) domain using {sdtm.oak}
# Input: pharmaverseraw::ds_raw
# Output: SDTM DS domain
# Notes: Instructions ask for DSSTDY in the final SDTM dataset but the raw DS
#        did not provide any data on reference start dates so it was left out
#        Sorry if I missed it :( but I wasn't sure how to calculate it without reference dates
# ------------------------------------------------------------------------------------------------

# Loading in required libraries
library(tidyverse)
library(sdtm.oak)
library(pharmaverseraw)

# Loading in raw data from instruction file
ds_raw <- pharmaverseraw::ds_raw
str(ds_raw)


# Loading in study controlled terminology file
study_sct <- read_csv("/Users/zoelu/Downloads/GenentechADSAssessment/GenentechADSAssessment/Question1/sdtm_ct.csv")
str(study_sct)

# -------------------------------------------------------------------------

# Adding Oak ID vars into dataset
ds_raw <- generate_oak_id_vars(
  raw_dat = ds_raw,
  pat_var = "PATNUM",
  raw_src = "DS"
)

# -------------------------------------------------------------------------
# Create eCRF-driven collected values
# Logic : If OTHERSP is NOT NULL, it drives DSTERM and DSDECOD, and sets DSCAT.
#         Otherwise use the standard collected fields IT.DSTERM / IT.DSDECOD.

ds_raw <- ds_raw %>%
  mutate(
    DSTERM_COLLECTED  = ifelse(!is.na(OTHERSP), OTHERSP, `IT.DSTERM`),
    DSDECOD_COLLECTED = ifelse(!is.na(OTHERSP), OTHERSP, `IT.DSDECOD`),
    DSCAT_COLLECTED   = ifelse(!is.na(OTHERSP), "OTHER EVENT", 
                               ifelse(`IT.DSDECOD` == "Randomized", "PROTOCOL MILESTONE", "DISPOSITION EVENT"))
  )

# -------------------------------------------------------------------------
# Map DSTERM (Topic variable)
# Logic : DSTERM = DSTERM_COLLECTED (OTHERSP overrides IT.DSTERM when NOT NULL)
ds <- assign_no_ct(
  tgt_var = "DSTERM",
  raw_dat = ds_raw,
  raw_var = "DSTERM_COLLECTED",
  id_vars = oak_id_vars()
)

# -------------------------------------------------------------------------
# Identify codelist for DSDECOD, then map using CT
# Logic : DSDECOD = CT decode of DSDECOD_COLLECTED using study_sct
cand_codelist_code <- study_sct %>%
  filter(collected_value %in% unique(ds_raw$DSDECOD_COLLECTED)) %>%
  count(codelist_code, sort = TRUE) %>%
  slice(1) %>%
  pull(codelist_code)

ds <- ds %>%
  assign_ct(
    raw_var = "DSDECOD_COLLECTED",
    raw_dat = ds_raw,
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars(),
    ct_spec = study_sct,
    ct_clst = cand_codelist_code
  )

# -------------------------------------------------------------------------
# Map DSCAT
# Logic : If OTHERSP is populated then DSCAT = "OTHER EVENT", else "DISPOSITION EVENT" 
#         DSCAT_COLLECTED derived earlier

ds <- ds %>%
  assign_no_ct(
    raw_var = "DSCAT_COLLECTED",
    raw_dat = ds_raw,
    tgt_var = "DSCAT",
    id_vars = oak_id_vars()
  )

# -------------------------------------------------------------------------
# Map STUDYID
# Logic: Map STUDY (raw) to STIDYID (target)
ds <- ds %>%
  assign_no_ct(
    raw_var = "STUDY",
    raw_dat = ds_raw,
    tgt_var = "STUDYID",
    id_vars = oak_id_vars()
  )

# -------------------------------------------------------------------------
# Map DOMAIN
# Logic : Hardcode DOMAIN as a constant "DS"
ds <- ds %>%
  hardcode_no_ct(
    raw_var = "PATNUM",
    raw_dat = ds_raw,
    tgt_var = "DOMAIN",
    tgt_val = "DS",
    id_vars = oak_id_vars()
  )

# -------------------------------------------------------------------------
# Derive USUBJID
# Logic: USUBJID = STUDY + "-" + PATNUM
ds <- ds %>% 
  left_join(
    ds_raw %>% select(all_of(oak_id_vars()), STUDY, PATNUM)
    ) %>% 
  mutate(USUBJID = paste0(STUDY, "-", PATNUM)) %>% 
  select(-c(STUDY, PATNUM))

# -------------------------------------------------------------------------
# Derive VISIT and VISITNUM
# Logic: 
#   - INSTANCE represents study timepoints and is mapped to VISIT.
#   - VISITNUM is derived only for scheduled visits (Baseline, Screening, Week XX).
#   - VISITNUM logic: Baseline = 0, Screening = -1, Week = XX
#   - Unscheduled and procedure-like INSTANCE values do not receive VISITNUM (NA).

# Check possible INSTANCE values
table(ds_raw$INSTANCE)

# Deriving Visit and VISITNUM
ds <- ds %>% 
  left_join(
    ds_raw %>% select(all_of(oak_id_vars()), INSTANCE), 
    by = oak_id_vars()
  ) %>% 
  mutate(VISIT = INSTANCE, 
         VISITNUM = case_when(
           INSTANCE == "Baseline" ~ 0, 
           str_detect(INSTANCE, "^Screening") ~ -1, 
           str_detect(INSTANCE, "^Week\\s+\\d+") ~ as.numeric(str_extract(INSTANCE, "\\d+")), 
           TRUE ~ NA_real_
         )) 

# -------------------------------------------------------------------------
# Derive DSDTC to ISO 8601 format
# Logic : Mapping DSDTCOL (follows m-d-y format), DSTMCOL (follows H:M format) to DSDTC


# Mapping DSTMCOL and DSDTCOL to DSDTC
ds <- ds %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),
    tgt_var = "DSDTC",
    id_vars = oak_id_vars(),
    raw_fmt = c("m-d-y", "H:M"),
    raw_unk = c("NA")  # safe, common unknown tokens
  )

# -------------------------------------------------------------------------
# Derive DSSTDTC 
# Logic : Convert IT.DSSTDAT to ISO 8601 date.
ds <- ds %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    id_vars = oak_id_vars(),
    raw_fmt = "m-d-y",
    raw_unk = c("NA")  # safe, common unknown tokens
  )

# -------------------------------------------------------------------------
# Derive DSSEQ
# Logic : Sequence within USUBJID ordered by DSSTDTC then DSDTC then oak_id.
ds <- ds %>%
  left_join(
    ds_raw %>% select(all_of(oak_id_vars()), oak_id),
    by = oak_id_vars()
  ) %>%
  arrange(USUBJID, DSSTDTC, DSDTC, oak_id) %>%
  group_by(USUBJID) %>%
  mutate(DSSEQ = row_number()) %>%
  ungroup()

# -------------------------------------------------------------------------
# Final formatting for SDTM dataset
ds_sdtm <- ds %>% 
  select(STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT, VISITNUM, VISIT, DSDTC,
         DSSTDTC)










