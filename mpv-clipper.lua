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
    container       = "auto",
    audio_bitrate   = "",
    clip_suffix     = "-clip",
    osd_duration    = 1500,
    show_logs       = false,
    quality         = "copy",     -- default mode
    crf             = "",
    preset          = "",
    scale           = ""          -- e.g. "1280:-1"
}

-- Quality presets
local quality_presets = {
    copy   = { video_codec="copy", audio_codec="copy" },
    high   = { video_codec="libx264", crf="18", preset="slower", audio_codec="aac", audio_bitrate="192k" },
    medium = { video_codec="libx264", crf="20", preset="medium", audio_codec="aac", audio_bitrate="128k" },
    fast   = { video_codec="libx264", crf="23", preset="fast", audio_codec="aac", audio_bitrate="96k" },
    tiny   = { video_codec="libx264", crf="28", preset="ultrafast", audio_codec="aac", audio_bitrate="64k" },
    custom = {} -- will be filled by config overrides
}

-- Load config file
local function load_config()
    local conf_path = mp.find_config_file("scripts/mpv-clipper.conf") or mp.find_config_file("mpv-clipper.conf")
    if not conf_path then return end
    for line in io.lines(conf_path) do
        local key, val = line:match('^%s*([^#][^=]*)%s*=%s*"(.-)"%s*$')
        if key and val ~= "" then
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
    local out_path = utils.join_path(out_dir, name:gsub("%..+$", "") .. config.clip_suffix .. ext)

    local p = get_active_preset()
    local args = { "ffmpeg", "-y", "-ss", tostring(start_time), "-i", file, "-t", tostring(duration) }

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

    if p.scale and p.scale ~= "" then
        table.insert(args, "-vf"); table.insert(args, "scale="..p.scale)
    end

    table.insert(args, out_path)

    if config.show_logs then msg.info("Running:", table.concat(args, " ")) end
    mp.command_native_async({ name = "subprocess", args = args, capture_stdout = true, capture_stderr = true }, function() end)
    mp.osd_message("Clip saved: " .. out_path, config.osd_duration)
end

-- Key bindings
mp.add_key_binding("c", "set-start", function() clip_start = mp.get_property_number("time-pos"); mp.osd_message("Clip start: "..clip_start) end)
mp.add_key_binding("v", "set-end",   function() clip_end = mp.get_property_number("time-pos");   mp.osd_message("Clip end: "..clip_end) end)
mp.add_key_binding("b", "make-clip", make_clip)

-- Cycle quality presets
local preset_order = { "copy", "high", "medium", "fast", "tiny", "custom" }
mp.add_key_binding("q", "cycle-quality", function()
    local idx
    for i,v in ipairs(preset_order) do if v == config.quality then idx = i break end end
    config.quality = preset_order[(idx % #preset_order) + 1]
    mp.osd_message("Quality: " .. config.quality, config.osd_duration)
end)
