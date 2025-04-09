# Housekeeping
source('housekeeping.R')

# Read in data
charts <- read_csv(file.path(clean_dir, "oricon_charts_clean.csv"))
manga_index <- read_csv(file.path(clean_dir, "manga_index_clean.csv"))
anime_index <- read_csv(file.path(clean_dir, "anime_index_clean.csv"))

# Lowercase everything and remove duplicates
anime_index_clean <- anime_index %>%
  mutate(
    search_title = str_to_lower(search_title),
    title_romaji = str_to_lower(title_romaji)
  ) %>%
  distinct(search_title, .keep_all = TRUE)

charts_clean <- charts %>%
  mutate(series = str_to_lower(series))

# Join on exact match first
charts_matched <- charts_clean %>%
  left_join(anime_index_clean, by = c("series" = "search_title"))

# Fuzzy match on remaining rows
threshold <- 0.12
columns_to_add <- setdiff(names(anime_index_clean), "search_title")

charts_matched <- charts_matched %>%
  rowwise() %>%
  mutate(
    match_data = list({
      if (!is.na(title_romaji)) {
        matched <- anime_index_clean[anime_index_clean$search_title == series, columns_to_add, drop = FALSE]
        matched$score <- 0
        matched
      } else {
        distances <- stringdist(series, anime_index_clean$search_title, method = "jw")
        min_dist <- min(distances)
        if (min_dist < threshold) {
          best_index <- which.min(distances)
          matched <- anime_index_clean[best_index, columns_to_add, drop = FALSE]
          matched$score <- min_dist
          matched
        } else {
          tibble(score = NA_real_, !!!setNames(rep(list(NA), length(columns_to_add)), columns_to_add))
        }
      }
    })
  ) %>%
  ungroup()

# Unpack all match_data columns
match_cols <- names(charts_matched$match_data[[1]])
for (col in match_cols) {
  charts_matched[[col]] <- sapply(charts_matched$match_data, `[[`, col)
}

# Clean up
charts_matched <- charts_matched %>%
  select(-match_data)

# Save the merged dataset
write_csv(charts_matched, file.path(clean_dir, "anime_charts.csv"))
