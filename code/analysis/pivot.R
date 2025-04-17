# --- Load data ---
source('housekeeping.R')

manga_charts <- read_csv(file.path(clean_dir, "manga_charts_clean.csv")) %>%
  mutate(reporting_week = as.Date(reporting_week)) %>%
  # remove if end_date-start_date is greater than 13 weeks
  filter(as.numeric(end_date - start_date) <= 91) %>% 
  filter(format == "TV")

agg_sales <- manga_charts %>%
  filter(between(weeks_relative_to_end, -40, 40)) %>%
  group_by(weeks_relative_to_end) %>%
  summarise(total_sales = sum(weekly_sales, na.rm = TRUE), .groups = "drop")

ggplot(agg_sales, aes(x = weeks_relative_to_end, y = total_sales)) +
  geom_line(linewidth = 0.5, color = "darkgreen") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "black") +      # End
  geom_vline(xintercept = -13, linetype = "dotted", color = "blue") +     # Start
  annotate("text", x = -13, y = max(agg_sales$total_sales, na.rm = TRUE) * 0.95,
           label = "Approx. Start", angle = 90, vjust = -0.5, size = 3, color = "blue") +
  labs(
    title = "Aggregate Weekly Manga Sales Around Anime Endings",
    subtitle = "Filtered for Short (≤13 Weeks) Adaptations Ending After 2019",
    x = "Weeks Relative to Anime End",
    y = "Total Weekly Sales"
  ) +
  theme_minimal()
ggsave(file.path(output_dir, "agg_sales_end.png"), width = 8, height = 5, dpi = 300)

#####

agg_sales_start <- manga_charts %>%
  filter(between(weeks_relative_to_start, -20, 40)) %>%
  group_by(weeks_relative_to_start) %>%
  summarise(total_sales = sum(weekly_sales, na.rm = TRUE), .groups = "drop")

ggplot(agg_sales_start, aes(x = weeks_relative_to_start, y = total_sales)) +
  geom_line(linewidth = 0.5, color = "steelblue") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "black") +       # Start
  labs(
    title = "Aggregate Weekly Manga Sales Around Anime Start",
    subtitle = "Filtered for Short (≤13 Weeks) TV Adaptations Ending After 2019",
    x = "Weeks Relative to Anime Start",
    y = "Total Weekly Sales"
  ) +
  theme_minimal()
ggsave(file.path(output_dir, "agg_sales_start.png"), width = 8, height = 5, dpi = 300)

#####
# --- Prepare data ---
rdd_data_start <- manga_charts %>%
  filter(between(weeks_relative_to_start, -20, 20)) %>%
  mutate(
    running = weeks_relative_to_start,
    post = if_else(running >= 0, 1, 0)
  )

# --- Create RDD object ---
library(rddtools)

rdd_object_start <- rdd_data(y = rdd_data_start$weekly_sales,
                             x = rdd_data_start$running,
                             cutpoint = 0)

# --- Estimate local linear model ---
rdd_reg_start <- rdd_reg_lm(rdd_object_start, order = 1)
summary(rdd_reg_start)

# --- Estimate optimal bandwidth (IK) ---
bw_start <- rdd_bw_ik(rdd_object_start)
summary(bw_start)

# --- Re-estimate model within bandwidth ---
rdd_reg_start_bw <- rdd_reg_lm(rdd_object_start, bw = bw_start, order = 1)
summary(rdd_reg_start_bw)
# --- Plot results ---# --- Bin and summarize sales by week relative to start ---
plot_data_start <- rdd_data_start %>%
  filter(abs(running) <= 20) %>%
  group_by(running) %>%
  summarise(total_sales = sum(weekly_sales, na.rm = TRUE), .groups = "drop")

