#!/bin/bash
set -e

echo "[TMJOs] Applying TMJOs dark theme..."

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
THEME_DIR="$SCRIPT_DIR/theme"

# Default skeleton for new users
SKEL="/etc/skel"
mkdir -p "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$SKEL/.config/xfce4/terminal"
mkdir -p "$SKEL/.config/gtk-3.0"
mkdir -p "$SKEL/.local/share/xfce4/terminal/colorschemes"

# GTK dark theme
cp "$THEME_DIR/gtk-3.0/settings.ini" "$SKEL/.config/gtk-3.0/settings.ini"

# XFCE desktop settings (wallpaper, icons)
cp "$THEME_DIR/xfce4-desktop.xml" "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"

# XFCE panel
cp "$THEME_DIR/xfce4-panel.xml" "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"

# Terminal color scheme
cp "$THEME_DIR/tmjos-terminal.theme" "$SKEL/.local/share/xfce4/terminal/colorschemes/tmjos.theme"
cp "$THEME_DIR/terminalrc" "$SKEL/.config/xfce4/terminal/terminalrc"

# Wallpaper
mkdir -p /usr/share/backgrounds/tmjos
cp "$SCRIPT_DIR/../assets/wallpapers/tmjos_wallpaper_4k.png" /usr/share/backgrounds/tmjos/

# LightDM greeter config
cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'EOF'
[greeter]
background=/usr/share/backgrounds/tmjos/tmjos_wallpaper_4k.png
theme-name=Adwaita-dark
icon-theme-name=Papirus-Dark
font-name=JetBrains Mono 11
indicators=~host;~spacer;~session;~language;~a11y;~clock;~power
EOF

echo "[TMJOs] Theme applied."
