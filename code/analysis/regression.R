source('housekeeping.R')

# --- Load Data ---
manga <- read_csv(file.path(clean_dir, "manga_clean.csv"))
manga_adaptations <- read_csv(file.path(clean_dir, "manga_adaptations_clean.csv"))
charts <- read_csv(file.path(clean_dir, "manga_charts_clean.csv"))

# --- Filter event window around anime end date ---
event_window <- charts %>%
  filter(!is.na(weeks_relative_to_end)) %>%
  filter(between(weeks_relative_to_end, -12, 12))

# --- Plot sales trend around anime end ---

p <- ggplot(event_window, aes(x = weeks_relative_to_end, y = weekly_sales)) +
  geom_smooth(method = "loess", se = FALSE, color = "blue") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Weekly Manga Sales Before and After Anime End",
    x = "Weeks Relative to Anime End",
    y = "Weekly Sales"
  ) +
  theme_minimal()

ggsave(file.path(output_dir, "event_study_plot.png"), plot = p, width = 8, height = 6)

# --- Create Post-Anime Dummy ---
event_window <- event_window %>%
  mutate(post = if_else(weeks_relative_to_end > 0, 1, 0))
