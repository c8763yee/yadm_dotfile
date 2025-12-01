sudo pacman -S --noconfirm --needed \
	lua51 rustup cargo rust-analyzer tree-sitter{,-cli} hyprland swaylock \
	waybar nwg-{look,displays,dock-hyprland} gnome-keyring fd fastfetch wofi \
	kitty waybar otf-font-awesome network-manager-applet brightnessctl \
	hyprshot power-profiles-daemon wofi hyprpaper swayidle dunst cliphist \
	pipewire pipewire-pulse wireplumber pavucontrol xorg xorg-xwayland \
	xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-kde-agent \
	qt5-wayland qt6-wayland qt5ct qt6ct nwg-look udiskie \
	greetd greetd-tuigreet fcitx5-im fcitx5-chewing fcitx5-qt fcitx5-gtk fcitx5-chinese-addons

rustup install stable
yay -S --noconfirm --needed awww-git pw-volume wlogout
