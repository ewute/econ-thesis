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
  