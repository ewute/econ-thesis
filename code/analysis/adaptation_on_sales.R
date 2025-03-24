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
  mutate(time_since_adaptation = abs(as.numeric(difftime(weekly_date, anime_index$start_date[match(search_title, anime_index$search_title)], units = "days"))))

# Fit a linear model with time variable and treated group
model_time <- lm(weekly ~ treated + time_since_adaptation + I(time_since_adaptation^2), data = df)
summary(model_time)

model_time_simple <- lm(weekly ~ treated + time_since_adaptation, data = df)
summary(model_time_simple)

# Plot the relationship between time_since_adaptation and weekly sales
ggplot(df, aes(x = time_since_adaptation, y = weekly, color = factor(treated))) +
  geom_point() +
  labs(title = "Weekly Sales vs. Time Since Anime Adaptation",
       x = "Time Since Anime Adaptation (days)",
       y = "Weekly Sales") +
  scale_color_discrete(name = "Anime Adaptation") +
  theme_minimal() +
  theme(legend.position = "top")
