source("housekeeping.R")

# --- Load data ---
manga_charts <- read_csv(file.path(clean_dir, "manga_charts_clean.csv"))
manga_adaptations <- read_csv(file.path(clean_dir, "manga_adaptations_clean.csv"))
manga <- read_csv(file.path(clean_dir, "manga_clean.csv"))
weekly_bounds <- read_csv(file.path(clean_dir, "weekly_bounds.csv"))

#####
# Get all unique series and all weeks
series_list <- unique(manga_charts$title_romaji)
week_list <- unique(weekly_bounds$reporting_week)

# Create complete grid of title_romaji × week
complete_weeks <- expand.grid(
  title_romaji = series_list,
  reporting_week = week_list
)

# Join with manga_charts and bounds
manga_charts_filled <- complete_weeks %>%
  left_join(manga_charts, by = c("title_romaji", "reporting_week")) %>%
  left_join(weekly_bounds, by = "reporting_week") %>%
  mutate(
    weekly_sales_imputed = ifelse(is.na(weekly_sales), min_weekly, weekly_sales),
    on_chart = !is.na(weekly_sales)
  ) %>% 
  select(-c(start_date, end_date))
# Ensure dates are date objects
manga_adaptations <- manga_adaptations %>%
  mutate(
    start_date = as.Date(start_date),
    end_date = as.Date(end_date)
  )
  
# Join adaptation dates
manga_charts_filled <- manga_charts_filled %>%
  left_join(
    manga_adaptations %>% select(title_romaji, start_date, end_date),
    by = "title_romaji"
  )
manga_charts_filled <- manga_charts_filled %>%
  mutate(
    period = case_when(
      reporting_week < start_date ~ "pre",
      reporting_week >= start_date & reporting_week <= end_date ~ "during",
      reporting_week > end_date ~ "post",
      TRUE ~ NA_character_
    )
  )

manga_charts_filled <- manga_charts_filled %>%
  mutate(
    weeks_relative_to_end = as.integer(difftime(reporting_week, end_date, units = "weeks"))
  )
#####
# --- Identify genre dummy columns ---
genre_cols <- names(manga_charts)[str_starts(names(manga_charts), "genre_")]

# --- Total sales by series ---
sales_popularity <- manga_charts_filled %>% 
  group_by(title_romaji) %>%
  summarise(total_sales = max(total_sales, na.rm = TRUE), .groups = "drop")

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

# --- Combine genre dummies + popularity + spectral scores ---
model_data <- manga_charts %>%
  select(title_romaji, all_of(genre_cols)) %>%
  distinct(title_romaji, .keep_all = TRUE) %>%
  left_join(sales_popularity, by = "title_romaji") %>%
  left_join(spectral_scores, by = "title_romaji") %>%
  filter(!is.na(log_spec_strength), !is.na(total_sales)) %>%
  mutate(log_popularity = log1p(total_sales))

# --- Residualize log popularity using genre fixed effects ---
genre_only_model <- lm(
  formula = as.formula(
    paste("log_popularity ~", paste0("`", genre_cols, "`", collapse = " + "))
  ),
  data = model_data
)
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
library(lfe)
library(dplyr)
library(ggplot2)

# --- Filter data to pre/post periods only, and ±20 weeks around the anime end
fe_data <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -20, 20)) %>%
  mutate(log_sales = log1p(weekly_sales_imputed))

# --- Optional: Drop high-cyclicality titles
low_cyclicality_titles <- spectral_scores %>%
  filter(log_spec_strength < quantile(log_spec_strength, 0.75, na.rm = TRUE)) %>%
  pull(title_romaji)

fe_data <- fe_data %>% filter(title_romaji %in% low_cyclicality_titles)

# --- Fixed effects regression: Does sales change after anime ends?
fe_model <- felm(
  log_sales ~ period | title_romaji + reporting_week,
  data = fe_data
)

summary(fe_model)

# --- Add residuals to visualize trend
fe_data$resid_log_sales <- resid(fe_model)

# --- Plot loess smoothed residuals
ggplot(fe_data, aes(x = weeks_relative_to_end, y = resid_log_sales, color = period)) +
  geom_smooth(method = "loess", span = 0.3, se = FALSE, linewidth = 1.2) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "FE Log Sales Residuals: Pre vs Post Anime Ending",
    x = "Weeks Since Anime Ended",
    y = "Residual Log(Weekly Sales + 1)",
    color = "Period"
  ) +
  theme_minimal()

