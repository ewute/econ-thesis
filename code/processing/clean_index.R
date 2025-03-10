source('housekeeping.R')

# Read in .csv files
index <- read_csv(file.path(raw_dir, "anime_data.csv"))

# Remove "N/A" values from the index
index <- subset(index, !apply(index == "N/A", 1, any, na.rm = TRUE))

# Make headings lowercase for easier merging
index <- index %>%
  rename_all(tolower)

# Remove headings with "anime_"
index <- index %>%
  rename_all(~gsub("anime_", "", .))

# Change meanscore to mean_score
index <- index %>%
  rename(mean_score = meanscore)

# Drop columns id, mal_id
index <- index %>%
  select(-id, -mal_id)

# Save the cleaned index
write_csv(index, file.path(clean_dir, "index_cleaned.csv"))
