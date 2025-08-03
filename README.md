# mpv Clipper - Installation & Usage Guide

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
3. *(Optional)* Create a `clipper.conf` file in the main mpv config directory to override settings.

**Final structure:**
```
~/.config/mpv/
├── scripts/
│   └── mpv-clipper.lua
└── clipper.conf  (optional)
```

### 3. Ensure FFmpeg Is Available

Make sure FFmpeg is installed and available in your system `PATH`.

Test with:
```bash
ffmpeg -version
```

## Usage

### Basic Workflow

1. Load a video in `mpv`
2. Seek to the desired **start** time
3. Press `c` to mark the start
4. Seek to the desired **end** time
5. Press `c` again to mark the end and create the clip

### Status & Debugging

- Press `i` to display current clip status
- Open the console (`~`) to view logs (if `show_logs = true`)
- Press `Ctrl+Shift+C` to force a clip (if start/end were manually set)
- Press `C` to reset the current selection

## Key Bindings

| Key Combination | Description                                |
|-----------------|--------------------------------------------|
| `c`             | Toggle: set start → set end → create clip  |
| `C`             | Cancel/reset current selection             |
| `i`             | Show current clip status                   |
| `Ctrl+Shift+C`  | Force clip creation (manual range)         |

## Configuration

### Default Settings

These are defined in the Lua script or can be overridden in `clipper.conf`.

```ini
video_codec="libx264"
audio_codec="aac"
crf="20"
preset="medium"
container="mp4"
audio_bitrate="128k"
output_dir=""
osd_duration="1500"
show_logs=true
```

### Example: Custom Configuration

Create a file at `~/.config/mpv/clipper.conf` with content like:

```ini
video_codec="libx265"
crf="23"
output_dir="/home/user/clips"
container="mkv"
audio_bitrate="192k"
show_logs=false
```

## Clipping Examples

### Example 1: Quick Clip

```
1. mpv video.mp4
2. Press `c` at 00:05:10
3. Press `c` again at 00:06:30
→ Output: video-clip-00-05-10-00-06-30.mp4
```

### Example 2: Multiple Clips in One Session

```
1. Clip 1 → 0:10 → `c`, 0:25 → `c`
2. Clip 2 → 1:15 → `c`, 1:30 → `c`
3. Clip 3 → 2:00 → `c`, 2:10 → `c`
```

Each clip is saved separately with its own timestamped filename.

## Troubleshooting

### Script Not Running?
- Make sure `mpv-clipper.lua` is in the `scripts/` directory
- Verify mpv is reading from the correct config directory
- Press `~` and look for `[mpv-clipper]` messages

### Clip Fails to Create?
- Ensure you’re not trying to clip a stream (e.g. YouTube URL)
- Confirm FFmpeg is available and works independently
- Check output path is writable

### Keybindings Don't Work?
- Conflicts with other scripts? Try modifying bindings in the script or use a config override.
- Use `mpv --input-test` to verify keys are registering
