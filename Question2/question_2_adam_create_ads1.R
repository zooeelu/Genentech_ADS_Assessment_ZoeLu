###############################################################################
# Question 2: ADaM ADSL Dataset Creation (using {admiral})
# Program: question_2_adam_create_ads1.R 
# Purpose: Create an ADSL (Subject Level) dataset using SDTM source data, 
#          the {admiral} family of packages, and tidyverse tools
# Inputs: pharmaversesdtm::dm, pharmaversesdtm::vs, pharmaversesdtm::ex, 
#         pharmaversesdtm::ds, pharmaversesdtm::ae
# Output: ADSL with AGEGR9/AGEGR9N, TRTSDTM/TRTSTMF, ITTFL, LSTAVLDT
###############################################################################

# Loading in Libraries
library(tidyverse)
library(pharmaversesdtm)
library(admiral)
library(lubridate)
library(stringr)

# ------------Reading in the data ---------------------------------------
dm <- pharmaversesdtm::dm
vs <- pharmaversesdtm::vs
ex <- pharmaversesdtm::ex
ds <- pharmaversesdtm::ds
ae <- pharmaversesdtm::ae

# Convering blanks in data to NA
dm <- convert_blanks_to_na(dm)
vs <- convert_blanks_to_na(vs)
ex <- convert_blanks_to_na(ex)
ds <- convert_blanks_to_na(ds)
ae <- convert_blanks_to_na(ae)


# ------------Setting up ADSL ---------------------------------------
adsl <- dm %>%
  select(-DOMAIN)

# ------------Derive AGEGR9 / AGEGR9N ---------------------------------------
# Age grouping cateogries: <18, 18-50, >50
adsl <- adsl %>% 
  mutate(
    # Text version of Age groups
    AGEGR9 = case_when(
      AGE < 18 ~ "<18", 
      AGE >= 18 & AGE <= 50 ~ "18-50", 
      AGE > 50 ~ ">50", 
      TRUE ~ NA_character_
    ), 
    # Numeric version of Age groups, numbered 1,2, and 3
    AGEGR9N = case_when(
      AGE < 18 ~ 1L, 
      AGE >= 18 & AGE <= 50 ~ 2L, 
      AGE > 50 ~ 3L, 
      TRUE ~ NA_integer_
    )
  )

# ------------Derive TRTSDTM / TRTSTMF ---------------------------------------
# - Use first exposure record per subject (ex file)
# - Only include "valid dose" records:
#     EXDOSE > 0 OR (EXDOSE == 0 AND EXTRT contains 'PLACEBO')
# - Only include records where datepart of EXSTDTC is complete (YYYY-MM-DD)
# - Impute time:
#     * If time missing entirely -> 00:00:00 and TRTSTMF = "Y" (flag)
#     * If partial time missing -> impute missing HH/MM/SS with "00" seconds and TRTSTMF = "Y" (flag)
#     * If ONLY seconds missing -> impute seconds to "00" BUT TRTSTMF = NA (do not flag)

# Derive date time object for treatment start date
ex_ext <-  ex %>% 
  derive_vars_dtm(
    dtc = EXSTDTC, # input
    new_vars_prefix = "EXST", # output
    time_imputation = "first", # impute missing time to 00:00:00 (first time of day), 
    flag_imputation = "time"
    ) 

# Create a "valid dose" subset of EX:
#     - Valid dose = EXDOSE > 0 OR (EXDOSE == 0 AND EXTRT contains "PLACEBO")
#     - Also require EXSTDTM not missing (means date part of EXSTDTC was complete enough)

ex_for_trt <- ex_ext %>%
  mutate(
    valid_dose =
      (EXDOSE > 0) |
      (EXDOSE == 0 & !is.na(EXTRT) & str_detect(toupper(EXTRT), "PLACEBO")),
    
    # TRTSTMF is a Y/NA flag:
    # - "Y" if hours or minutes were imputed
    # - NA otherwise (including "seconds-only" imputation)
    TRTSTMF_TMP = case_when(
      EXSTTMF %in% c("H", "M") ~ "Y",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(valid_dose, !is.na(EXSTDTM))

# Merge FIRST valid exposure record into ADSL: 
#     - order by earliest EXSTDTM (with EXSEQ as a tie breaker if needed)
#     - mode = "first" --> picks the first record per subject
#     - officially create TRTSDTM and TRTSTMF in ADSL
adsl <- adsl %>% 
  derive_vars_merged(
    dataset_add = ex_for_trt, # external data 
    new_vars = exprs(TRTSDTM = EXSTDTM, # mapping to new vars
                     TRTSTMF = TRTSTMF_TMP), 
    by_vars = exprs(STUDYID,   # grouping vars
                    USUBJID),
    mode = "first", # first obs
    order = exprs(EXSTDTM, EXSEQ) # sort order
  )

# ------------Derive ITTFL ---------------------------------------------------