# --- Save figure
ggsave(file.path(output_dir, "fe_log_sales_residuals_pre_post.png"), width = 8, height = 6)

stargazer(
  fe_model,
  type = "html",
  title = "Effect of Anime Ending on Weekly Manga Sales (FE Model)",
  keep = "periodpost",
  digits = 3,
  single.row = TRUE,
  out = file.path(output_dir, "anime_end_effect_fe_model.html")
)

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
plot_data <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -30, 30)) %>%
  group_by(period, weeks_relative_to_end) %>%
  summarise(
    avg_sales = mean(weekly_sales_imputed, na.rm = TRUE),
    .groups = "drop"
  )

ggplot(plot_data, aes(x = weeks_relative_to_end, y = avg_sales, color = period)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Average Manga Sales: Pre vs Post Anime Ending",
    x = "Weeks Since Anime Ended",
    y = "Average Weekly Sales",
    color = "Period"
  ) +
  theme_minimal()
ggsave(file.path(output_dir, "avg_sales_pre_post_anime_ending.png"),
       width = 8, height = 6)

####

library(lfe)  # for fast fixed effects with felm

# Only include pre/post weeks in the model
fe_data <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -30, 30)) %>%
  filter(!is.na(weekly_sales_imputed)) %>%
  mutate(log_sales = log1p(weekly_sales_imputed))

# Fit fixed effects model: sales ~ period + manga + week
fe_model_log <- felm(
  log_sales ~ period | title_romaji + reporting_week,
  data = fe_data
)

fe_data$resid_log <- resid(fe_model_log)


# Add residuals to the dataset
fe_data$resid_log <- resid(fe_model_log)

plot_fe <- fe_data %>%
  group_by(period, weeks_relative_to_end) %>%
  summarise(avg_resid = mean(resid_log, na.rm = TRUE), .groups = "drop")

ggplot(plot_fe, aes(x = weeks_relative_to_end, y = avg_resid, color = period)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Fixed-Effect Adjusted Sales: Pre vs Post Anime Ending",
    x = "Weeks Since Anime Ended",
    y = "Residual Weekly Log Sales (FE-adjusted)",
    color = "Period"
  ) +
  theme_minimal()
  ggsave(file.path(output_dir, "fe_adjusted_sales_pre_post_anime_ending.png"),
       width = 8, height = 6)

#####
## --- Spectral detrending: log1p sales + top 3 frequencies ---
get_spectral_fit_log <- function(sales_vector) {
  if (length(sales_vector) < 10 || all(sales_vector == 0)) {
    return(rep(NA, length(sales_vector)))
  }
  
  log_sales <- log1p(sales_vector)
  spec <- spectrum(log_sales, plot = FALSE)
  top_freqs <- spec$freq[order(spec$spec, decreasing = TRUE)][1:3]
  t <- seq_along(log_sales)
  
  fit <- rep(mean(log_sales), length(t))
  for (f in top_freqs) {
    fit <- fit + sd(log_sales) * sin(2 * pi * f * t)
  }
  
  return(fit)
}

# --- Apply spectral smoother ---
spectral_data <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -30, 30)) %>%
  filter(!is.na(weekly_sales_imputed)) %>%
  group_by(title_romaji) %>%
  arrange(reporting_week) %>%
  mutate(
    fitted_spectral_log = get_spectral_fit_log(weekly_sales_imputed),
    resid_spectral_log = log1p(weekly_sales_imputed) - fitted_spectral_log
  ) %>%
  ungroup()

# --- Plot spectrally detrended residuals ---
plot_spectral_log <- spectral_data %>%
  group_by(period, weeks_relative_to_end) %>%
  summarise(avg_resid = mean(resid_spectral_log, na.rm = TRUE), .groups = "drop")

ggplot(plot_spectral_log, aes(x = weeks_relative_to_end, y = avg_resid, color = period)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Spectrally Detrended Log Sales: Pre vs Post Anime Ending",
    x = "Weeks Since Anime Ended",
    y = "Residual Log Sales (Multi-Frequency Spectral Fit)",
    color = "Period"
  ) +
  theme_minimal()

ggsave(file.path(output_dir, "spectral_log_residuals_pre_post_anime_ending.png"),
       width = 8, height = 6)


# Filter to pre/post and limit weeks around the ending
loess_plot_data <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -30, 30)) %>%
  filter(!is.na(weekly_sales_imputed))

