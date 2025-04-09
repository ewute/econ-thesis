#!/bin/bash

output_file="manga_data.csv"
rm -f "$output_file"

# Canonical CSV header (your desired column order)
canonical_header="search_title,series,Manga_Title_Romaji,Manga_ID,MAL_ID,Manga_Format,Manga_Status,Manga_Chapters,Manga_Volumes,Manga_Source,Manga_Country,Manga_MeanScore,Manga_Popularity,Manga_Trending,Manga_Favourites,Manga_Genres,Manga_StartDate,Manga_EndDate,Manga_Tags,Manga_IsAdult"

# Write the correct header once
echo "$canonical_header" > "$output_file"

# Convert to array
IFS=',' read -r -a canonical_cols <<< "$canonical_header"

for i in $(seq 1 527); do
    file="manga_data_batch_${i}.csv"
    if [[ -f "$file" ]]; then
        echo "Processing: $file"

        # Read the header from the file
        IFS=',' read -r -a file_cols < <(head -n 1 "$file")

        # Build index map from canonical to actual positions
        declare -A col_map
        for j in "${!file_cols[@]}"; do
            col_map["${file_cols[$j]}"]=$((j + 1))
        done

        # Build awk print statement
        awk_expr='BEGIN { FS=OFS="," } NR>1 {'
        for col in "${canonical_cols[@]}"; do
            if [[ -n "${col_map[$col]}" ]]; then
                awk_expr+=" printf \"%s\", \$$((col_map[$col]));"
            else
                awk_expr+=' printf "%s", "";'
            fi
            awk_expr+=' printf OFS;'
        done
        awk_expr=''"$awk_expr"' printf "\n" }'

        tail -n +2 "$file" | awk "$awk_expr" >> "$output_file"
    else
        echo "Missing: $file"
    fi
done

echo "✅ All files normalized and combined into: $output_file"

