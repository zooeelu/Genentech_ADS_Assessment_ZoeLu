###############################################################################
# Question 3: TLG – Adverse Events Reporting - Visualizations
# Program: question_3_tlg_01_create_ae_visualizations.R

# Plot 1: AE Severity Distribution by Treatment (Bar Chart)
#     -Purpose: Create a stacked bar chart showing the distribution of AE severity
#               (MILD, MODERATE, SEVERE) by treatment group using ADAE.

# Plot 2: 
# Input: pharmaverseadam ADAE and ADSL datasets
# Output: PNG file
###############################################################################

# -------------- Load required packages -------------------------------------------
library(tidyverse)
library(pharmaverseadam)

# -------------- Load input datasets ----------------------------------------------
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

# -------------- Prepare visualization dataset -------------------------------------
# Filter for Treatment-Emergent AEs and keep severity and treatment

adae_dat <- adae %>% 
  filter(TRTEMFL == "Y") %>%  # Treatment-emergent AEs only
  filter(!is.na(AESEV)) %>% # Remove missing severity 
  select(USUBJID, ACTARM,  AESEV) # Select necessary columns only
    
# Get the counts for each severity for each treatment arm
adae_viz_dat <- adae_dat %>% 
  group_by(ACTARM, AESEV) %>% 
  summarise(count = n()) %>% 
  ungroup()

# -------------- Create bar chart ---------------------------------------------
ae_sev_barchart <- ggplot(data = adae_viz_dat, 
                          aes(x = ACTARM, # x axis
                              y = count, # y axis
                              fill = AESEV)) +  # stacked barchart
  # barchart with counts with space between bars
  geom_col(width = 0.7) +
  # adjust axis and title names
  labs(
    title = "AE Severity Distribution by Treatment",
    x = "Treatment Arm",
    y = "Count of AEs",
    # legend title
    fill = "Severity/Intensity"
  ) + 
  # fix x tick labels for better readability
  scale_x_discrete(
    labels = c(
      "Placebo" = "Placebo", 
      "Xanomeline Low Dose" = "Xanomeline\nLow Dose", 
      "Xanomeline High Dose" = "Xanomeline\nHigh Dose"
    )
  ) + 
  # adjust colors for barchart
  scale_fill_manual(
    values = c(
      "MILD"     = "#6FBF9A",  
      "MODERATE" = "#F2B66D",  
      "SEVERE"   = "#E07A7A"   
    ) 
  ) +
  # background theme
  theme_minimal() +
  theme(
    # make plot title bold 
    plot.title = element_text(hjust = 0.5, face = "bold"),
    # make x-axis title labels bold
    axis.title.x = element_text(face = "bold"), 
    # make y-axis title labels bold
    axis.title.y = element_text(face = "bold"),
    # put legend on the right
    legend.position = "right"
  )

# -------------- Save output --------------------------------------------------
ggsave(
  filename = "Question3/question3_02_visuals/ae_severity_by_treatment_barchart.png",
  plot = ae_sev_barchart,
  width = 6,
  height = 4,
  dpi = 300
)

