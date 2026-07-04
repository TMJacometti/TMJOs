#!/bin/bash
set -e

echo "[TMJOs] Setting up tmjMenu + tmjDock as default launcher..."

SKEL="/etc/skel"

# tmjDock autostart (replaces XFCE panel entirely)
mkdir -p "$SKEL/.config/autostart"
cat > "$SKEL/.config/autostart/tmjdock.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=TMJDock
Exec=tmjdock
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

# tmjMenu first-run script (keybindings: Super+Space = tmjmenu)
mkdir -p "$SKEL/.config/autostart"
cat > "$SKEL/.config/autostart/tmjmenu-first-run.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=TMJMenu Setup
Exec=tmjmenu-first-run
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Initialization
EOF

# XFCE keybinding: Super opens tmjmenu
mkdir -p "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml"
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Super&gt;space" type="string" value="tmjmenu"/>
      <property name="&lt;Super&gt;&lt;Shift&gt;h" type="string" value="tmjdock --toggle-hide"/>
      <property name="override" type="bool" value="true"/>
    </property>
  </property>
</channel>
EOF

# Disable XFCE panel completely (tmjDock replaces it)
# xfce4-panel won't start if the config says no panels
# Already handled via xfce4-panel.xml with empty panels array

# Remove XFCE panel from session startup
mkdir -p "$SKEL/.config/xfce4"
cat > "$SKEL/.config/xfce4/xfce4-session.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="sessions" type="empty">
    <property name="Failsafe" type="empty">
      <property name="Client0_Command" type="array">
        <value type="string" value="xfwm4"/>
      </property>
      <property name="Client1_Command" type="array">
        <value type="string" value="xfdesktop"/>
      </property>
      <property name="Client2_Command" type="array">
        <value type="string" value="tmjdock"/>
      </property>
      <property name="Count" type="int" value="3"/>
    </property>
  </property>
</channel>
EOF

echo "[TMJOs] tmjMenu/tmjDock configured as system launcher."
