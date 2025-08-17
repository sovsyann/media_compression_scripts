#!/bin/bash
# media-compress.sh — compress videos and images recursively (macOS-friendly)
#
# Requirements:
#   ffmpeg, exiftool, jpeg-recompress
#
# Video options:
#   --hw       use Mac hardware encoding (VideoToolbox HEVC, ~6 Mbps target)
#   --bitrate  use software bitrate-based encoding (~5 Mbps target)
#   (default)  software CRF-based encoding (CRF=32, better quality/size tradeoff)
#
# Images:
#   Processes JPG/JPEG files with jpeg-recompress (high quality, preserves EXIF/GPS)

set -e

USE_HW=0
USE_BITRATE=0

# Parse options (apply only to video part)
for arg in "$@"; do
    case "$arg" in
        --hw) USE_HW=1 ;;
        --bitrate) USE_BITRATE=1 ;;
    esac
done

########################################
# VIDEO COMPRESSION
########################################
echo "🔹 Video compression mode:"
if (( USE_HW )); then
    echo "   ⚡ Hardware-accelerated encoding (VideoToolbox, ~6 Mbps target)"
elif (( USE_BITRATE )); then
    echo "   🎯 Software encoding (libx265, ~5 Mbps target, bitrate mode)"
else
    echo "   🐢 Software encoding (libx265, CRF=32 quality mode, default CRF=28)"
fi
echo

# Collect all video files recursively
videos=()
while IFS= read -r file; do
    videos+=("$file")
done < <(find . -type f \( -iname "*.mp4" -o -iname "*.mov" \))

vcount=${#videos[@]}
if (( vcount > 0 )); then
    echo "Found $vcount video(s) to check."
    vidx=1

    for src in "${videos[@]}"; do
        [[ -f "$src" ]] || continue
        echo
        echo "[Video $vidx/$vcount] Processing: $src"

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
            touch -r "$src" "$tmp"
            mv -f "$tmp" "$src"
            echo "✅ Video reduced from $((orig_size/1024/1024)) MB to $((new_size/1024/1024)) MB (${saved}% smaller)."
        else
            rm -f "$tmp"
            echo "⚠️ Video skipped: new file not smaller."
        fi

        ((vidx++))
    done
else
    echo "No videos found."
fi

########################################
# IMAGE COMPRESSION
########################################
echo
echo "🔹 Image compression mode:"
images=$(find . -type f \( -iname '*.jpg' -o -iname '*.jpeg' \))
icount=$(echo "$images" | wc -l | tr -d ' ')

if [[ "$icount" -eq 0 ]]; then
    echo "No JPG/JPEG files found."
else
    echo "Found $icount image(s) to check."
    echo

    iidx=1
    echo "$images" | while IFS= read -r src; do
        [[ -f "$src" ]] || continue
        echo "[Image $iidx/$icount] Processing: $src"

        tmp="${src}.opt.jpg"

        output=$(jpeg-recompress --strip --quality high "$src" "$tmp" 2>&1)

        if echo "$output" | grep -q "File already processed"; then
            echo "    Already optimized, skipping."
            rm -f "$tmp" 2>/dev/null
            echo
            ((iidx++))
            continue
        fi

        echo "$output"

        if [[ ! -f "$tmp" ]]; then
            echo "    No optimized file produced, skipping."
            echo
            ((iidx++))
            continue
        fi

        exiftool -TagsFromFile "$src" -All:All -overwrite_original "$tmp" > /dev/null
        touch -r "$src" "$tmp"
        mv -f "$tmp" "$src"

        echo "✅ Image optimized."
        echo
        ((iidx++))
    done
fi

echo
echo "🎉 All done!"

