source('housekeeping.R')

# Import dataset
df <- read_csv(file.path(clean_dir, "merged_manga.csv"))
anime_index <- read_csv(file.path(clean_dir, "anime_index_cleaned.csv"))

# Convert date column and create weekly_date (shift by -7 days)
df <- df %>%
  mutate(final_date = as.Date(final_date, format = "%Y-%m-%d"),
         weekly_date = final_date - 7)

# Select relevant columns
# If search_title is NA, use title_romaji
df <- df %>%
  mutate(search_title = ifelse(is.na(search_title), title_romaji, search_title)) %>%
  select(search_title, weekly, total, weekly_date)

# In anime_index, group by search_title and take the most popular (highest popularity), non "MANGA"
anime_index <- anime_index %>%
  filter(format != "MANGA") %>%
  group_by(search_title) %>%
  arrange(desc(popularity)) %>%
  slice_head(n = 1) %>%
  ungroup()

# Mutate df column to indicate whether there was an anime adaption or not before the weekly_date
# Compare search_title, start_date in anime_index with search_title, weekly_date in df
# If NA, then it was not an anime adaption
df <- df %>%
  mutate(treated = ifelse(search_title %in% anime_index$search_title &
                            weekly_date >= anime_index$start_date[match(search_title, anime_index$search_title)],
                          1, 0))

df$weekly_date <- as.Date(df$weekly_date)
anime_index$start_date <- as.Date(anime_index$start_date)

# Create time variable (e.g., weeks before or after anime adaptation)
df <- df %>%
  mutate(time_since_adaptation = as.numeric(difftime(weekly_date, anime_index$start_date[match(search_title, anime_index$search_title)], units = "days")))

# Find top charting day for each treated manga
top_charting_day <- df %>%
  filter(treated == 1) %>%
  group_by(search_title) %>%
  arrange(desc(total)) %>%
  slice_head(n = 1) %>%
  ungroup()

# Create variable time_since_top_charting_day_treated using mutate
df_treated <- df %>%
  filter(treated == 1) %>%
  mutate(time_since_top_charting_day_treated = ifelse(search_title %in% top_charting_day$search_title,
                                                      as.numeric(difftime(weekly_date, top_charting_day$weekly_date[match(search_title, top_charting_day$search_title)], units = "days")), NA))

# Graph a ggplot where the center is minimizing time_since_top_charting_day_treated of df_treated
ggplot(df_treated, aes(x = time_since_top_charting_day_treated)) +
  geom_histogram(binwidth = 100, fill = "orange", color = "black") +
  labs(title = "Time Since Top Charting Day for Treated Manga",
       x = "Time Since Top Charting Day (Days)",
       y = "Weekly Sales") +
  theme_minimal()

# Create a variable for manga that never had an anime adaptation
df <- df %>%
  mutate(never_adapted = ifelse(search_title %in% anime_index$search_title, 0, 1))

# Do the same for untreated manga, and exclude manga that have never been adapted
top_charting_day_untreated <- df %>%
  filter(treated == 0 & never_adapted == 0) %>%
  group_by(search_title) %>%
  arrange(desc(total)) %>%
  slice_head(n = 1) %>%
  ungroup()

df_untreated <- df %>%
  filter(treated == 0) %>%
  mutate(time_since_top_charting_day_untreated = ifelse(search_title %in% top_charting_day_untreated$search_title,
                                                        as.numeric(difftime(weekly_date, top_charting_day_untreated$weekly_date[match(search_title, top_charting_day_untreated$search_title)], units = "days")), NA))

ggplot(df_untreated, aes(x = time_since_top_charting_day_untreated)) +
  geom_histogram(binwidth = 150, fill = "skyblue", color = "black") +
  labs(title = "Time Since Top Charting Day for Untreated Manga",
       x = "Time Since Top Charting Day (Days)",
       y = "Weekly Sales") +
  theme_minimal()

# For treated manga, use the time_since_top_charting_day_treated
df_treated <- df %>%
  filter(treated == 1) %>%
  mutate(time_since_top_charting_day = 
           as.numeric(difftime(weekly_date, 
                               top_charting_day$weekly_date[match(search_title, top_charting_day$search_title)], 
                               units = "days"))) %>%
  mutate(treated = "Treated")

# For untreated manga, use the time_since_top_charting_day_untreated
df_untreated <- df %>%
  filter(treated == 0) %>%
  mutate(time_since_top_charting_day = 
           as.numeric(difftime(weekly_date, 
                               top_charting_day_untreated$weekly_date[match(search_title, top_charting_day_untreated$search_title)], 
                               units = "days"))) %>%
  mutate(treated = "Untreated")

# Combine the treated and untreated data
df_combined <- rbind(df_treated, df_untreated)

# Plot the combined data
ggplot(df_combined, aes(x = time_since_top_charting_day, y = weekly, color = treated)) +
  geom_point() +
  labs(title = "Weekly Sales vs. Time Since Top Charting Day",
       x = "Time Since Top Charting Day (Days)",
       y = "Weekly Sales") +
  theme_minimal()

# Plot the combined data from time_since_adaptation as histograms
ggplot(df_combined, aes(x = time_since_adaptation, fill = treated)) +
  geom_histogram(binwidth = 150, position = "dodge") +
  labs(title = "Time Since Adaptation for Treated and Untreated Manga",
       x = "Time Since Adaptation (Days)",
       y = "Weekly Sales") +
  theme_minimal()

# Find never adapted manga with the highest total sales charts
top_charting_day_never_adapted <- df %>%
  filter(never_adapted == 1) %>%
  group_by(search_title) %>%
  arrange(desc(total)) %>%
  slice_head(n = 1) %>%
  ungroup()

# Create time_since_top_charting_day_never_adapted
df_never_adapted <- df %>%
  filter(never_adapted == 1) %>%
  mutate(time_since_top_charting_day_never_adapted = ifelse(search_title %in% top_charting_day_never_adapted$search_title,
                                                           as.numeric(difftime(weekly_date, top_charting_day_never_adapted$weekly_date[match(search_title, top_charting_day_never_adapted$search_title)], units = "days")), NA))

# Plot the time_since_top_charting_day_never_adapted
ggplot(df_never_adapted, aes(x = time_since_top_charting_day_never_adapted)) +
  geom_histogram(binwidth = 125, fill = "skyblue", color = "black") +
  labs(title = "Time Since Top Charting Day for Never Adapted Manga",
       x = "Time Since Top Charting Day (Days)",
       y = "Weekly Sales") +
  theme_minimal()

# Save the plots
ggsave(file.path(output_dir, "time_since_top_charting_day_treated.png"), width = 8, height = 6)
ggsave(file.path(output_dir, "time_since_top_charting_day_untreated.png"), width = 8, height = 6)
ggsave(file.path(output_dir, "time_since_top_charting_day_combined.png"), width = 8, height = 6)
