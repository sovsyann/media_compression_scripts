#!/bin/bash
# Recursive processing from the current directory
# vcompress.sh — compress videos with ffmpeg (macOS/QuickTime compatible)
# to run this script install ffmpeg and exiftool
# use with no options for software mode compression with CRF (quality based compresstion) set to 32 (a bit lower filesize, default 28)
# use with option --bitrate to fix bitrate to ~5 Mbps
# use with option --hw to use Mac Hardware encoding toolkit with fixed bitrate to about ~5-6 Mbps

set -e

USE_HW=0
USE_BITRATE=0

# Parse options
for arg in "$@"; do
    case "$arg" in
        --hw) USE_HW=1 ;;
        --bitrate) USE_BITRATE=1 ;;
    esac
done

if (( USE_HW )); then
    echo "⚡ Using hardware-accelerated encoding (VideoToolbox, ~6 Mbps target)..."
elif (( USE_BITRATE )); then
    echo "🎯 Using software encoding (libx265, ~5 Mbps target, bitrate mode)..."
else
    echo "🐢 Using software encoding (libx265, CRF-based 32 quality mode, default CRF=28)..."
fi

# Collect all video files recursively (compatible with older Bash)
videos=()
while IFS= read -r file; do
    videos+=("$file")
done < <(find . -type f \( -iname "*.mp4" -o -iname "*.mov" \))

count=${#videos[@]}
if (( count == 0 )); then
    echo "No video files found."
    exit 0
fi

echo "Found $count video(s) to check."
idx=1

for src in "${videos[@]}"; do
    [[ -f "$src" ]] || continue
    echo
    echo "[$idx/$count] Processing: $src"

    tmp="${src%.*}.opt.mp4"
    meta="$src"

    # Get original size
    orig_size=$(stat -c %s "$src" 2>/dev/null || stat -f %z "$src")

    if (( USE_HW )); then
        ffmpeg -hide_banner -y -i "$src" \
            -c:v hevc_videotoolbox -b:v 6000k -maxrate 7000k -bufsize 12000k \
            -tag:v hvc1 -pix_fmt yuv420p \
            -c:a copy -map_metadata 0 -movflags use_metadata_tags "$tmp" \
            -progress - 2>/dev/null | awk '
                /^out_time_ms=/ { 
                    secs=$0; sub("out_time_ms=", "", secs); 
                    prog=int(secs/1000000);
                    printf("\r    Progress: %d sec encoded...", prog);
                    fflush();
                }'
    elif (( USE_BITRATE )); then
        ffmpeg -hide_banner -y -i "$src" \
            -c:v libx265 -preset slow -b:v 5000k -maxrate 6000k -bufsize 10000k \
            -tag:v hvc1 \
            -c:a copy -map_metadata 0 -movflags use_metadata_tags "$tmp" \
            -progress - 2>/dev/null | awk '
                /^out_time_ms=/ { 
                    secs=$0; sub("out_time_ms=", "", secs); 
                    prog=int(secs/1000000);
                    printf("\r    Progress: %d sec encoded...", prog);
                    fflush();
                }'
    else
        ffmpeg -hide_banner -y -i "$src" \
            -c:v libx265 -preset slow -crf 32 \
            -tag:v hvc1 \
            -c:a copy -map_metadata 0 -movflags use_metadata_tags "$tmp" \
            -progress - 2>/dev/null | awk '
                /^out_time_ms=/ { 
                    secs=$0; sub("out_time_ms=", "", secs); 
                    prog=int(secs/1000000);
                    printf("\r    Progress: %d sec encoded...", prog);
                    fflush();
                }'
    fi

    echo

    # Inject metadata from original file using ExifTool
    if command -v exiftool >/dev/null 2>&1; then
        exiftool -overwrite_original -tagsFromFile "$meta" "$tmp" >/dev/null
    else
        echo "⚠️ ExifTool not found — metadata not restored."
    fi

    # Final sizes
    new_size=$(stat -c %s "$tmp" 2>/dev/null || stat -f %z "$tmp")

    if (( new_size < orig_size )); then
        saved=$(( (orig_size - new_size) * 100 / orig_size ))
        # Preserve file timestamps
        touch -r "$src" "$tmp"
        # Replace original with optimized file
        mv -f "$tmp" "$src"
        echo "✅ Success: reduced from $((orig_size/1024/1024)) MB to $((new_size/1024/1024)) MB (${saved}% smaller)."
    else
        rm -f "$tmp"
        echo "⚠️ Skipped: new file not smaller (orig=$((orig_size/1024/1024)) MB, new=$((new_size/1024/1024)) MB)."
    fi

    ((idx++))
done

echo
echo "🎉 All done!"
