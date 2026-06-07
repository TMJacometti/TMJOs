#!/bin/bash
set -e

echo "[TMJOs] Installing dev tools (all pre-installed, zero setup for user)..."

# Git (from packages.list, but ensure latest)
apt-get install -y git

# Python 3 — use whatever version ships with this Ubuntu release
apt-get install -y python3 python3-venv python3-pip

# Node.js LTS via NodeSource
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# .NET SDK — try Ubuntu 26.04 feed, fallback to 24.04 feed
if curl -fsSL -o /tmp/ms-prod.deb https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb 2>/dev/null; then
    echo "[TMJOs] Using Microsoft feed for Ubuntu 26.04"
elif curl -fsSL -o /tmp/ms-prod.deb https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb 2>/dev/null; then
    echo "[TMJOs] Falling back to Microsoft feed for Ubuntu 24.04"
else
    echo "[TMJOs] WARNING: Microsoft .NET feed not available, skipping .NET"
fi
if [ -f /tmp/ms-prod.deb ]; then
    dpkg -i /tmp/ms-prod.deb
    rm /tmp/ms-prod.deb
    apt-get update
    apt-get install -y dotnet-sdk-10.0 || apt-get install -y dotnet-sdk-9.0 || echo "[TMJOs] WARNING: .NET SDK not available"
fi

# VSCode (pre-installed, opens out of the box)
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
apt-get update
apt-get install -y code

# TMJOs apps (tmjpad = editor nativo, tmjmenu = launcher, tmjstore = app store)
curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.gpg | tee /usr/share/keyrings/tmjos-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] https://packages.tmjos.com.br stable main" > /etc/apt/sources.list.d/tmjos.list
apt-get update
apt-get install -y tmjpad tmjmenu tmjstore

# Verify all tools are present
echo "[TMJOs] Verifying installations..."
git --version
python3 --version
node --version
dotnet --version
code --version || true
which tmjpad

echo "[TMJOs] All dev tools installed and ready."