# Plot with loess smoothers by period
ggplot(loess_plot_data, aes(x = weeks_relative_to_end, y = weekly_sales_imputed, color = period)) +
  geom_smooth(method = "loess", se = FALSE, span = 0.3, size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Smoothed Weekly Manga Sales: Pre vs Post Anime Ending",
    x = "Weeks Since Anime Ended",
    y = "Weekly Sales (Imputed)",
    color = "Period"
  ) +
  theme_minimal()

# Filter and log-transform
loess_plot_data <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -30, 30)) %>%
  filter(!is.na(weekly_sales_imputed)) %>%
  mutate(log_sales = log1p(weekly_sales_imputed))

# Plot
ggplot(loess_plot_data, aes(x = weeks_relative_to_end, y = log_sales, color = period)) +
  geom_smooth(method = "loess", se = FALSE, span = 0.3, size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Smoothed Log Weekly Manga Sales: Pre vs Post Anime Ending",
    x = "Weeks Since Anime Ended",
    y = "Log(Weekly Sales + 1)",
    color = "Period"
  ) +
  theme_minimal()
#####
low_cyclicality_titles <- spectral_scores %>%
  filter(log_spec_strength < quantile(log_spec_strength, 0.25, na.rm = TRUE)) %>%
  pull(title_romaji)

manga_charts_low_cyc <- manga_charts_filled %>%
  filter(title_romaji %in% low_cyclicality_titles)

loess_plot_low <- manga_charts_low_cyc %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -30, 30)) %>%
  filter(!is.na(weekly_sales_imputed)) %>%
  mutate(log_sales = log1p(weekly_sales_imputed))

ggplot(loess_plot_low, aes(x = weeks_relative_to_end, y = log_sales, color = period)) +
  geom_smooth(method = "loess", se = FALSE, span = 0.3, size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Smoothed Log Weekly Manga Sales (Low-Cyclicality Only)",
    x = "Weeks Since Anime Ended",
    y = "Log(Weekly Sales + 1)",
    color = "Period"
  ) +
  theme_minimal()

library(lfe)

fe_data_low <- manga_charts_low_cyc %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -30, 30)) %>%
  filter(!is.na(weekly_sales_imputed)) %>%
  mutate(log_sales = log1p(weekly_sales_imputed))

fe_model_low_log <- felm(
  log_sales ~ period | title_romaji + reporting_week,
  data = fe_data_low
)

fe_data_low$resid_log <- resid(fe_model_low_log)

plot_fe_low <- fe_data_low %>%
  group_by(period, weeks_relative_to_end) %>%
  summarise(avg_resid = mean(resid_log, na.rm = TRUE), .groups = "drop")

ggplot(plot_fe_low, aes(x = weeks_relative_to_end, y = avg_resid, color = period)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "FE-Adjusted Log Sales (Low-Cyclicality Only)",
    x = "Weeks Since Anime Ended",
    y = "Residual Log Sales",
    color = "Period"
  ) +
  theme_minimal()

# Apply spectral smoother to log sales
spectral_data_low <- manga_charts_low_cyc %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -30, 30)) %>%
  filter(!is.na(weekly_sales_imputed)) %>%
  group_by(title_romaji) %>%
  arrange(reporting_week) %>%
  mutate(
    fitted_spectral_log = get_spectral_fit_log(weekly_sales_imputed),
    resid_spectral_log = log1p(weekly_sales_imputed) - fitted_spectral_log
  ) %>%
  ungroup()

plot_spectral_low <- spectral_data_low %>%
  group_by(period, weeks_relative_to_end) %>%
  summarise(avg_resid = mean(resid_spectral_log, na.rm = TRUE), .groups = "drop")

ggplot(plot_spectral_low, aes(x = weeks_relative_to_end, y = avg_resid, color = period)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Spectrally Detrended Log Sales (Low-Cyclicality Only)",
    x = "Weeks Since Anime Ended",
    y = "Residual Log Sales (Spectral Fit)",
    color = "Period"
  ) +
  theme_minimal()

ggsave(file.path(output_dir, "spectral_log_low_cyc_pre_post_anime_ending.png"),
       width = 8, height = 6)
