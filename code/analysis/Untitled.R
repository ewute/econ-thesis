# Housekeeping
source('housekeeping.R')

# Load in data
df <- read_csv(file.path(clean_dir, "anime_charts.csv"))

# Drop unidentifiable manga
df <- df %>%
  filter(!is.na(id)) %>% 
  filter(!(format %in% c("MUSIC", NA)))

