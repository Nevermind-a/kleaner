#!/bin/bash
# Installiert Multimedia-Codecs + OpenH264 für Firefox auf Rocky Linux 10
# Basiert auf: https://momandpop.network/2026/05/06/installing-codecs-on-rocky-linux-10-and-firefox/

set -euo pipefail

echo "==> 1. RPM Fusion (free + nonfree) installieren..."
if ! rpm -q rpmfusion-free-release &>/dev/null; then
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm
fi

echo "==> 2. CRB (CodeReady Builder) aktivieren..."
sudo dnf config-manager --set-enabled crb


echo "==> 3. Multimedia-Gruppen aktualisieren (mit --allowerasing)..."
sudo dnf groupupdate core -y
sudo dnf groupupdate multimedia \
    --setopt="install_weak_deps=False" \
    --exclude=PackageKit-gstreamer-plugin \
    --allowerasing -y
sudo dnf groupupdate sound-and-video -y

echo ""
echo "Fertig!"
echo ""
echo "Firefox neu starten und unter:"
echo "  Menü → Add-ons und Themes → Plugins"
echo "den OpenH264-Plugin aktivieren (falls nötig)."
echo ""
echo "Test-Seite: https://mozilla.github.io/webrtc-landing/pc_test.html"
