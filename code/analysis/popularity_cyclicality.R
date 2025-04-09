source('housekeeping.R')

# --- Load data ---
manga_charts <- read_csv(file.path(clean_dir, 'manga_charts_clean.csv'))
manga_adaptations <- read_csv(file.path(clean_dir, 'manga_adaptations_clean.csv'))
manga <- read_csv(file.path(clean_dir, 'manga_clean.csv'))

# total sales
sales_popularity <- manga_charts %>% 
  group_by(title_romaji) %>%
  summarise(total_sales = max(total_sales)) %>%
  ungroup()

# --- Spectral strength helper ---
get_spectral_strength <- function(sales_series) {
  if (length(sales_series) < 10 || all(sales_series == 0)) {
    return(NA)
  }
  spec <- spectrum(sales_series, plot = FALSE)
  dominant <- which.max(spec$spec)
  return(spec$spec[dominant])
}

# --- Compute spectral strength ---
spectral_scores <- manga_charts %>%
  group_by(title_romaji) %>%
  summarise(
    spec_strength = get_spectral_strength(weekly_sales),
    weeks_on_chart = n(),
    .groups = "drop"
  ) %>%
  mutate(log_spec_strength = log1p(spec_strength))

# --- Join popularity and genres ---
manga_genres <- manga %>%
  select(title_romaji, genres) %>%
  left_join(sales_popularity, by = "title_romaji") %>%
  filter(!is.na(total_sales), !is.na(genres)) %>%
  mutate(genres = strsplit(genres, ",\\s*"))

# --- Join with spectral scores and calculate log_popularity ---
model_data <- manga_genres %>%
  left_join(spectral_scores, by = "title_romaji") %>%
  filter(!is.na(log_spec_strength)) %>%
  mutate(log_popularity = log1p(total_sales)) %>% 
  distinct(title_romaji, .keep_all = TRUE)

# --- One-hot encode genres ---
model_data_long <- model_data %>% unnest(genres)

genre_dummies <- model_data_long %>%
  distinct(title_romaji, genres) %>%
  mutate(dummy = 1) %>%
  pivot_wider(
    names_from = genres,
    values_from = dummy,
    values_fill = list(dummy = 0)
  )

# --- Merge back with core modeling data ---
model_data <- genre_dummies %>%
  left_join(model_data %>% select(title_romaji, total_sales, log_popularity, log_spec_strength, spec_strength), by = "title_romaji") %>% 
  rename(popularity = total_sales)

# --- Genre fixed effects model (residualizing log popularity) ---
genre_only_model <- lm(log_popularity ~ . - log_spec_strength - title_romaji - popularity, data = model_data)
model_data$residual_log_popularity <- residuals(genre_only_model)

# --- Regression: residual log_popularity ~ log_spec_strength ---
resid_model <- lm(residual_log_popularity ~ log_spec_strength, data = model_data)
resid_summary <- summary(resid_model)

slope <- signif(resid_summary$coefficients["log_spec_strength", "Estimate"], 3)
r2 <- signif(resid_summary$adj.r.squared, 3)

# --- Plot ---
p <- ggplot(model_data, aes(x = log_spec_strength, y = residual_log_popularity)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(
    title = "Relationship Between Cyclical Sales Patterns and Popularity (Controlling for Genre)",
    x = "Cyclicality (Log Spectral Density)",
    y = "Total Log Sales (Residual from Genre Fixed Effects)",
    caption = paste0("Slope = ", slope, ", Adjusted R² = ", r2)
  ) +
  theme_minimal()

ggsave(file.path(output_dir, "spectral_strength_vs_genre_adjusted_log_popularity.png"),
       plot = p, width = 8, height = 6)
#####
demon_slayer <- manga_charts %>%
  filter(title_romaji == "kimetsu no yaiba") %>%
  arrange(reporting_week)  # make sure it's sorted chronologically

ggplot(demon_slayer, aes(x = reporting_week, y = weekly_sales)) +
  geom_line(color = "darkred", linewidth = 1) +
  labs(
    title = "Weekly Sales for Demon Slayer: Kimetsu no Yaiba",
    x = "Reporting Week",
    y = "Weekly Sales"
  ) +
  theme_minimal()
ggsave(file.path(output_dir, "one_piece_weekly_sales.png"),
       width = 8, height = 6)
#####

library(lfe)

# Step 1: Make genre dummy column names safe
genre_dummies <- genre_dummies %>%
  distinct(title_romaji, .keep_all = TRUE)

# Make safe column names
colnames(genre_dummies) <- make.names(colnames(genre_dummies))

# Step 2: Merge into main chart data
manga_charts_model <- manga_charts %>%
  left_join(model_data %>% select(title_romaji, log_spec_strength, log_popularity), by = "title_romaji") %>%
  left_join(genre_dummies, by = "title_romaji") %>%
  filter(!is.na(log_spec_strength), !is.na(log_popularity), !is.na(weekly_sales))

# Step 3: Get all genre columns except title_romaji
genre_cols <- names(genre_dummies)
genre_cols <- genre_cols[genre_cols != "title_romaji"]

# Step 4: Construct formula string
genre_formula <- paste(genre_cols, collapse = " + ")
model_formula_str <- paste("log1p(weekly_sales) ~ post_adaptation + log_spec_strength + log_popularity +", genre_formula, "| title_romaji + reporting_week")

# 4.5
manga_charts_model <- manga_charts_model %>%
  mutate(post_adaptation = ifelse(weeks_relative_to_end > 0, 1, 0))

# Step 5: Convert to formula and estimate model
model_formula <- as.formula(model_formula_str)
final_model <- felm(model_formula, data = manga_charts_model)

# View summary
summary(final_model)

# Run model summary separately to extract useful variable(s)
clean_model <- summary(final_model)

# Save a cleaned-up summary table with only post_adaptation
stargazer(final_model,
          type = "text",
          title = "Effect of Anime Ending on Weekly Manga Sales",
          keep = "post_adaptation",  # show only this variable
          out = file.path(output_dir, "clean_regression_results.html"),
          digits = 3,
          single.row = TRUE,
          star.cutoffs = c(0.05, 0.01, 0.001))

#####


