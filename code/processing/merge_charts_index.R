source('housekeeping.R')

# Read in .csv files
charts <- read_csv(file.path(clean_dir, "oricon_all_charts_cleaned.csv"))
anime_index <- read_csv(file.path(clean_dir, "anime_index_cleaned.csv"))
manga_index <- read_csv(file.path(clean_dir, "manga_index_cleaned.csv"))

# Group anime_index by search_title and get the first title_romaji
titles <- anime_index %>%
  group_by(search_title) %>%
  summarise(title_romaji = first(title_romaji))

# Standardize casing in manga_index$title_romaji and titles$title_romaji
# Uppercase first letter of each word
manga_index <- manga_index %>%
  mutate(title_romaji = str_to_title(title_romaji))

titles <- titles %>%
  mutate(title_romaji = str_to_title(title_romaji))

# Merge manga_index and titles by title_romaji
manga_index <- manga_index %>%
  left_join(titles, by = "title_romaji")

# Merge the manga and charts datasets by search_title for manga and series for charts
manga_charts <- manga_index %>%
  left_join(charts, by = c("search_title" = "series"), suffix = c("_manga", "_charts"))

# Drop manga from anime_index


# Merge the manga_charts and anime_index datasets by title_romaji for manga_charts and search_title for anime_index

# Save the merged datasets
#write_csv(merged_data, file.path(clean_dir, "merged_data.csv"))
write_csv(manga_charts, file.path(clean_dir, "merged_manga.csv"))
