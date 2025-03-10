source('housekeeping.R')

# Read in .csv files
df <- read_csv(file.path(clean_dir, "merged_data.csv"))

# Take in only format == "MANGA"
df <- df %>%
  filter(format == "MANGA")

# Linear regression of weekly and total by popularity, favourites, mean score
model_weekly <- lm(weekly ~ popularity + favourites + mean_score, data = df)
model_total <- lm(total ~ popularity + favourites + mean_score, data = df)

# Print regression results
summary(model_weekly)
summary(model_total)

# Create linear regression model for weekly and total sales by popularity
model_weekly_popularity <- lm(weekly ~ popularity, data = df)
model_total_popularity <- lm(total ~ popularity, data = df)

# Print regression results
summary(model_weekly_popularity)
summary(model_total_popularity)

# Plot total sales against popularity
ggplot(df, aes(x = popularity, y = total)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE) +
  labs(title = "Total Sales vs. Popularity",
       x = "Popularity",
       y = "Total Sales") +
  theme_minimal()
 