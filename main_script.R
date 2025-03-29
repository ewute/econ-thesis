source('housekeeping.R')

# Data processing
# Clean charts and index
source(file.path(code_dir, "processing", "clean_charts.R"))
source(file.path(code_dir, "processing", "clean_index.R"))

# Data analysis
source(file.path(code_dir, "analysis", "fe_days_summary.R"))

# Data visualization

# Causal inference