#####
# Add the post adaptation dummy
manga_charts_model_low <- manga_charts_low_cyc %>%
  left_join(model_data %>% select(title_romaji, log_spec_strength, log_popularity), by = "title_romaji") %>%
  left_join(genre_dummies, by = "title_romaji") %>%
  mutate(post_adaptation = ifelse(weeks_relative_to_end > 0, 1, 0)) %>%
  filter(!is.na(log_spec_strength), !is.na(log_popularity), !is.na(weekly_sales))

# Make genre formula
genre_cols <- setdiff(names(genre_dummies), "title_romaji")
genre_formula <- paste(genre_cols, collapse = " + ")

# Build model formula string
model_formula_str <- paste("log1p(weekly_sales) ~ post_adaptation + log_spec_strength + log_popularity +", genre_formula, "| title_romaji + reporting_week")
model_formula <- as.formula(model_formula_str)

# Run the model
final_model_low <- felm(model_formula, data = manga_charts_model_low)

# Summary
summary(final_model_low)
#######
# Ge

fe_data_partial_impute <- fe_data_partial_impute %>%
  filter(title_romaji %in% medium_low_cyclicality_titles)

fe_data_partial_impute <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -40, 20)) %>%
  filter(on_chart | between(weeks_relative_to_end, -1, 1)) %>%
  mutate(log_sales = log1p(weekly_sales_imputed))
fe_model_log_partial <- felm(
  log_sales ~ period | title_romaji + reporting_week,
  data = fe_data_partial_impute
)

fe_data_partial_impute$resid_log_sales <- resid(fe_model_log_partial)

plot_fe_partial <- fe_data_partial_impute %>%
  group_by(period, weeks_relative_to_end) %>%
  summarise(avg_resid = mean(resid_log_sales, na.rm = TRUE), .groups = "drop")

ggplot(plot_fe_partial, aes(x = weeks_relative_to_end, y = avg_resid, color = period)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "FE Log Sales Residuals (Impute Only ±1 Week)",
    x = "Weeks Since Anime Ended",
    y = "Residual Log(Weekly Sales + 1)",
    color = "Period"
  ) +
  # dotted line -12 and -24
  geom_vline(xintercept = c(-12, -13), linetype = "dotted", color = "blue") +
  # label the dotted lines typical season
  annotate("text", x = -6.25, y = 1, label = "Typical Season Start", color = "blue", size = 2) +
  theme_minimal()

ggsave(file.path(output_dir, "linear_trends_pre_not_during.png"),
       width = 8, height = 6)
#####
# Recompute smoothed data
fe_data_plot <- fe_data_partial_impute %>%
  filter(!is.na(resid_log_sales))  # ensure no junk values

# Compute average only for the shaded region (-13 to -1)
avg_pre_anime_window <- fe_data_plot %>%
  filter(weeks_relative_to_end >= -13, weeks_relative_to_end <= -1) %>%
  summarise(mean_resid = mean(resid_log_sales, na.rm = TRUE)) %>%
  pull(mean_resid)

# Plot with fixed y-axis
ggplot(fe_data_plot, aes(x = weeks_relative_to_end, y = resid_log_sales, color = period)) +
  geom_smooth(method = "loess", se = FALSE, span = 0.3, size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  annotate("rect", xmin = -13, xmax = -1, ymin = -0.15, ymax = 0.15,
           alpha = 0.1, fill = "blue") +
  annotate("text", x = -7, y = 0.14, label = "Anime Broadcast Window", color = "blue", hjust = 0.5) +
  geom_hline(yintercept = avg_pre_anime_window, linetype = "dotted", color = "blue") +
  scale_y_continuous(limits = c(-0.15, 0.15)) +
  labs(
    title = "Volatility During Anime Broadcast Window",
    x = "Weeks Since Anime Ended",
    y = "Residual Log(Weekly Sales + 1)",
    color = "Period"
  ) +
  theme_minimal()

ggsave(file.path(output_dir, "clean_loess_broadcast_volatility.png"),
       width = 8, height = 6)

# Filter to medium/low-cyclicality titles (already done earlier)
fe_data_partial_impute <- fe_data_partial_impute %>%
  filter(title_romaji %in% medium_low_cyclicality_titles)

# Refit FE model on this subset
fe_model_final <- felm(
  log_sales ~ period | title_romaji + reporting_week,
  data = fe_data_partial_impute
)

summary(fe_model_final)
#####
# Filter to medium/low-cyclicality titles (already done earlier)
fe_data_partial_impute <- fe_data_partial_impute %>%
  filter(title_romaji %in% medium_low_cyclicality_titles)

# Refit FE model on this subset
fe_model_final <- felm(
  log_sales ~ period | title_romaji + reporting_week,
  data = fe_data_partial_impute
)

summary(fe_model_final)
#########
library(dplyr)
library(lfe)
library(ggplot2)
library(stargazer)

# --- Filter to ±20 weeks and impute only ±1 week off-chart ---
fe_data_partial_impute <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -40, 20)) %>% 
  mutate(log_sales = log1p(weekly_sales_imputed))

