# Read in .csv files
charts <- read_csv(file.path(raw_dir, "oricon_all_charts_sorted.csv"))

# Extract month and day values
charts <- charts %>%
  mutate(cleaned_date_range = str_squish(`Date Range`)) %>%
  rowwise() %>%
  mutate(
    # Extract months and days
    months = list(str_extract_all(cleaned_date_range, paste(month.name, collapse = "|"))[[1]]),
    days = list(as.integer(str_extract_all(cleaned_date_range, "\\d+")[[1]])),
    
    # Month 1 (first detected)
    month1 = months[1],
    
    # Month 2 (second detected, or same as Month 1 if missing)
    month2 = ifelse(length(months) > 1, months[2], month1),
    
    # Day 1 (first detected)
    day1 = days[1],
    
    # Day 2 (last detected)
    day2 = days[length(days)],
    
    # Convert month2 to numeric safely
    month2 = ifelse(!is.na(month2), match(month2, month.name), NA_integer_)) %>%
  ungroup()

charts_cleaned <- charts %>% 
  mutate(final_date = make_date(Year, month2, day2)) %>% 
  select(TITLE, WEEKLY, TOTAL, final_date, Year, month2, day2)

# Check for any negative differences in the dates (dates from scraping incorrect)
# Remove the first one because that's a header error
error_rows <- which(diff(charts_cleaned$final_date) < 0)[-1]

charts_corrections <- charts_cleaned %>%
  mutate(
    month2 = ifelse(row_number() >= 351 & row_number() <= 450, 5, month2),  # Change month to May
    month2 = ifelse(row_number() >= 36961 & row_number() <= 37160, 12, month2),  # Change month to December
    Year = ifelse(row_number() >= 2731 & row_number() <= 2880, 2008, Year),  # Change Year to 2008
    Year = ifelse(row_number() >= 4311 & row_number() <= 4460, 2009, Year),  # Change Year to 2009
    Year = ifelse(row_number() >= 5841 & row_number() <= 5990, 2010, Year),  # Change Year to 2010
    Year = ifelse(row_number() >= 7761 & row_number() <= 8010, 2011, Year),  # Change Year to 2011
    Year = ifelse(row_number() >= 10081 & row_number() <= 10660, 2012, Year),  # Change Year to 2012
    Year = ifelse(row_number() >= 12760 & row_number() <= 13260, 2013, Year),  # Change Year to 2013
    Year = ifelse(row_number() >= 15560 & row_number() <= 15860, 2014, Year),  # Change Year to 2014
    Year = ifelse(row_number() >= 18060 & row_number() <= 18460, 2015, Year),  # Change Year to 2015
    Year = ifelse(row_number() >= 20460 & row_number() <= 21060, 2016, Year),  # Change Year to 2016
    Year = ifelse(row_number() >= 23160 & row_number() <= 23710, 2017, Year),  # Change Year to 2017
    Year = ifelse(row_number() >= 25860 & row_number() <= 26310, 2018, Year),  # Change Year to 2018
    Year = ifelse(row_number() >= 28560 & row_number() <= 28910, 2019, Year),  # Change Year to 2019
    Year = ifelse(row_number() >= 31260 & row_number() <= 31510, 2020, Year),  # Change Year to 2020
    Year = ifelse(row_number() >= 33960 & row_number() <= 34560, 2021, Year),  # Change Year to 2021
    Year = ifelse(row_number() >= 36660 & row_number() <= 37160, 2022, Year),  # Change Year to 2022

    final_date = make_date(Year, month2, day2)  # Recalculate final date
  ) %>% 
  select(TITLE, WEEKLY, TOTAL, final_date)

# Check for any negative differences in the dates (dates from scraping incorrect)
all(diff(charts_corrections$final_date) >= 0)
which(diff(charts_corrections$final_date) < 0)

charts_corrections <- charts_corrections %>%
  mutate(
    # Clean the WEEKLY and TOTAL columns: Remove '*' and convert to numeric
    WEEKLY = as.numeric(str_replace_all(WEEKLY, "[^0-9.]", "")),
    TOTAL = as.numeric(str_replace_all(TOTAL, "[^0-9.]", "")),
    
    # Create a new Series column by removing volume numbers from TITLE
    SERIES = str_trim(str_remove(TITLE, " #\\d+"))
  ) %>%
  select(SERIES, TITLE, WEEKLY, TOTAL, final_date)  # Keep only relevant columns

# Rename columns to lowercase
charts_corrections <- charts_corrections %>%
  rename_with(tolower)

# Save the cleaned data
write_csv(charts_corrections, file.path(clean_dir, "oricon_all_charts_cleaned.csv"))
