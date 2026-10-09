#!/bin/bash
#
# install-xpad-rocky10.sh  (aktualisiert – behebt Kernel 6.12.0-211 Kompatibilität)
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[!]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] || error "Bitte als root ausführen (sudo $0)"

KERNEL=$(uname -r)
log "Laufender Kernel: $KERNEL"

# Secure Boot
SECURE_BOOT=0
if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    SECURE_BOOT=1
    warn "Secure Boot ist AKTIV"
else
    log "Secure Boot ist deaktiviert / nicht erkannt"
fi

# Dependencies
log "Installiere Dependencies..."
dnf install -y epel-release >/dev/null 2>&1 || true
dnf install -y dkms git gcc make elfutils-libelf-devel "kernel-devel-${KERNEL}" kernel-headers mokutil \
    || error "Dependency-Installation fehlgeschlagen"

[[ -d "/usr/src/kernels/${KERNEL}" ]] || error "kernel-devel für ${KERNEL} fehlt!"

# Alten Stand entfernen
if dkms status 2>/dev/null | grep -q xpad; then
    warn "Entferne alte xpad-DKMS-Installation..."
    dkms remove xpad/0.4 --all 2>/dev/null || true
fi
rm -rf /usr/src/xpad-0.4

# Klonen
log "Klone paroj/xpad..."
git clone --depth 1 https://github.com/paroj/xpad.git /usr/src/xpad-0.4

# === FIX für Kernel 6.12.0-211 (RHEL/Rocky) ===
log "Patche xpad.c für Kernel 6.12.0-211 Kompatibilität..."
# Den problematischen Compatibility-Block auskommentieren
sed -i '/#if LINUX_VERSION_CODE < KERNEL_VERSION(6,16,0)/,/^#endif/{
    s|^|// |
}' /usr/src/xpad-0.4/xpad.c

# DKMS installieren
log "Baue und installiere xpad..."
dkms install -m xpad -v 0.4

# Laden
modprobe -r xpad 2>/dev/null || true
modprobe xpad || error "modprobe xpad fehlgeschlagen"

# Secure Boot Hinweis
if [[ $SECURE_BOOT -eq 1 ]]; then
    echo
    warn "=============================================="
    warn " Secure Boot ist aktiv!"
    warn "=============================================="
    if [[ -f /var/lib/dkms/mok.pub ]]; then
        log "Importiere DKMS-Key..."
        mokutil --import /var/lib/dkms/mok.pub
        warn "→ Jetzt neu starten und im MOK-Menü den Key bestätigen!"
    else
        warn "Kein mok.pub gefunden – manuelles Signieren nötig."
    fi
fi

# Auto-load
echo "xpad" > /etc/modules-load.d/xpad.conf
log "xpad wird ab jetzt automatisch geladen"

echo
log "=== Fertig ==="
echo "Prüfe mit:  modinfo xpad   |   lsmod | grep xpad"
echo "Controller anstecken und testen:  jstest /dev/js0"
