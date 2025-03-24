source('housekeeping.R')

# Read in .csv files
charts <- read_csv(file.path(clean_dir, "oricon_all_charts_cleaned.csv"))
anime_index <- read_csv(file.path(clean_dir, "anime_index_cleaned.csv"))
manga_index <- read_csv(file.path(clean_dir, "manga_index_cleaned.csv"))

# Merge the manga and charts datasets by title_romaji for manga and series for charts
manga_charts <- manga_index %>%
  left_join(charts, by = c("title_romaji" = "series"), suffix = c("_manga", "_charts"))

# Drop manga from anime_index
anime_index <- anime_index %>%
  filter(format != "MANGA")

# Merge the manga_charts and anime_index datasets by title_romaji for manga_charts and search_title for anime_index
merged_data <- manga_charts %>%
  left_join(anime_index, by = c("title_romaji" = "search_title"), suffix = c("_manga_charts", "_anime_index"))

# Save the merged data
write_csv(merged_data, file.path(clean_dir, "merged_data.csv"))
