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
  mutate(treatment = ifelse(search_title %in% anime_index$search_title &
                            weekly_date >= anime_index$start_date[match(search_title, anime_index$search_title)],
                          1, 0))

df$weekly_date <- as.Date(df$weekly_date)
anime_index$start_date <- as.Date(anime_index$start_date)

# Create time variable (e.g., weeks before or after anime adaptation)
df <- df %>%
  mutate(time_since_adaptation = abs(as.numeric(difftime(weekly_date, anime_index$start_date[match(search_title, anime_index$search_title)], units = "days"))))

# Mutate column for ever_treated
df <- df %>%
  group_by(search_title) %>%
  mutate(ever_treated = max(treatment)) %>%
  ungroup()

df_ever_treated <- df %>%
  filter(ever_treated == 1)

# Include fe for days and series
model_fe_day <- lm(weekly ~ treatment + factor(weekly_date) + factor(search_title), data = df_ever_treated)

# Save model as file
saveRDS(model_fe_day, file.path(output_dir, "model_fe_week.rds"))

# Summary of model_time but only looking at treatment and time_since_adaptation
summary(model_fe_day)$coefficients["treatment", ]

# Without fe for titles
model_fe_day_no_title <- lm(weekly ~ treatment + factor(weekly_date), data = df_ever_treated)
saveRDS(model_fe_day_no_title, file.path(output_dir, "model_fe_week_no_title.rds"))
summary(model_fe_day_no_title)$coefficients["treatment", ]

# Find top charting day for each treated manga
top_charting_day <- df %>%
  filter(treatment == 1) %>%
  group_by(search_title) %>%
  arrange(desc(total)) %>%
  slice_head(n = 1) %>%
  ungroup()

# Create variable time_since_top_charting_day_treated using mutate
df_treated <- df %>%
  filter(ever_treated == 1) %>%
  mutate(time_since_top_charting_day_treated = ifelse(search_title %in% top_charting_day$search_title,
                                                      as.numeric(difftime(weekly_date, top_charting_day$weekly_date[match(search_title, top_charting_day$search_title)], units = "days")), NA))

# Fixed effects for top_charting_day
model_fe_top_charting_day <- lm(weekly ~ treatment + factor(time_since_top_charting_day_treated) + factor(search_title), data = df_treated)
saveRDS(model_fe_top_charting_day, file.path(output_dir, "model_fe_top_charting_day.rds"))

# Without fe for titles
model_fe_top_charting_day_no_title <- lm(weekly ~ treatment + factor(time_since_top_charting_day_treated), data = df_treated)
saveRDS(model_fe_top_charting_day_no_title, file.path(output_dir, "model_fe_top_charting_day_no_title.rds"))

# Summarize both
summary(model_fe_top_charting_day)$coefficients["treatment", ]
summary(model_fe_top_charting_day_no_title)$coefficients["treatment", ]
