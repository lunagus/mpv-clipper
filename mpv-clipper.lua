-- mpv-clipper.lua
-- Video trimming script for mpv
-- Usage:
--   c: Set start time (first press) or end time and create clip (second press)
--   C (Shift+c): Reset/cancel current clip selection
--   ctrl+shift+c: Create clip with current selection
--   i: Show clip info/status

local mp = require 'mp'
local utils = require 'mp.utils'

local config = {
    output_dir = "",
    video_codec = "libx264",
    audio_codec = "aac",
    crf = "20",
    preset = "medium",
    container = "mp4",
    audio_bitrate = "128k",
    clip_suffix = "-clip",
    osd_duration = 1500,
    show_logs = true
}

local function load_config()
    local path = mp.find_config_file("mpv-clipper.conf")
    if not path then return end

    local file = io.open(path, "r")
    if not file then return end

    for line in file:lines() do
        local key, val = line:match('^%s*([%w_]+)%s*=%s*"?([^"]+)"?%s*$')
        if key and val and config[key] ~= nil then
            if val == "true" then val = true
            elseif val == "false" then val = false
            elseif tonumber(val) then val = tonumber(val)
            end
            config[key] = val
        end
    end
    file:close()
end

load_config()

local clip_start, clip_end = nil, nil
local current_file = mp.get_property("path")
local is_processing = false

local function log(msg)
    if config.show_logs then
        print("[mpv-clipper] " .. msg)
    end
end

local function format_time(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%06.3f", h, m, s)
end

local function osd(msg, dur)
    mp.osd_message(msg, dur or config.osd_duration)
end

local function get_output_path(start_time, end_time)
    local dir, name = utils.split_path(current_file)
    if config.output_dir ~= "" then
        dir = config.output_dir
        os.execute('mkdir -p "' .. dir .. '"')
    end
    name = name:gsub("%..-$", "")
    local st = format_time(start_time):gsub("[:.]", "-")
    local et = format_time(end_time):gsub("[:.]", "-")
    local filename = string.format("%s%s-%s-%s.%s", name, config.clip_suffix, st, et, config.container)
    return utils.join_path(dir, filename)
end

local function ffmpeg_cmd(output_path, start_time, end_time)
    return {
        "ffmpeg", "-y", "-ss", tostring(start_time), "-i", current_file,
        "-t", tostring(end_time - start_time),
        "-c:v", config.video_codec, "-crf", config.crf, "-preset", config.preset,
        "-c:a", config.audio_codec, "-b:a", config.audio_bitrate,
        output_path
    }
end

local function create_clip()
    if not clip_start or not clip_end or clip_end <= clip_start then
        osd("Invalid clip range")
        return
    end

    if is_processing then
        osd("Clip already processing")
        return
    end

    if current_file:match("^https?://") then
        osd("Cannot clip streamed videos")
        return
    end

    local output = get_output_path(clip_start, clip_end)
    is_processing = true
    log("Creating clip: " .. output)

    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        args = ffmpeg_cmd(output, clip_start, clip_end)
    }, function(success, result)
        is_processing = false
        if success and result.status == 0 then
            osd("Clipped", 2000)
            log("Clip saved: " .. output)
        else
            osd("Clip failed", 3000)
            log("FFmpeg error")
        end
    end)

    clip_start, clip_end = nil, nil
end

local function toggle_clip_time()
    local pos = mp.get_property_number("time-pos")
    if not clip_start then
        clip_start = pos
        osd("Clip Start at " .. format_time(pos), 2000)
        log("Start set: " .. format_time(pos))
    else
        clip_end = pos
        osd("Clip End at " .. format_time(pos), 2000)
        log("End set: " .. format_time(pos))
        create_clip()
    end
end

local function reset_clip()
    clip_start, clip_end = nil, nil
    osd("Selection reset", 2000)
    log("Clip selection reset")
end

local function show_status()
    local pos = mp.get_property_number("time-pos")
    local status = {
        "Clipper Status:",
        "File: " .. (current_file or "None"),
        "Current: " .. (pos and format_time(pos) or "N/A"),
        "Start: " .. (clip_start and format_time(clip_start) or "Not set"),
        "End: " .. (clip_end and format_time(clip_end) or "Not set"),
        is_processing and "Status: Processing" or "Status: Ready",
    }
    osd(table.concat(status, "\n"), 6000)
end

-- Keybindings
mp.add_key_binding("c", "clipper-toggle", toggle_clip_time)
mp.add_key_binding("C", "clipper-reset", reset_clip)
mp.add_key_binding("ctrl+shift+c", "clipper-create", create_clip)
mp.add_key_binding("i", "clipper-info", show_status)

-- On file load
mp.register_event("file-loaded", function()
    current_file = mp.get_property("path")
end)