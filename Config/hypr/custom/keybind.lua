hl.unbind("F10")
hl.unbind("F11")
hl.unbind("F12")
hl.unbind("SUPER + SHIFT + F")

hl.bind(
	"SUPER + SHIFT + F",
	hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
	{ description = "[Window Management] maximize window" }
)

hl.bind(
	"SUPER + F",
	hl.dsp.exec_cmd("hyde-shell window.pin"),
	{ description = "[Window Management] toggle pin on focused window" }
)

-- hl.bind(
-- 	"CTRL + ALT + T",
-- 	hl.dsp.exec_cmd("kitty"),
-- 	{ description = "terminal emulator"}
-- )


hl.bind(
	"ALT + SPACE",
	hl.dsp.exec_cmd("pkill -x rofi || hyde-shell rofilaunch d"),
	{ description = "[Launcher|Rofi menus] application finder" }
)

-- hl.bind(
-- 	"CTRL + SHIFT + A",
-- 	hl.dsp.exec_cmd("busctl --user call org.waywallen.waywallen.Daemon /org/waywallen/waywallen/Daemon org.waywallen.waywallen.Daemon1 Next"),
-- 	{ description = "[Theming and Wallpaper] next waywallen wallpaper" }
-- )
hl.bind(
	"CTRL + SHIFT + A",
	hl.dsp.exec_cmd("$HOME/.config/hypr/custom/scripts/random-wallpaper-per-monitor.sh"),
	{ description = "[Theming and Wallpaper] next wallpaper" }
)

hl.bind(
	"SUPER + D",
	hl.dsp.exec_cmd("$HOME/.config/hypr/custom/scripts/toggle-show-desktop.sh"),
	{ description = "[Window Management] toggle show desktop" }
)

-- hl.bind(
-- 	"SUPER",
-- 	hl.dsp.exec_cmd("pkill -x rofi || hyde-shell rofilaunch d"),
-- 	{ description = "[Launcher|Rofi menus] start menu" }
-- )
