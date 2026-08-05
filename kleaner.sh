#!/bin/bash

echo "=== KDE Cleanup + Gaming/Tools Setup ==="

# === Entferne alten KDE-Bloat ===
echo "Entferne alte KDE-Pakete..."
sudo dnf remove -y \
    plasma-browser-integration \
    freecell-solver-data kpat libblack-hole-solver1 libfreecell-solver \
    kmahjongg libkmahjongg libkmahjongg-data kmines libkdegames \
    akregator akregator-libs neochat libquotient-qt6 libolm cmark-lib \
    krdc krdc-libs kontact kontact-libs kmouth qrca kolourpaint kolourpaint-libs libksane \
    okular okular-libs okular-part libspectre djvulibre-libs kf6-threadweaver \
    skanpage ksanecore kde-connect kdeconnectd kde-connect-libs kf6-kpeople \
    libfakekey openssh-askpass qt6-qtconnectivity fuse-sshfs \
    grantlee-editor grantlee-editor-libs kmail kmail-account-wizard kmail-libs \
    pim-data-exporter pim-data-exporter-libs pim-sieve-editor \
    krfb krfb-libs libvncserver elisa-player dragon \
    kdepim-runtime kdepim-runtime-libs kf6-kdav korganizer korganizer-libs qt6-qtnetworkauth \
    akonadi-calendar akonadi-contacts akonadi-import-wizard akonadi-search calendarsupport \
    eventviews grantleetheme incidenceeditor kaddressbook kaddressbook-libs kcalutils \
    kdepim-addons kdiagram kimap kitinerary kldap kontactinterface kpkpass ktnef \
    libgravatar libkdepim libksieve libphonenumber mailcommon mailimporter \
    mailimporter-akonadi messagelib pimcommon protobuf

# === Pika Backup ===
echo "Installiere Pika Backup + Abhängigkeiten..."
sudo dnf install -y gvfs-fuse gvfs-smb

# === Steam udev rules ===
echo "Installiere Steam udev rules..."
sudo curl -o /etc/udev/rules.d/60-steam-input.rules \
    https://raw.githubusercontent.com/ValveSoftware/steam-devices/master/60-steam-input.rules

# === OpenRGB udev rules ===
echo "Installiere OpenRGB udev rules..."
sudo curl -L https://openrgb.org/releases/release_0.9/openrgb-udev-install.sh | sudo bash

# === Mountpoint für 2. SSD ===
echo "Erstelle Mountpoint /mnt/data1..."
sudo mkdir -p /mnt/data1
sudo chown enrico:enrico /mnt/data1
sudo chmod 755 /mnt/data1

echo "Führe autoremove aus..."
sudo dnf autoremove -y

echo "=== Fertig! ==="
echo "Pika Backup, Steam und OpenRGB sollten jetzt richtig funktionieren."
