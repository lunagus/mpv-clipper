-- mpv-clipper.lua
-- Video trimming script for mpv
-- Usage:
--   c: Set start time
--   v: Set end time
--   b: Make clip from start to end time
--   q: Cycle quality presets
--   i: Show clip info/status

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"
-- Defaults
local config = {
    output_dir      = "",
    video_codec     = "copy",     -- default lossless
    audio_codec     = "copy",     -- default lossless
    sub_codec       = "copy",     -- default lossless
    container       = "auto",
    audio_bitrate   = "",
    clip_suffix     = "-clip",
    osd_duration    = 1.5,        -- baseline seconds
    show_logs       = false,
    quality         = "copy",     -- default mode
    crf             = "",
    preset          = "",
    scale           = ""          -- e.g. "1280:-1"
}

-- Quality presets
local quality_presets = {
    copy   = { video_codec="copy", audio_codec="copy", sub_codec="copy" },
    high   = { video_codec="libx264", crf="18", preset="slower", audio_codec="aac", audio_bitrate="192k", sub_codec="copy" },
    medium = { video_codec="libx264", crf="20", preset="medium", audio_codec="aac", audio_bitrate="128k", sub_codec="copy" },
    fast   = { video_codec="libx264", crf="23", preset="fast", audio_codec="aac", audio_bitrate="96k", sub_codec="copy" },
    tiny   = { video_codec="libx264", crf="28", preset="ultrafast", audio_codec="aac", audio_bitrate="64k", sub_codec="copy" },
    custom = {} -- will be filled by config overrides
}

-- Load config file
local function load_config()
    local conf_path = mp.find_config_file("scripts/mpv-clipper.conf") or mp.find_config_file("mpv-clipper.conf")
    if not conf_path then return end
    for line in io.lines(conf_path) do
        local key, val = line:match('^%s*([^#][^=]-)%s*=%s*(.-)%s*$')
        if key and val then
            -- Remove quotes if they exist
            val = val:match('^"(.*)"$') or val
            if tonumber(val) then val = tonumber(val)
            elseif val == "true" then val = true
            elseif val == "false" then val = false end
            config[key] = val
        end
    end
end
load_config()

-- Merge preset with config overrides
local function get_active_preset()
    local preset = quality_presets[config.quality] or {}
    local merged = {}
    for k,v in pairs(preset) do merged[k] = v end
    for k,v in pairs(config) do if merged[k] == nil or config.quality == "custom" then merged[k] = v end end

    -- Auto-lossless if both codecs = copy
    if merged.video_codec == "copy" and merged.audio_codec == "copy" then
        merged.crf, merged.preset, merged.audio_bitrate = "", "", ""
    end
    return merged
end

-- Get currently active tracks (video, audio, sub) in mpv
local function get_active_tracks()
    local track_list = mp.get_property_native("track-list")
    local active_tracks = {}
    local external_inputs = {}
    if not track_list then return active_tracks, external_inputs end
    
    for _, track in ipairs(track_list) do
        if track.selected then
            if track.external and track['external-filename'] then
                table.insert(external_inputs, track['external-filename'])
            elseif not track.external and track['ff-index'] ~= nil then
                table.insert(active_tracks, track['ff-index'])
            end
        end
    end
    return active_tracks, external_inputs
end

