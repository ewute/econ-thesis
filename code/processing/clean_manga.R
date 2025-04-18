source('housekeeping.R')

# Import data
manga <- read_csv(file.path(raw_dir, 'matched_titles2.csv'))
anime <- read_csv(file.path(raw_dir, 'anilist_anime.csv')) %>% 
  select(title_romaji, title_english, format, status, start_date, end_date, main_series_romaji, main_series_english)
charts <- read_csv(file.path(clean_dir, 'oricon_charts_clean.csv')) %>% 
  select(series, weekly_sales, total_sales, reporting_week)
popularity <- read_csv(file.path(raw_dir, 'anilist_manga_popularity.csv'))
genres <- read_csv(file.path(raw_dir, 'anilist_manga_list.csv')) %>% 
  select(id, genres)

# Join by manga and popularity by id
manga <- manga %>%
  left_join(popularity, by = c('id' = 'id'))

# Join manga with genres by id
manga <- manga %>%
  left_join(genres, by = "id") %>%
  mutate(
    genres = strsplit(genres, ",\\s*"),
    genres = sapply(genres, function(g) paste(unique(g), collapse = ", "))
  )

# Give statistics of df$match_score
summary(manga$match_score)

# Drop first quartile
manga <- manga %>%
  filter(match_score > quantile(manga$match_score, 0.25))

# Make all series in charts and manga lowercase
manga <- manga %>%
  mutate(series = tolower(series),
         title_romaji = tolower(title_romaji))
charts <- charts %>%
  mutate(series = tolower(series))
anime <- anime %>% 
  mutate(title_romaji = tolower(title_romaji),
         main_series_romaji = tolower(main_series_romaji))

# One hot encode genres in manga
manga <- manga %>%
  mutate(genres = ifelse(genres == "NA", NA, genres)) %>%
  filter(!is.na(genres)) %>% 
  mutate(genres = strsplit(genres, ",\\s*")) %>% 
  unnest(genres) %>%
  mutate(
    genres = str_to_lower(genres),
    genres = paste0("genre_", genres),
    dummy = 1
  ) %>%
  pivot_wider(
    names_from = genres,
    values_from = dummy,
    values_fill = list(dummy = 0)
  )

# Match manga to charts, series to series
manga_charts <- charts %>%
  left_join(manga, by = c('series' = 'series')) %>% 
  filter(!is.na(id))

# If anime doesn't have a main_series_english and main_series_romaji, replace NA with the title_romaji and title_english
anime <- anime %>%
  mutate(main_series_romaji = ifelse(is.na(main_series_romaji), title_romaji, main_series_romaji),
         main_series_english = ifelse(is.na(main_series_english), title_english, main_series_english)) %>% 
  distinct(title_romaji, .keep_all = TRUE)

# Manga has had an anime adaptation
manga_charts <- manga_charts %>%
  mutate(adapted = if_else(title_romaji %in% anime$main_series_romaji, 1, 0))

# Filter out manga that have not had an anime adaptation
manga_charts <- manga_charts %>%
  filter(adapted == 1) %>%
  select(-c(adapted, title_english))

# List of unique manga on the charts
manga_adaptations <- manga_charts %>%
  select(title_romaji) %>%
  distinct() %>%
  left_join(anime, by = c("title_romaji" = "title_romaji")) 

unmatched <- manga_adaptations %>%
  filter(is.na(start_date)) %>%
  select(title_romaji)

second_matches <- unmatched %>%
  left_join(anime, by = c("title_romaji" = "main_series_romaji")) %>% 
  group_by(title_romaji) %>%
  slice_head(n=1)

manga_adaptations_final <- manga_adaptations %>%
  filter(!is.na(start_date)) %>%
  bind_rows(second_matches) %>% 
  select(title_romaji, format, start_date, end_date)

# Mutate manga_charts_unique for adaptation end date based on anime main_series_romaji
manga_adaptations <- manga_adaptations_final %>% 
  select(title_romaji, format, start_date, end_date) #%>% 
  # drop any before 2009-01-04 and after 2023-11-12
  # filter(start_date >= as.Date('2009-01-04') & start_date <= as.Date('2023-11-12'))

# Record column in charts that says whether the report was before or after the (first) adaptation

manga_charts <- manga_charts %>%
  mutate(reporting_week = as.Date(reporting_week))

first_adaptations <- manga_adaptations %>%
  group_by(title_romaji) %>% 
  slice_head(n=1)

manga_charts_join <- manga_charts %>%
  left_join(manga_adaptations, by = "title_romaji") %>%
  mutate(
    reporting_week = as.Date(reporting_week),
    end_date = as.Date(end_date),
    start_date = as.Date(start_date),
    weeks_relative_to_end = as.numeric(difftime(reporting_week, end_date, units = "weeks")),
    weeks_relative_to_start = as.numeric(difftime(reporting_week, start_date, units = "weeks")),
    pre_start = if_else(weeks_relative_to_start <= -1, 1, 0),
    post_start = if_else(weeks_relative_to_start > 0, 1, 0)
  ) %>% 
  filter(end_date >= as.Date('2009-01-04') & end_date <= as.Date('2023-11-12')) %>% 
  select(-c(id, popularity, match_score)) %>% 
  mutate(
    # pre, during and post
    pre_adaptation = if_else(weeks_relative_to_end <= -1, 1, 0),
    post_adaptation = if_else(weeks_relative_to_end > 0, 1, 0),
  )

# Save the data
write_csv(manga_charts_join, file.path(clean_dir, 'manga_charts_clean.csv'))
write_csv(manga_adaptations, file.path(clean_dir, 'manga_adaptations_clean.csv'))
write_csv(manga, file.path(clean_dir, 'manga_clean.csv'))

