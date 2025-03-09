source('housekeeping.R')

# Read in .csv files
index <- read_csv(file.path(raw_dir, "anime_data.csv"))

# Remove "N/A" values from the index
index <- subset(index, !apply(index == "N/A", 1, any, na.rm = TRUE))

# Make headings lowercase for easier merging
index <- index %>%
  rename_all(tolower)
             