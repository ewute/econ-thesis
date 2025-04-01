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

# Summary statistics of adaptation_count
summary(df$adaptation_count)
