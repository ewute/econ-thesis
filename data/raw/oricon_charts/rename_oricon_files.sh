#!/bin/bash

# Loop through all files matching the pattern
for file in oricon_chart_*.csv; do
    # Rename the file by replacing "oricon_chart_" with "oricon_charts_"
    mv "$file" "${file/oricon_chart_/oricon_charts_}"
done

echo "Renaming completed."