####
# --- Plot average log sales by period and relative week
plot_log_partial <- fe_data_partial_impute %>%
  group_by(period, weeks_relative_to_end) %>%
  summarise(avg_log_sales = mean(log_sales, na.rm = TRUE), .groups = "drop")

ggplot(plot_log_partial, aes(x = weeks_relative_to_end, y = avg_log_sales, color = period)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  geom_vline(xintercept = c(-12, -13), linetype = "dotted", color = "blue") +
  annotate("text", x = -6.25, y = max(plot_log_partial$avg_log_sales), 
           label = "Typical Season Start", color = "blue", size = 2) +
  labs(
    title = "Avg. Log(Weekly Sales + 1) by Anime Ending Proximity",
    x = "Weeks Since Anime Ended",
    y = "Log(Weekly Sales + 1)",
    color = "Period"
  ) +
  theme_minimal()
ggsave(file.path(output_dir, "avg_log_sales_full_impute.png"),
       width = 8, height = 6)
####
# --- FE Regression (title + week fixed effects)
fe_model_log_partial <- felm(
  log_sales ~ period | title_romaji + reporting_week,
  data = fe_data_partial_impute
)

# --- Residuals for plotting
fe_data_partial_impute$resid_log_sales <- resid(fe_model_log_partial)

# --- Plot residual sales by period
plot_fe_partial <- fe_data_partial_impute %>%
  group_by(period, weeks_relative_to_end) %>%
  summarise(avg_resid = mean(resid_log_sales, na.rm = TRUE), .groups = "drop")

ggplot(plot_fe_partial, aes(x = weeks_relative_to_end, y = avg_resid, color = period)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  geom_vline(xintercept = c(-12, -13), linetype = "dotted", color = "blue") +
  annotate("text", x = -6.25, y = 1, label = "Typical Season Start", color = "blue", size = 2) +
  labs(
    title = "FE Log Sales Residuals (Impute Only ±1 Week)",
    x = "Weeks Since Anime Ended",
    y = "Residual Log(Weekly Sales + 1)",
    color = "Period"
  ) +
  theme_minimal()

ggsave(file.path(output_dir, "fe_log_residuals_partial_impute.png"),
       width = 8, height = 6)
stargazer(
  fe_model_log_partial,
  type = "latex",
  title = "Fixed Effects Regression: Sales Before and After Anime Ends",
  keep = "periodpre",
  dep.var.labels = "log(Weekly Sales + 1)",
  covariate.labels = "Pre-Adaptation Period",
  digits = 3,
  single.row = TRUE,
  out = file.path(output_dir, "fe_model_partial_impute.html")
)

#####

library(ggplot2)
library(lubridate)
library(dplyr)

# Years to include
years_to_plot <- 2009:2023

# Prepare weekly total sales per year and log-transform
sales_by_week <- manga_charts_filled %>%
  filter(year(reporting_week) %in% years_to_plot) %>%
  mutate(year = year(reporting_week)) %>%
  group_by(reporting_week, year) %>%
  summarise(total_sales = sum(weekly_sales_imputed, na.rm = TRUE), .groups = "drop") %>%
  mutate(log_total_sales = log1p(total_sales))

# Prepare season start dates for each year
season_starts_df <- lapply(years_to_plot, function(yr) {
  data.frame(
    year = yr,
    season = c("Winter", "Spring", "Summer", "Fall"),
    date = as.Date(c(
      paste0(yr, "-01-01"),
      paste0(yr, "-04-01"),
      paste0(yr, "-07-01"),
      paste0(yr, "-10-01")
    ))
  )
}) %>% bind_rows()

# Plot with facets
ggplot(sales_by_week, aes(x = reporting_week, y = log_total_sales)) +
  geom_line(color = "black") +
  geom_vline(data = season_starts_df, aes(xintercept = date), linetype = "dashed", color = "blue") +
  facet_wrap(~year, scales = "free_x") +
  labs(
    title = "Log-Transformed Total Weekly Manga Sales (2009–2023)",
    x = "Week",
    y = "log(1 + Total Weekly Sales)",
    caption = "Dashed lines = anime season starts"
  ) +
  theme_minimal() +
  theme(strip.text = element_text(face = "bold"))
ggsave(file.path(output_dir, "weekly_sales_by_year.png"),
       width = 12, height = 8)

#####
fe_data_partial_impute <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -40, 40)) %>%
  filter(on_chart | between(weeks_relative_to_end, -4, 4)) %>%
  mutate(
    log_sales = log1p(weekly_sales_imputed),
    anime_season = case_when(
      month(end_date) %in% 1:3 ~ "Winter",
      month(end_date) %in% 4:6 ~ "Spring",
      month(end_date) %in% 7:9 ~ "Summer",
      month(end_date) %in% 10:12 ~ "Fall",
      TRUE ~ NA_character_
    )
  )
