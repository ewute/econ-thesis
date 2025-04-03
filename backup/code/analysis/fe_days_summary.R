source('housekeeping.R')

# Load in .rds models from output_dir

# Manga ever adapted; FE of weekly_date and search_title
model_fe_date_title_treated <- readRDS(file.path(output_dir, "model_fe_date_title_treated.rds"))
model_fe_date_treated <- readRDS(file.path(output_dir, "model_fe_date_treated.rds"))

# Manga ever adapted; FE of relative time (days since top charting)
model_fe_charting_title_treated <- readRDS(file.path(output_dir, "model_fe_charting_title_treated.rds"))
model_fe_charting_treated <- readRDS(file.path(output_dir, "model_fe_charting_treated.rds"))

# All manga; FE of relative time (days since top charting)
model_fe_charting_title_all <- readRDS(file.path(output_dir, "model_fe_charting_title_all.rds"))
model_fe_charting_all <- readRDS(file.path(output_dir, "model_fe_charting_all.rds"))

# Summary of model looking only at treatment
summary(model_fe_date_title_treated)$coefficients["treatment", ]
summary(model_fe_date_treated)$coefficients["treatment", ]
summary(model_fe_charting_title_treated)$coefficients["treatment", ]
summary(model_fe_charting_treated)$coefficients["treatment", ]
summary(model_fe_charting_title_all)$coefficients["treatment", ]
summary(model_fe_charting_all)$coefficients["treatment", ]