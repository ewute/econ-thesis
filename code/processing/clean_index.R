# Housekeeping
source('housekeeping.R')

# Read in data
anime_index <- read_csv(file.path(raw_dir, "anime_data.csv"))
manga_index <- read_csv(file.path(raw_dir, "manga_data.csv"))

# Clean anime data
anime_index <- anime_index %>%
  rename_all(tolower) %>% 
  mutate_all(~na_if(., "N/A")) %>% 
  rename_all(~gsub("anime_", "", .)) %>% 
  mutate(
    tags = str_split(tags, ",\\s*"),
    genres = str_split(genres, ",\\s*")
  ) %>%
  rename(
    mean_score = meanscore,
    start_date = startdate,
    end_date = enddate
  )

# Clean manga  data
manga_index <- manga_index %>%
  rename_all(tolower) %>% 
  mutate_all(~na_if(., "N/A")) %>% 
  rename_all(~gsub("manga_", "", .)) %>% 
  mutate(
    tags = str_split(tags, ",\\s*"),
    genres = str_split(genres, ",\\s*")
  ) %>%
  rename(
    mean_score = meanscore,
    start_date = startdate,
    end_date = enddate
  )

# Save cleaned data
write_csv(anime_index, file.path(clean_dir, "anime_data_clean.csv"))
write_csv(manga_index, file.path(clean_dir, "manga_data_clean.csv"))