fe_model_all_controls <- felm(
  log_sales ~ period | title_romaji + reporting_week + anime_season,
  data = fe_data_partial_impute
)

# Add residuals
fe_data_partial_impute$resid_log_sales <- resid(fe_model_all_controls)

plot_fe_partial <- fe_data_partial_impute %>%
  group_by(weeks_relative_to_end) %>%
  summarise(avg_resid = mean(resid_log_sales, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    block = floor(weeks_relative_to_end / 13),
    block_label = paste0("Block ", block)
  )

# Define where block boundaries are (excluding 0)
block_boundaries <- seq(-39, 26, by = 13)
block_boundaries <- block_boundaries[block_boundaries != 0]  # remove center if needed

ggplot(plot_fe_partial, aes(x = weeks_relative_to_end, y = avg_resid, color = block_label)) +
  geom_line(size = 1.1) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  geom_vline(xintercept = block_boundaries, linetype = "dotted", color = "gray50") +
  labs(
    title = "Residual Log(Weekly Sales + 1), Colored by 13-Week Blocks",
    x = "Weeks Since Anime Ended",
    y = "Residual Log Sales",
    color = "13-Week Block"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    legend.title = element_text(size = 10),
    legend.text = element_text(size = 8),
    strip.text = element_text(face = "bold")
  )
ggsave(file.path(output_dir, "residual_log_sales_13_week_blocks.png"),
       width = 8, height = 6)

#####
fe_data_partial_impute <- manga_charts_filled %>%
  filter(period %in% c("pre", "post")) %>%
  filter(between(weeks_relative_to_end, -40, 40)) %>%
  filter(on_chart | between(weeks_relative_to_end, -4, 4)) %>%
  mutate(
    log_sales = log1p(weekly_sales_imputed),
    anime_season = case_when(
      month(end_date) %in% 1:3 ~ "Winter",
      month(end_date) %in% 4:6 ~ "Spring",
      month(end_date) %in% 7:9 ~ "Summer",
      month(end_date) %in% 10:12 ~ "Fall",
      TRUE ~ NA_character_
    )
  )

fe_model_all_controls <- felm(
  log_sales ~ period | title_romaji + reporting_week + anime_season,
  data = fe_data_partial_impute
)

# Add residuals back to same frame
fe_data_partial_impute$resid_log_sales <- resid(fe_model_all_controls)

plot_fe_partial <- fe_data_partial_impute %>%
  filter(weeks_relative_to_end <= 20) %>%
  group_by(weeks_relative_to_end) %>%
  summarise(avg_resid = mean(resid_log_sales, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    block = floor(weeks_relative_to_end / 13),
    block_label = paste0("Block ", block)
  )
ggplot(plot_fe_partial, aes(x = weeks_relative_to_end, y = avg_resid, color = block_label)) +
  geom_line(size = 1.1) +
  geom_point(size = 1.2, alpha = 0.6) +  # optional dots for emphasis
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  geom_vline(xintercept = block_boundaries, linetype = "dotted", color = "gray50") +
  scale_color_brewer(palette = "Set1") +  # or another discrete palette
  labs(
    title = "Residual Log(Weekly Sales + 1), Colored by 13-Week Blocks",
    x = "Weeks Since Anime Ended",
    y = "Residual Log Sales",
    color = "13-Week Block"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    legend.title = element_text(size = 10),
    legend.text = element_text(size = 8)
  )