# --- Plot binned averages and separate linear trends ---
ggplot(plot_data_start, aes(x = running, y = total_sales)) +
  geom_point(size = 1.5, alpha = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_smooth(data = filter(plot_data_start, running < 0), method = "lm", se = FALSE, color = "red") +
  geom_smooth(data = filter(plot_data_start, running >= 0), method = "lm", se = FALSE, color = "blue") +
  labs(
    title = "RDD Visualization: Manga Sales Before and After Anime Start",
    subtitle = "Local linear fits ±20 weeks",
    x = "Weeks Relative to Anime Start",
    y = "Mean Weekly Sales"
  ) +
  theme_minimal()

#####
# Set new cutoff 3 weeks *before* airing
rdd_data_start_shifted <- rdd_data_start %>%
  mutate(running_shifted = running + 3)  # Shift treatment window left

plot_data_start_shifted <- rdd_data_start_shifted %>%
  filter(abs(running_shifted) <= 20) %>%
  group_by(running_shifted) %>%
  summarise(total_sales = sum(weekly_sales, na.rm = TRUE), .groups = "drop")

ggplot(plot_data_start_shifted, aes(x = running_shifted, y = total_sales)) +
  geom_point(size = 1.5, alpha = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_smooth(data = filter(plot_data_start_shifted, running_shifted < 0), method = "lm", se = FALSE, color = "red") +
  geom_smooth(data = filter(plot_data_start_shifted, running_shifted >= 0), method = "lm", se = FALSE, color = "blue") +
  labs(
    title = "RDD Visualization: Manga Sales Before Anticipated Anime Start",
    subtitle = "Cutoff set ~3 weeks before airing; local linear fits ±20 weeks",
    x = "Weeks Relative to Early Anticipation Window",
    y = "Total Weekly Sales"
  ) +
  theme_minimal()
ggsave(file.path(output_dir, "rdd_start_shifted.png"), width = 8, height = 5, dpi = 300)

#####

# --- Set new cutoff 3 weeks *before* airing ---
rdd_data_start_shifted <- rdd_data_start %>%
  mutate(running_shifted = running + 3)  # Shift treatment window left

# --- Bin and log-aggregate sales by shifted week ---
plot_data_start_shifted <- rdd_data_start_shifted %>%
  filter(abs(running_shifted) <= 20) %>%
  group_by(running_shifted) %>%
  summarise(
    total_sales = sum(weekly_sales, na.rm = TRUE),
    log_sales = log1p(total_sales),
    .groups = "drop"
  )

# --- Plot ---
ggplot(plot_data_start_shifted, aes(x = running_shifted, y = log_sales)) +
  geom_point(size = 1.5, alpha = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_smooth(data = filter(plot_data_start_shifted, running_shifted < 0), method = "lm", se = FALSE, color = "red") +
  geom_smooth(data = filter(plot_data_start_shifted, running_shifted >= 0), method = "lm", se = FALSE, color = "blue") +
  labs(
    title = "RDD Visualization (Log Scale): Manga Sales Before Anticipated Anime Start",
    subtitle = "Cutoff set ~3 weeks before airing; log-transformed total sales, ±20 weeks",
    x = "Weeks Relative to Early Anticipation Window",
    y = "log(1 + Total Weekly Sales)"
  ) +
  theme_minimal()
ggsave(file.path(output_dir, "rdd_start_shifted_log.png"), width = 8, height = 5, dpi = 300)
#####
# --- Shift treatment window 3 weeks earlier ---
rdd_data_start_shifted <- rdd_data_start %>%
  mutate(running_shifted = running + 3)

# --- Bin into 2-week intervals ---
plot_data_binned <- rdd_data_start_shifted %>%
  mutate(week_bin = floor(running_shifted / 2) * 2) %>%  # Create 2-week bins like -18, -15, ..., 0, 3, ...
  filter(abs(week_bin) <= 17) %>%
  group_by(week_bin) %>%
  summarise(
    total_sales = sum(weekly_sales, na.rm = TRUE),
    log_sales = log1p(total_sales),
    .groups = "drop"
  )

# --- Plot ---
premiere_week <- 3
finale_week <- 16

ggplot(plot_data_binned, aes(x = week_bin, y = log_sales)) +
  geom_point(size = 1.5, alpha = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "black") +  # anticipation cutoff
  geom_vline(xintercept = premiere_week, linetype = "dotted", color = "blue") +  # premiere
  geom_vline(xintercept = finale_week, linetype = "dotted", color = "purple") +  # finale
  geom_smooth(data = filter(plot_data_binned, week_bin < 0), aes(x = week_bin, y = log_sales),
              method = "lm", se = FALSE, color = "red") +
  geom_smooth(data = filter(plot_data_binned, week_bin >= 0), aes(x = week_bin, y = log_sales),
              method = "lm", se = FALSE, color = "blue") +
  labs(
    title = "RDD Visualization (Log Scale, 2-Week Bins)",
    subtitle = "Bars show log(1 + total sales); vertical lines = anticipation (dashed), premiere/finale (dotted)",
    x = "Binned Weeks Relative to Early Anticipation Window",
    y = "log(1 + Total Weekly Sales)"
  ) +
  theme_minimal()
ggsave(file.path(output_dir, "rdd_start_shifted_binned.png"), width = 8, height = 5, dpi = 300)

#####

rdd_data_start_shifted %>%
  filter(abs(running_shifted) <= 20) %>%
  summarise(
    pre_count = sum(running_shifted < 0, na.rm = TRUE),
    post_count = sum(running_shifted >= 0, na.rm = TRUE),
    total = n()
  )

#####
  
  series_pre_presence <- rdd_data_start_shifted %>%
    filter(running_shifted < 0) %>%
    group_by(title_romaji) %>%
    summarise(pre_on_chart = any(!is.na(weekly_sales)), .groups = "drop")  # TRUE if ever on chart pre
  
  # Merge flag into original data
  rdd_data_start_shifted <- rdd_data_start_shifted %>%
    left_join(series_pre_presence, by = "title_romaji") %>%
    mutate(pre_on_chart = ifelse(is.na(pre_on_chart), FALSE, pre_on_chart),  # if not present at all, set FALSE
           never_on_chart_pre = !pre_on_chart)  # TRUE if never on chart before
  library(janitor)
  
  rdd_data_start_shifted <- rdd_data_start_shifted %>%
    clean_names()
  # Step 1: Collapse to one row per series
  genre_chart_status <- rdd_data_start_shifted %>%
    group_by(title_romaji) %>%
    summarise(
      never_on_chart_pre = any(never_on_chart_pre),
      across(starts_with("genre_"), ~ any(.x == 1)),
      .groups = "drop"
    )
  
  # Step 2: Calculate % of never-on-chart-pre per genre
  genre_summary <- genre_chart_status %>%
    pivot_longer(cols = starts_with("genre_"), names_to = "genre", values_to = "has_genre") %>%
    filter(has_genre) %>%
    group_by(genre) %>%
    summarise(
      total_series = n(),
      never_on_chart_pre_count = sum(never_on_chart_pre),
      percent_never_on_chart_pre = mean(never_on_chart_pre),
      .groups = "drop"
    ) %>%
    arrange(desc(percent_never_on_chart_pre))
  
  genre_summary %>% 
    arrange(percent_never_on_chart_pre) %>% 
    head(8)

#####

# --- Filter only series that *were* on the chart before the adaptation ---
rdd_filtered <- rdd_data_start_shifted %>%
  filter(never_on_chart_pre == FALSE)

# --- Shift treatment window 3 weeks earlier ---
rdd_filtered <- rdd_filtered %>%
  mutate(running_shifted = running + 3)

# --- Bin into 2-week intervals ---
plot_data_binned <- rdd_filtered %>%
  mutate(week_bin = floor(running_shifted / 2) * 2) %>%
  filter(abs(week_bin) <= 17) %>%
  group_by(week_bin) %>%
  summarise(
    total_sales = sum(weekly_sales, na.rm = TRUE),
    log_sales = log1p(total_sales),
    .groups = "drop"
  )

# --- Plot ---
premiere_week <- 3
finale_week <- 16

ggplot(plot_data_binned, aes(x = week_bin, y = log_sales)) +
  geom_point(size = 1.5, alpha = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "black") +
  geom_vline(xintercept = premiere_week, linetype = "dotted", color = "blue") +
  geom_vline(xintercept = finale_week, linetype = "dotted", color = "purple") +
  geom_smooth(data = filter(plot_data_binned, week_bin < 0), aes(x = week_bin, y = log_sales),
              method = "lm", se = FALSE, color = "red") +
  geom_smooth(data = filter(plot_data_binned, week_bin >= 0), aes(x = week_bin, y = log_sales),
              method = "lm", se = FALSE, color = "blue") +
  labs(
    title = "RDD: Only Series With Pre-Adaptation Chart Presence",
    subtitle = "Log-scale weekly sales; vertical lines = anticipation (dashed), premiere/finale (dotted)",
    x = "Weeks Relative to Anticipation Cutoff",
    y = "log(1 + Total Weekly Sales)"
  ) +
  theme_minimal()

ggsave(file.path(output_dir, "rdd_start_filtered_pre_on_chart.png"), width = 8, height = 5, dpi = 300)

rdd_filtered %>%
  filter(abs(running_shifted) <= 20) %>%
  summarise(
    pre_count = sum(running_shifted < 0, na.rm = TRUE),
    post_count = sum(running_shifted > 0, na.rm = TRUE),
    total = n()
  )

#####
# Step 1: Collapse to one row per series, keeping only genre info
genre_overall <- rdd_data_start_shifted %>%
  group_by(title_romaji) %>%
  summarise(
    across(starts_with("genre_"), ~ any(.x == 1)),
    .groups = "drop"
  )

# Step 2: Count how many series fall into each genre
genre_summary_all <- genre_overall %>%
  pivot_longer(cols = starts_with("genre_"), names_to = "genre", values_to = "has_genre") %>%
  filter(has_genre) %>%
  group_by(genre) %>%
  summarise(
    total_series = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(total_series))

genre_summary_all %>% 
  arrange(desc(total_series)) %>% 
  head(5)
######
# Collapse to one row per series with a flag for whether it was ever on the chart pre-airing
series_pre_chart_status <- rdd_data_start_shifted %>%
  group_by(title_romaji) %>%
  summarise(never_on_chart_pre = any(never_on_chart_pre), .groups = "drop")

# Calculate the overall proportion
overall_proportion <- series_pre_chart_status %>%
  summarise(percent_never_on_chart_pre = mean(never_on_chart_pre))

# View result
overall_proportion
