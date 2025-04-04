# Housekeeping
source('housekeeping.R')

# Load in data
df <- read_csv(file.path(clean_dir, "anime_charts.csv"))

# Keep non-duplicate series with a end_date
df <- df %>%
  select(series, title_romaji, id, format, end_date) %>% 
  filter(!duplicated(id)) %>%
  filter(!is.na(end_date)) %>% 
  filter(!(format %in% c("MUSIC", NA)))

# Cast end_date to date
df <- df %>%
  mutate(end_date = as.Date(end_date)) %>% 
  filter(!is.na(end_date))

# Save
write_csv(df, file.path(clean_dir, "anime_finale.csv"))