-- Convert seconds to MM-SS format
local function format_timestamp(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d-%02d", mins, secs)
end

-- Clip function
local clip_start, clip_end
local function make_clip()
    if not clip_start or not clip_end then
        mp.osd_message("Set start and end points first", config.osd_duration)
        return
    end
    local file = mp.get_property("path")
    if not file then return end
    local start_time = math.min(clip_start, clip_end)
    local end_time   = math.max(clip_start, clip_end)
    local duration   = end_time - start_time
    local dir, name = utils.split_path(file)
    local out_dir = (config.output_dir ~= "" and config.output_dir) or dir
    local ext = (config.container == "auto") and file:match("^.+(%..+)$") or ("."..config.container)
    
    -- Format timestamps for filename
    local start_formatted = format_timestamp(start_time)
    local end_formatted = format_timestamp(end_time)
    
    -- Create filename: originalname_MM-SS_MM-SS-clip.ext
    local base_name = name:gsub("%..+$", "")
    local out_path = utils.join_path(out_dir, base_name .. "_" .. start_formatted .. "_" .. end_formatted .. config.clip_suffix .. ext)

    local p = get_active_preset()
    local active_tracks, external_inputs = get_active_tracks()
    local args = { "ffmpeg", "-y" }

    -- Main input
    table.insert(args, "-ss"); table.insert(args, tostring(start_time))
    table.insert(args, "-i"); table.insert(args, file)

    -- External inputs
    for _, ext_file in ipairs(external_inputs) do
        table.insert(args, "-ss"); table.insert(args, tostring(start_time))
        table.insert(args, "-i"); table.insert(args, ext_file)
    end
    
    table.insert(args, "-t"); table.insert(args, tostring(duration))

    -- Map only currently active tracks
    for _, ff_idx in ipairs(active_tracks) do
        table.insert(args, "-map")
        table.insert(args, "0:" .. tostring(ff_idx))
    end
    
    -- Map external inputs
    for i, _ in ipairs(external_inputs) do
        table.insert(args, "-map")
        table.insert(args, tostring(i) .. ":0")
    end

    if p.video_codec == "copy" then
        table.insert(args, "-c:v"); table.insert(args, "copy")
    else
        table.insert(args, "-c:v"); table.insert(args, p.video_codec)
        if p.crf ~= "" then table.insert(args, "-crf"); table.insert(args, p.crf) end
        if p.preset ~= "" then table.insert(args, "-preset"); table.insert(args, p.preset) end
    end

    if p.audio_codec == "copy" then
        table.insert(args, "-c:a"); table.insert(args, "copy")
    else
        table.insert(args, "-c:a"); table.insert(args, p.audio_codec)
        if p.audio_bitrate and p.audio_bitrate ~= "" then
            table.insert(args, "-b:a"); table.insert(args, p.audio_bitrate)
        end
    end

    if p.sub_codec == "copy" then
        table.insert(args, "-c:s"); table.insert(args, "copy")
    elseif p.sub_codec and p.sub_codec ~= "" then
        table.insert(args, "-c:s"); table.insert(args, p.sub_codec)
    end

    if p.scale and p.scale ~= "" then
        table.insert(args, "-vf"); table.insert(args, "scale="..p.scale)
    end

    table.insert(args, out_path)

    if config.show_logs then msg.info("Running:", table.concat(args, " ")) end
    mp.command_native_async({ name = "subprocess", args = args, capture_stdout = true, capture_stderr = true }, function() end)
    mp.osd_message("Clip saved: " .. out_path, config.osd_duration * 1.5)
end

-- Format timestamp for OSD display
local function format_osd_timestamp(seconds)
    if not seconds then return "Not set" end
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, mins, secs)
    end
    return string.format("%02d:%02d", mins, secs)
end

-- Get friendly string of active tracks for OSD
local function get_active_track_info()
    local track_list = mp.get_property_native("track-list")
    if not track_list then return "A: ? | S: ?" end
    
    local audio, sub = "None", "None"
    
    for _, track in ipairs(track_list) do
        if track.selected then
            local info = tostring(track.id)
            if track.lang then info = info .. " (" .. track.lang .. ")"
            elseif track.title then info = info .. " (" .. track.title .. ")" end
            if track.external then info = info .. " [Ext]" end
            
            if track.type == "audio" then audio = info
            elseif track.type == "sub" then sub = info end
        end
    end
    return string.format("A: %s | S: %s", audio, sub)
end

-- Key bindings
mp.add_key_binding("c", "set-start", function() clip_start = mp.get_property_number("time-pos"); mp.osd_message("Clip start: "..format_osd_timestamp(clip_start)) end)
mp.add_key_binding("v", "set-end",   function() clip_end = mp.get_property_number("time-pos");   mp.osd_message("Clip end: "..format_osd_timestamp(clip_end)) end)
mp.add_key_binding("b", "make-clip", make_clip)
mp.add_key_binding("ctrl+i", "show-info", function() 
    local msg_str = string.format("Clip: %s to %s\nQuality: %s\nTracks: %s", 
        format_osd_timestamp(clip_start), format_osd_timestamp(clip_end), config.quality, get_active_track_info())
    mp.osd_message(msg_str, config.osd_duration * 2.5) 
end)

-- Cycle quality presets
local preset_order = { "copy", "high", "medium", "fast", "tiny", "custom" }
mp.add_key_binding("q", "cycle-quality", function()
    local idx
    for i,v in ipairs(preset_order) do if v == config.quality then idx = i break end end
    config.quality = preset_order[(idx % #preset_order) + 1]
    mp.osd_message("Quality: " .. config.quality, config.osd_duration)
end)