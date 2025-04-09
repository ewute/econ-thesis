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
    tags = sapply(tags, function(x) paste(x, collapse = ", ")),
    genres = sapply(genres, function(x) paste(x, collapse = ", "))
  ) %>%
  rename(
    mean_score = meanscore,
    start_date = startdate,
    end_date = enddate
  )

manga_index <- manga_index %>%
  rename_all(tolower) %>% 
  mutate_all(~na_if(., "N/A")) %>% 
  rename_all(~gsub("manga_", "", .)) %>% 
  # Remove na in id column
  filter(!is.na(id)) %>% 
  rename(
    mean_score = meanscore,
    start_date = startdate,
    end_date = enddate
  ) %>%
  select(-series) # drop column series

# Save cleaned data
write_csv(anime_index, file.path(clean_dir, "anime_index_clean.csv"))
write_csv(manga_index, file.path(clean_dir, "manga_index_clean.csv"))
