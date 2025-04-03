source('housekeeping.R')

# Read in .csv files
df <- read_csv(file.path(clean_dir, "merged_data.csv"))

df <- df %>%
  mutate(tags = str_replace_all(tags, ",\\s+", ","))

# Count how often each tag appears
top_tags <- df %>%
  filter(format == "MANGA") %>%
  separate_rows(tags, sep = ",") %>%  # Split tags into separate rows
  count(tags, sort = TRUE) %>%  # Count occurrences and sort
  slice_head(n = 10) %>%  # Take the top 10 most frequent tags
  pull(tags)  # Extract the tag names

# Create new columns for each tag and fill with 1 if the tag is present
df_wide <- df %>%
  filter(format == "MANGA") %>%
  mutate(tags = str_trim(tags))  # Ensure no extra spaces

# Loop through each tag and create binary columns
for (tag in top_tags) {
  df_wide[[tag]] <- as.integer(str_detect(df_wide$tags, tag))
}

# Keep only relevant columns
df_wide <- df_wide %>%
  select(series, title, weekly, total, final_date, all_of(top_tags))

# Drop row if all tag columns are 0
df_wide <- df_wide %>%
  filter(rowSums(select(., all_of(top_tags))) > 0)

# Create linear regression models for weekly and total sales
# Prepare the dataset (keep only numeric columns)
df_regression <- df_wide %>%
  select(-series, -title, -final_date)  # Remove non-numeric columns

# Fit a linear regression model (weekly sales)
model_weekly <- lm(weekly ~ ., data = df_regression)
summary(model_weekly)  # Print regression results

# Fit a linear regression model (total sales)
model_total <- lm(total ~ ., data = df_regression)
summary(model_total)  # Print regression results


