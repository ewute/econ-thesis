# Housekeeping
source('housekeeping.R')

# Load in data
df <- read_csv(file.path(clean_dir, "anime_charts.csv"))

# Create a new data frame for the bounds of weekly_sales for each reporting_week
weekly_bounds <- df %>%
  group_by(reporting_week) %>%
  summarise(
    sales_lo = min(weekly_sales, na.rm = TRUE),
    sales_hi = max(weekly_sales, na.rm = TRUE)
  ) %>%
  ungroup()

# Save
write_csv(weekly_bounds, file.path(clean_dir, "weekly_bounds.csv"))
