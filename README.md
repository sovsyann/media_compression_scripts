# Media (Photo and Video) Compression Scripts for your home archive

Lightweight shell scripts to **save a lot of disk space** by compressing videos and pictures **recursively** while preserving metadata (EXIF, GPS, timestamps).  

Modern mobile devices, cameras, and smartphones often produce **very large files by default** (e.g. 4K/60fps video, high-resolution JPEGs) and/or use non-optimal compression. Defult compression of many devices provide best quality, but treat your storage like it is endless. This is even more a problem when it comes to archiving. 

These scripts help reclaim disk space with **minimal or no visible quality loss**, making storage and backups more efficient. Imagine cutting your 1TB media archive at least a half while not sacrifizing quality and preserving important meta data - read on...

---

## Scripts Included

- **`pcompress.sh`** → compresses JPEG images  
- **`vcompress.sh`** → compresses video files  
- **`vpcompress.sh`** → combination of the above - compresses images and videos in one pass  

---

## 💡 Why?

- Photos and videos take up **huge amounts of space** out of the box.  
- Modern codecs (HEVC / H.265, JPEG recompression) can reduce size significantly without noticeable quality loss.  
- Ideal for laptops, NAS, cloud sync, or mobile devices where storage is limited.  

---

## Real-Life Results

On average test samples:

- **JPEG images**  
  - Original: 4–10 MB each  
  - After compression: 1–3 MB each  
  - **≈ 40–70% savings** with no visible quality loss  

- **Videos** (recorded on iPhone / Samsung or other Android devices, 1080p–4K)  
  - Original: 500 MB (5 min)  
  - After software CRF compression: 150–250 MB  
  - After hardware encoding: 180–220 MB  
  - **≈ 30–70% savings** depending on content and mode  

---

## Requirements

Install these tools before running the scripts:

- [ffmpeg](https://ffmpeg.org/)  
- [exiftool](https://exiftool.org/)  
- [jpeg-recompress](https://github.com/danielgtaylor/jpeg-archive) (for images)  

On macOS (Homebrew):

```bash
brew install ffmpeg exiftool jpeg-archive
```

On Linux (Debian/Ubuntu):

```bash
sudo apt install ffmpeg exiftool jpeg-archive
```

---

## 🚀 Usage

Run any of the scripts from the folder where your media files are stored.  
They work **recursively**, so all subfolders are processed as well.

### Compress Pictures Only
```bash
./pcompress.sh
```

### Compress Videos Only
```bash
./vcompress.sh
```

### Compress Both Pictures & Videos
```bash
./vpcompress.sh
```

---

## Video Options

For **`vcompress.sh`** and **`vpcompress.sh`** you can choose encoding modes:

- **Default (no option)** → software mode, **CRF-based** (quality-based, best balance)  
- **`--bitrate`** → software mode, fixed bitrate (~5 Mbps)  
- **`--hw`** → hardware mode (VideoToolbox on Mac), fixed bitrate (~6 Mbps)  

Examples:
```bash
./vcompress.sh           # software CRF mode (default)
./vcompress.sh --bitrate # software bitrate mode
./vcompress.sh --hw      # hardware accelerated mode
```

---

## Option Notes

- **Software (CRF)**  
  - Best quality & efficiency  
  - Slower (6–8× slower than hardware and usually slower than 1x)  
  - Recommended for archival
  - Feel free to tune that parameter in the script body

- **Software (bitrate)**  
  - Predictable file size (~5 Mbps target)  
  - Slightly faster than CRF  
  - May waste space on simple scenes or under-quality on complex ones
  - Feel free to tune that parameter in the script body

- **Mac Hardware Accelerated (`--hw`)**  
  - Much faster (normally faster than real-time)  
  - Larger files than CRF, slightly lower quality per bitrate  
  - Great for large batches when speed matters

---

## Tunable Parameters

Inside the scripts, you can adjust:

- **CRF (Constant Rate Factor)**  
  - Script Default: `32` (smaller size, slightly lower quality)
  - Lower value = better quality, larger files  
  - Recommended range: **26–32** 

- **Bitrate**  
  - Default: `5000k` (≈5 Mbps)  
  - Increase for higher quality (e.g. `8000k`)  
  - Decrease for smaller size (e.g. `3000k`)  

> ⚠️ Tip: Try CRF mode first; adjust if you want finer control. CRF mode gives best quality while saving file size. Whant/need to speed up the encoding ~5 times - use hardware acceleration with --hw option: quality will drop a little and expext ~20% more in file size.

---

## macOS vs Linux

- Developed & tested on **macOS** (with Homebrew packages).  
- Works on **Linux** as well, with small differences:  
  - `stat` command differs → script handles both GNU (Linux) and BSD (macOS).  
  - Hardware mode (`--hw`) requires **macOS VideoToolbox**. On Linux, use NVIDIA/VAAPI alternatives (modify ffmpeg options manually).  

---

## Other Notes

- **Metadata is preserved** (EXIF, GPS, timestamps).  
- **Files are only replaced if the new version is smaller**.  
- Both images and videos are processed **recursively** from the current folder down.  
- Safe to run multiple times — files already optimized will usually be skipped.  

---

## Example Workflow

```bash
# Optimize vacation folder (images + videos)
cd ~/Pictures/Vacation2025
./vpcompress.sh

# Fast video-only compression with hardware acceleration (Mac)
./vcompress.sh --hw
```
