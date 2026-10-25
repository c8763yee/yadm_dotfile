-- yadm-owned HyDE user overrides.
-- HyDE loads this file last. Keep the loader block so Hyprland can also use
-- ~/.config/hypr/hyprland.lua as the entry point when started directly.
if not hyde then
  local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
  local entry = share .. "/hypr/hyde.lua"
  local handle = io.open(entry, "r")
  if not handle then
    error("HyDE is not installed at " .. entry)
  end
  handle:close()
  dofile(entry)
end

local MOD = hyde.config.modifiers.main
local HOME = assert(os.getenv("HOME"), "HOME is not set")

-- Preserve machine-local Lua settings that HyDE created before yadm took
-- ownership of hyprland.lua (for example, an auto-detected keyboard layout).
local state = os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")
local preserved = state .. "/yadm/hypr/hyprland.lua.pre-yadm"
local preserved_file = io.open(preserved, "r")
if preserved_file then
  preserved_file:close()
  dofile(preserved)
end
-- Migrated from userprefs.conf.
hl.config({
  input = {
    touchpad = {
      natural_scroll = false,
    },
  },
})

-- Migrated from custom/keybind.conf.
hl.unbind("F10")
hl.unbind("F11")
hl.unbind("F12")
hl.unbind(MOD .. " + SHIFT + F")

hl.bind(
  MOD .. " + SHIFT + F",
  hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
  { description = "[Window Management] maximize window" }
)

hl.bind(
  MOD .. " + F",
  hl.dsp.exec_cmd(hyde.sh.window.pin()),
  { description = "[Window Management] toggle pin on focused window" }
)

hl.bind(
  "ALT + SPACE",
  hl.dsp.exec_cmd("pkill -x rofi || hyde-shell rofilaunch d"),
  { description = "[Launcher|Rofi menus] application finder" }
)

hl.bind(
  MOD .. " + D",
  hl.dsp.exec_cmd(HOME .. "/.config/hypr/custom/scripts/toggle-show-desktop.sh"),
  { description = "[Window Management] toggle show desktop" }
)

-- Load custom user modules
-- 自動載入 custom/ 底下的所有 .lua 模組（等同於 source = custom/*.conf 的效果）
local function source_custom_modules()
  local ok, lfs = pcall(require, "lfs")
  if not ok then return end

  local custom_dir = HOME .. "/.config/hypr/custom"
  if lfs.attributes(custom_dir, "mode") ~= "directory" then return end

  for file in lfs.dir(custom_dir) do
    -- 匹配 .lua 結尾，並排除 keep.lua 等特殊保留檔
    if file:match("%.lua$") and file ~= "keep.lua" then
      local mod_name = "custom." .. file:gsub("%.lua$", "")
      package.loaded[mod_name] = nil -- 確保 reload 時會重新讀取
      check_require(mod_name)
    end
  end
end

source_custom_modules()
