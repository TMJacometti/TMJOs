#!/bin/bash
set -e

echo "[TMJOs] Replacing Ubuntu branding with TMJOs..."

LOGO_SRC="/tmp/tmjos-distro/assets/logos/TMJOs_Logo_Circular.png"
WALL_SRC="/tmp/tmjos-distro/assets/wallpapers/tmjos_wallpaper_4k.png"

# Plymouth boot splash — replace Ubuntu logo
if [ -d /usr/share/plymouth/themes/spinner ]; then
    cp "$LOGO_SRC" /usr/share/plymouth/themes/spinner/watermark.png
    # Smaller version for the throbber
    if command -v convert >/dev/null 2>&1; then
        convert "$LOGO_SRC" -resize 128x128 /usr/share/plymouth/themes/spinner/bgrt-fallback.png
    else
        cp "$LOGO_SRC" /usr/share/plymouth/themes/spinner/bgrt-fallback.png
    fi
fi

# Plymouth background color (navy #0a0e2a)
if [ -f /usr/share/plymouth/themes/spinner/spinner.plymouth ]; then
    sed -i 's/BackgroundStartColor=.*/BackgroundStartColor=0x0a0e2a/' \
        /usr/share/plymouth/themes/spinner/spinner.plymouth
    sed -i 's/BackgroundEndColor=.*/BackgroundEndColor=0x050714/' \
        /usr/share/plymouth/themes/spinner/spinner.plymouth
fi

# Ubiquity installer branding (if present)
if [ -d /usr/share/ubiquity/pixmaps ]; then
    cp "$LOGO_SRC" /usr/share/ubiquity/pixmaps/ubuntu_installed.png
    cp "$LOGO_SRC" /usr/share/ubiquity/pixmaps/cd_in_tray.png
fi

# Calamares installer branding (if used instead of ubiquity)
if [ -d /etc/calamares/branding ]; then
    mkdir -p /etc/calamares/branding/tmjos
    cp "$LOGO_SRC" /etc/calamares/branding/tmjos/logo.png
    cp "$WALL_SRC" /etc/calamares/branding/tmjos/welcome.png
    cat > /etc/calamares/branding/tmjos/branding.desc << 'EOF'
componentName: tmjos
welcomeStyleCalamares: true
strings:
    productName: TMJOs
    shortProductName: TMJOs
    version: 26.04
    shortVersion: 26.04
    versionedName: TMJOs 26.04
    shortVersionedName: TMJOs 26.04
    bootloaderEntryName: TMJOs
    productUrl: https://github.com/TMJacometti/TMJOs
    supportUrl: https://github.com/TMJacometti/TMJOs/issues
    releaseNotesUrl: https://github.com/TMJacometti/TMJOs/releases
images:
    productLogo: logo.png
    productIcon: logo.png
    productWelcome: welcome.png
style:
    sidebarBackground: "#050714"
    sidebarText: "#e6e6e6"
    sidebarTextSelect: "#00d4ff"
    sidebarTextHighlight: "#ff2d95"
EOF
fi

# Debian installer (d-i) branding — banner/logo
if [ -d /usr/share/graphics ]; then
    cp "$LOGO_SRC" /usr/share/graphics/logo_debian.png 2>/dev/null || true
fi

# Replace /usr/share/ubuntu-logo* if present
find /usr/share -name "ubuntu-logo*" -exec cp "$LOGO_SRC" {} \; 2>/dev/null || true
find /usr/share -name "ubuntu_logo*" -exec cp "$LOGO_SRC" {} \; 2>/dev/null || true

# LightDM greeter logo
if [ -d /usr/share/unity-greeter ]; then
    cp "$LOGO_SRC" /usr/share/unity-greeter/logo.png
fi
cp "$LOGO_SRC" /usr/share/pixmaps/tmjos-logo.png

# os-release — rebrand completely
cat > /usr/lib/os-release << 'EOF'
PRETTY_NAME="TMJOs 26.04"
NAME="TMJOs"
VERSION_ID="26.04"
VERSION="26.04 (Developer Edition)"
VERSION_CODENAME=tmjos
ID=tmjos
ID_LIKE=ubuntu debian
HOME_URL="https://github.com/TMJacometti/TMJOs"
SUPPORT_URL="https://github.com/TMJacometti/TMJOs/issues"
BUG_REPORT_URL="https://github.com/TMJacometti/TMJOs/issues"
PRIVACY_POLICY_URL="https://github.com/TMJacometti/TMJOs"
UBUNTU_CODENAME=plucky
EOF
cp /usr/lib/os-release /etc/os-release

# LSB release
cat > /etc/lsb-release << 'EOF'
DISTRIB_ID=TMJOs
DISTRIB_RELEASE=26.04
DISTRIB_CODENAME=tmjos
DISTRIB_DESCRIPTION="TMJOs 26.04 Developer Edition"
EOF

# Issue / motd
echo "TMJOs 26.04 Developer Edition \\n \\l" > /etc/issue
echo "TMJOs 26.04 Developer Edition" > /etc/issue.net

echo "[TMJOs] Branding complete."
