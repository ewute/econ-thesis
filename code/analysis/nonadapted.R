source('housekeeping.R')

manga_charts_non_adapted <- read_csv(file.path(clean_dir, "manga_charts_non_adapted.csv"))
manga_charts <- read_csv(file.path(clean_dir, "manga_charts_adapted.csv"))

# Clean column name with janitor
manga_charts_non_adapted <- janitor::clean_names(manga_charts_non_adapted)
manga_charts <- janitor::clean_names(manga_charts)

# 1. Get unique series and their genre flags
genre_cols <- grep("^genre_", names(manga_charts), value = TRUE)

unique_series <- manga_charts %>%
  distinct(series, .keep_all = TRUE) %>%
  select(series, all_of(genre_cols))

# 2. Calculate proportion of each genre
genre_proportions <- colMeans(unique_series[genre_cols])

# 3. Turn into a tidy data frame
genre_proportions_df <- tibble(
  genre = names(genre_proportions),
  proportion = genre_proportions
) %>%
  arrange(desc(proportion))

# Do the same for manga_charts_non_adapted
unique_series_non_adapted <- manga_charts_non_adapted %>%
  distinct(series, .keep_all = TRUE) %>%
  select(series, all_of(genre_cols))
genre_proportions_non_adapted <- colMeans(unique_series_non_adapted[genre_cols])
genre_proportions_df_non_adapted <- tibble(
  genre = names(genre_proportions_non_adapted),
  proportion = genre_proportions_non_adapted
) %>%
  arrange(desc(proportion))

# Combine and say proportion, top 8
combined_genre_proportions <- genre_proportions_df %>%
  left_join(genre_proportions_df_non_adapted, by = "genre", suffix = c("_adapted", "_non_adapted")) %>%
  mutate(
    proportion_diff = proportion_adapted - proportion_non_adapted,
  ) %>%
  slice_head(n = 8)

combined_genre_proportions
