hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hypr-wallpaper-rotate.service")
end)
