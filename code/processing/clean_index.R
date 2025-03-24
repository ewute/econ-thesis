source('housekeeping.R')

# Read in .csv files
anime_index <- read_csv(file.path(raw_dir, "anime_data.csv"))
manga_index <- read_csv(file.path(raw_dir, "manga_data.csv"))

# Make headings lowercase for easier merging
anime_index <- anime_index %>%
  rename_all(tolower)

manga_index <- manga_index %>%
  rename_all(tolower)

# Convert "N/A" string to NA
anime_index <- anime_index %>%
  mutate_all(~na_if(., "N/A"))

manga_index <- manga_index %>%
  mutate_all(~na_if(., "N/A"))

# Remove headings with "anime_"
anime_index <- anime_index %>%
  rename_all(~gsub("anime_", "", .))

# Remove headings with "manga_"
manga_index <- manga_index %>%
  rename_all(~gsub("manga_", "", .))

# Change meanscore to mean_score
anime_index <- anime_index %>%
  rename(mean_score = meanscore)
manga_index <- manga_index %>%
  rename(mean_score = meanscore)

# Change startdate and enddate to start_date and end_date
anime_index <- anime_index %>%
  rename(start_date = startdate, end_date = enddate)

manga_index <- manga_index %>%
  rename(start_date = startdate, end_date = enddate)

# Drop columns id, mal_id
anime_index <- anime_index %>%
  select(-id, -mal_id)
manga_index <- manga_index %>%
  select(-id, -mal_id)

# Save the cleaned index
write_csv(anime_index, file.path(clean_dir, "anime_index_cleaned.csv"))
write_csv(manga_index, file.path(clean_dir, "manga_index_cleaned.csv"))