###############################################################################
# Question 3: TLG – Adverse Events Reporting
# Program: question_3_tlg/01_create_ae_summary_table.R
# Purpose: Create an FDA-style Table 10 summary of Treatment-Emergent
#          Adverse Events (TEAEs) using the pharmaverseadam ADAE and ADSL datasets.
#          The table summarizes the number and percentage of subjects experiencing
#          at least one TEAE by treatment group, following FDA TLG guidance.
# Output: AE summary table in HTML format
# Notes/ Reminders: 
#            - ADAE: event-level adverse event records (used for numerators)
#            - ADSL: analysis population / treatment groups (used for denominators)
###############################################################################

# -------------- Load required packages ---------------------------------------
library(dplyr)
library(gtsummary)
library(gt)
library(pharmaverseadam)

## ---- Load input datasets ----------------------------------------------------
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

## ---- Check contents of adsl and adae ----------------------------------------------------
# Check which dataset varibles of interest are in
sum(colnames(adae) %in% c("AETERM", "AESOC", "ACTARM"))
sum(colnames(adsl) %in% c("AETERM", "AESOC", "ACTARM")) # ACTARM in both datasets


## ---- Derive subject-level AE indicators -------------------------------------
adae_tbl_data <- adae %>% 
  # Restrict to TEAEs
  filter(TRTEMFL == "Y") 

## ---- Create AE summary table ------------------------------------------------
# Primary System Organ Class (AESOC) and Preferred Term (AETERM)
# n (%) = number (percent) of subjects with >=1 TEAE in the SOC/PT,
# where percent uses the ADSL denominator within each treatment arm.

ae_table <- adae_tbl_data %>% 
  tbl_hierarchical(
    variables = c(AESOC, AETERM), # variables to sepcify hierarchy
    by = ACTARM, # indicate what to group by for sum. stat
    id = USUBJID, # identify rows to calculate event rates
    denominator = adsl, # denominator of rates
    overall_row = TRUE, # summary row at top of table
    label = list(..ard_hierarchical_overall.. = "Any TEAE",
                 AESOC = "System Organ Class",
                 AETERM = "Preferred Term") # controls text shown in leftmost column
  )

## ---- Saving summary table as HTML ------------------------------------------------
as_gt(ae_table) %>%
  tab_header(
    title = "Summary of Treatment-Emergent Adverse Events (TEAE)"
    ) %>% 
  gtsave("Question3/AE_summary_table.html")

