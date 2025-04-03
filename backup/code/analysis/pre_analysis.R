source('housekeeping.R')

# Read in .csv files
df <- read_csv(file.path(clean_dir, "merged_manga.csv"))
anime_index <- read_csv(file.path(clean_dir, "anime_index_cleaned.csv"))

# Get list adaptations
anime_index <- anime_index %>%
  filter(format != "MANGA") %>%
  group_by(search_title)

# Mutate df column to count the number of adaptations there are, without joining
df <- df %>%
  mutate(
    # Count the number of adaptations for each 'search_title' in anime_index
    adaptation_count = sapply(search_title, function(title) {
      sum(anime_index$search_title == title)
    })
  )

# df should only be unique search_titles
df <- df %>%
  distinct(search_title, .keep_all = TRUE)

# Plot histogram
ggplot(df, aes(x = adaptation_count)) +
  geom_histogram(binwidth = 1, fill = "skyblue", color = "black") +
  labs(title = "Distribution of Adaptation Count",
       x = "Adaptation Count",
       y = "Frequency") +
  theme_minimal()

# Drop NA
df <- df %>%
  filter(!is.na(adaptation_count))

# Summary statistics of adaptation_count
summary(df$adaptation_count)

# Remove manga with more than 20 adaptations
df_clean <- df %>%
  filter(adaptation_count <= 15)

# Summary statistics of adaptation_count after removing outliers
summary(df_clean$adaptation_count)

# Perform one-sided t-test to check if the average adaptation count is less than 1
t_test_result <- t.test(df_clean$adaptation_count, mu = 1, alternative = "less")

# Show the p-value
t_test_result$p.value

# histogram of df_clean
ggplot(df_clean, aes(x = adaptation_count)) +
  geom_histogram(binwidth = 1, fill = "skyblue", color = "black") +
  labs(title = "Distribution of Adaptation Count (Cleaned)",
       x = "Adaptation Count",
       y = "Frequency") +
  theme_minimal()

# count adaptations above 5
df %>%
  count(adaptation_count > 5)

# fraction of manga with more than 1 adaptation
df %>%
  count(adaptation_count > 1) %>%
  mutate(fraction = n / sum(n))

# Check if tags affect weekly sales
df$genres <- strsplit(df$genres, ", ")

# Unnest the genres into individual rows
df_dummies <- df %>%
  select(title_romaji, genres, weekly) %>%
  unnest(genres) %>%
  distinct() %>%
  mutate(value = 1) %>%
  pivot_wider(names_from = genres, values_from = value, values_fill = list(value = 0))

# Regress weekly sales on the dummy variables of genres, fixing for title_romaji
model <- lm(weekly ~ . - factor(title_romaji), data = df_dummies)

# Filter out the coefficient related to title_romaji
filtered_summary <- model_summary$coefficients %>%
  as.data.frame() %>%
  rownames_to_column(var = "term") %>%
  filter(!grepl("title_romaji", term))  # Remove any coefficients related to title_romaji

# View the filtered summary (coefficients excluding title_romaji)
filtered_summary
