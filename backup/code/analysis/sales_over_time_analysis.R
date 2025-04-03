# Ensure final_date is in Date format
df <- df %>% mutate(final_date = as.Date(final_date))

# Aggregate total weekly sales over time
weekly_sales_trend <- df %>%
  group_by(final_date) %>%
  summarize(total_weekly_sales = sum(weekly, na.rm = TRUE)) %>%
  arrange(final_date)

# Plot the trend of weekly sales over time
ggplot(weekly_sales_trend, aes(x = final_date, y = total_weekly_sales)) +
  geom_line() + 
  geom_smooth(method = "loess", se = FALSE) + 
  labs(title = "Weekly Manga Sales Over Time",
       x = "Date",
       y = "Total Weekly Sales") +
  theme_minimal()

# Save the plot
ggsave(file.path(output_dir, "weekly_sales_trend.png"), width = 8, height = 6)
