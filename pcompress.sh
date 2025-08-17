#!/bin/bash
#
# Batch JPEG recompression script for macOS
# - Uses jpeg-recompress for high-quality size reduction
# - Preserves EXIF (including GPS) and file creation/modification dates
# - Displays progress counter and SSIM stats
#
# Usage:
#   ./compress.sh
#

# Count total number of JPG/JPEG files
total=$(find . -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) | wc -l | tr -d ' ')
if [[ "$total" -eq 0 ]]; then
    echo "No JPG/JPEG files found."
    exit 0
fi

echo "Found $total image(s) to check."
echo

i=0
# Loop through each file
find . -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -print0 | while IFS= read -r -d '' src; do
    i=$((i+1))
    echo "[$i/$total] Processing: $src"

    tmp="${src}.opt.jpg"

    # Run jpeg-recompress, capture output
    output=$(jpeg-recompress --strip --quality high "$src" "$tmp" 2>&1)

    # Check if jpeg-recompress says the file is already optimized
    if echo "$output" | grep -q "File already processed by jpeg-recompress!"; then
        echo "    jpeg-recompress reported: already optimized, skipping."
        rm -f "$tmp" 2>/dev/null
        echo
        continue
    fi

    # Show jpeg-recompress output
    echo "$output"

    # If no optimized file was produced, skip
    if [[ ! -f "$tmp" ]]; then
        echo "    No optimized file produced, skipping."
        echo
        continue
    fi

    # Copy EXIF metadata back from original
    exiftool -TagsFromFile "$src" -All:All -overwrite_original "$tmp" > /dev/null

    # Preserve file timestamps
    touch -r "$src" "$tmp"

    # Replace original with optimized file
    mv -f "$tmp" "$src"

    echo
done

echo "All done!"