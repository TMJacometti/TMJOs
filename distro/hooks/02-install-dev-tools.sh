#!/bin/bash
set -e

echo "[TMJOs] Installing dev tools (all pre-installed, zero setup for user)..."

# Git (from packages.list, but ensure latest)
apt-get install -y git

# Python 3.12 — set as default python3
apt-get install -y python3.12 python3.12-venv python3-pip
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
update-alternatives --set python3 /usr/bin/python3.12

# Node.js LTS via NodeSource
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# .NET 10 SDK
curl -fsSL https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb -o /tmp/ms-prod.deb
dpkg -i /tmp/ms-prod.deb
rm /tmp/ms-prod.deb
apt-get update
apt-get install -y dotnet-sdk-10.0

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
