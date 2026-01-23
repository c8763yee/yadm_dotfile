#!/bin/bash
# Arch-specific packages (different names or Arch-only)

# Packages with different names in Arch + kernel build (Arch-specific names)
sudo pacman -S --noconfirm --needed \
	fd \
	git-delta \
	yarn \
	base-devel \
	ncurses \
	openssl \
	libelf \
	pahole

# Hyprland desktop environment (Arch-only)
sudo pacman -S --noconfirm --needed \
	lua51 rustup cargo rust-analyzer tree-sitter{,-cli} hyprland \
	waybar nwg-{look,displays,dock-hyprland} gnome-keyring wofi \
	kitty otf-font-awesome network-manager-applet brightnessctl \
	hyprshot power-profiles-daemon hyprpaper swayidle dunst cliphist \
	pipewire pipewire-pulse wireplumber pavucontrol xorg xorg-xwayland \
	xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-kde-agent \
	qt5-wayland qt6-wayland qt5ct qt6ct udiskie \
	greetd greetd-tuigreet \
	fcitx5-im fcitx5-chewing fcitx5-qt fcitx5-gtk fcitx5-chinese-addons

rustup install stable
yay -S --noconfirm --needed pw-volume wlogout swaylock-effects
