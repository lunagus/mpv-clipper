# mpv Clipper - Installation & Usage Guide

## Overview

`mpv-clipper` is a Lua script for [mpv](https://mpv.io/) that lets you quickly create clips from videos directly in the player.  
It is **lossless by default** (using `copy` mode), but also supports quality presets (`high`, `medium`, `fast`, `tiny`) and a `custom` mode for advanced control.  
You can **cycle between presets** with a single key (`q`).

---

## Installation

### 1. Locate Your mpv Config Directory

**Windows**
```
%APPDATA%/mpv/
```

**macOS / Linux**
```
~/.config/mpv/
```

### 2. Install the Script

1. Create a `scripts/` folder inside your mpv config directory if it doesn't exist.
2. Save `mpv-clipper.lua` into the `scripts/` folder.
3. *(Optional)* Create a `mpv-clipper.conf` file in the main mpv config directory to override settings.

**Final structure:**
```
~/.config/mpv/
├── scripts/
│   └── mpv-clipper.lua
└── mpv-clipper.conf  (optional)
```

### 3. Ensure FFmpeg Is Available

Make sure FFmpeg is installed and available in your system `PATH`.

Test with:
```bash
ffmpeg -version
```

---

## Usage

### Basic Workflow

1. Load a video in `mpv`
2. Seek to the desired **start** time
3. Press `c` to mark the start
4. Seek to the desired **end** time
5. Press `v` to mark the end
6. Press `b` to create the clip

### Switching Quality Modes

- Press `q` to cycle through:  
  `copy` → `high` → `medium` → `fast` → `tiny` → `custom` → back to `copy`

`copy` mode = **lossless passthrough** (no re-encoding).  
Other presets re-encode with different CRF, preset speed, and audio bitrates.  
`custom` mode uses only what you define in `mpv-clipper.conf`.

---

## Key Bindings

| Key Combination | Description                                |
|-----------------|--------------------------------------------|
| `c`             | Set start point                            |
| `v`             | Set end point                              |
| `b`             | Create clip                                |
| `q`             | Cycle quality mode                         |

---

## Configuration

Create or edit `mpv-clipper.conf` in your mpv config folder.

### Example Config (lossless default, with optional scaling)

```ini
# Output directory for clips (leave empty for same folder as source)
output_dir="/home/user/clips"

# Default codecs ("copy" = lossless passthrough)
video_codec="copy"
audio_codec="copy"

# Container format (auto=same as input)
container="auto"

# Audio bitrate (used if audio is re-encoded)
audio_bitrate="192k"

# Optional CRF & preset (only used if re-encoding video)
crf=""
preset=""

# Optional scaling (e.g., "1280:-1")
scale=""

# Clip filename suffix
clip_suffix="-clip"

# OSD duration in ms
osd_duration=1500

# Show debug logs in console
show_logs=false

# Default quality mode
# Options: copy, high, medium, fast, tiny, custom
quality="copy"
```

### Preset Reference

| Mode    | Video Codec | CRF  | Preset     | Audio Codec | Audio Bitrate |
|---------|------------|------|------------|-------------|---------------|
| copy    | copy       | —    | —          | copy        | —             |
| high    | libx264    | 18   | slower     | aac         | 192k          |
| medium  | libx264    | 20   | medium     | aac         | 128k          |
| fast    | libx264    | 23   | fast       | aac         | 96k           |
| tiny    | libx264    | 28   | ultrafast  | aac         | 64k           |
| custom  | user-set   | —    | —          | user-set    | —             |

---

## Clipping Examples

### Example 1: Lossless Clip (default)
```
1. mpv video.mp4
2. Press `c` at 00:05:10
3. Press `v` at 00:06:30
4. Press `b` → Outputs lossless clip in same format as source
```

### Example 2: Quick Re-encode
```
1. Press `q` until "medium" appears in OSD
2. Set start/end with `c` and `v`
3. Press `b` → Outputs re-encoded clip (CRF 20, medium preset, 128k audio)
```

---

## Troubleshooting

### Script Not Running?
- Ensure `mpv-clipper.lua` is in `scripts/`
- Verify mpv is reading from correct config directory
- Press `~` to open console and check for `[mpv-clipper]` messages

### Clip Fails to Create?
- FFmpeg not found? Install and add to `PATH`
- Output directory not writable? Adjust `output_dir`
- Network streams may not be supported

### Keybindings Don't Work?
- Check for conflicts in other scripts
- Edit bindings directly in Lua file if needed
- Test with `mpv --input-test`
