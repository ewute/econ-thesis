source('housekeeping.R')

# Read in .csv files
charts <- read_csv(file.path(clean_dir, "oricon_all_charts_cleaned.csv"))
index <- read_csv(file.path(clean_dir, "index_cleaned.csv"))

# Merge the two datasets by series for charts and search_title for index
merged_data <- charts %>%
  left_join(index, by = c("series" = "search_title"), relationship = "many-to-many")

# Save the merged data
write_csv(merged_data, file.path(clean_dir, "merged_data.csv"))
