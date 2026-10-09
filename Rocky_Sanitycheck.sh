#!/bin/bash
# Rocky Linux – dnf + Flatpak + Filesystem Sanity-Check
# Speichern als: rocky-sanitycheck.sh
# Ausführen:   sudo bash rocky-sanitycheck.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== Rocky Linux Sanity-Check (dnf + Flatpak + Filesystem) ===${NC}"
echo

# Root-Check
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Fehler: Das Skript muss als root (sudo) ausgeführt werden.${NC}"
    exit 1
fi

# Hilfsfunktion: Befehl ausführen oder nur anzeigen
run_or_sim() {
    local description="$1"
    shift
    echo -e "${YELLOW}→ $description${NC}"
    if [[ "$DO_FIX" == "true" ]]; then
        echo -e "  ${GREEN}[AUSFÜHREN]${NC} $*"
        "$@" || echo -e "  ${YELLOW}(Warnung: Befehl hat Exit-Code != 0)${NC}"
    else
        echo -e "  ${BLUE}[SIMULATION]${NC} $*"
    fi
    echo
}

# -------------------------------------------------
# 1. dnf Checks
# -------------------------------------------------
echo -e "${CYAN}========== [1] dnf Paketmanager ==========${NC}"
echo

echo -e "${BLUE}[1.1] dnf-Version...${NC}"
if ! command -v dnf &>/dev/null; then
    echo -e "${RED}dnf ist nicht installiert!${NC}"
else
    dnf --version | head -n1
fi
echo

echo -e "${BLUE}[1.2] Repository-Status...${NC}"
dnf repolist 2>&1 | head -n 25
echo

echo -e "${BLUE}[1.3] dnf check (defekte Abhängigkeiten)...${NC}"
CHECK_OUTPUT=$(dnf check 2>&1 || true)
if [[ -z "$CHECK_OUTPUT" ]]; then
    echo -e "${GREEN}Keine Probleme gefunden.${NC}"
else
    echo -e "${YELLOW}$CHECK_OUTPUT${NC}"
fi
echo

echo -e "${BLUE}[1.4] Cache-Größe...${NC}"
du -sh /var/cache/dnf 2>/dev/null || echo "Cache-Verzeichnis nicht vorhanden"
echo

echo -e "${BLUE}[1.5] Ausstehende Updates (nur Anzeige)...${NC}"
dnf check-update --quiet 2>/dev/null || true
echo

# -------------------------------------------------
# 2. Flatpak Checks
# -------------------------------------------------
echo -e "${CYAN}========== [2] Flatpak ==========${NC}"
echo

if command -v flatpak &>/dev/null; then
    echo -e "${BLUE}[2.1] Flatpak-Version...${NC}"
    flatpak --version
    echo

    echo -e "${BLUE}[2.2] Remotes...${NC}"
    flatpak remotes -d 2>/dev/null || flatpak remotes
    echo

    echo -e "${BLUE}[2.3] Installierte Anwendungen (Kurzübersicht)...${NC}"
    flatpak list --app --columns=application,version,origin 2>/dev/null | head -n 20
    echo

    echo -e "${BLUE}[2.4] Verfügbare Updates...${NC}"
    flatpak remote-ls --updates 2>/dev/null || echo "Keine Updates oder Fehler beim Abruf"
    echo

    echo -e "${BLUE}[2.5] Unused Runtimes / Erweiterungen...${NC}"
    flatpak uninstall --unused --dry-run 2>/dev/null || true
    echo
else
    echo -e "${YELLOW}Flatpak ist nicht installiert – Abschnitt wird übersprungen.${NC}"
    echo
fi

# -------------------------------------------------
# 3. Filesystem Checks
# -------------------------------------------------
echo -e "${CYAN}========== [3] Filesystem ==========${NC}"
echo

echo -e "${BLUE}[3.1] Speicherplatz (df -h)...${NC}"
df -hT -x tmpfs -x devtmpfs
echo

echo -e "${BLUE}[3.2] Inode-Nutzung...${NC}"
df -i -x tmpfs -x devtmpfs
echo

echo -e "${BLUE}[3.3] Read-Only / problematische Mounts...${NC}"
mount | grep -E 'ro,|errors=' || echo -e "${GREEN}Keine Read-Only- oder Error-Mounts gefunden.${NC}"
echo

echo -e "${BLUE}[3.4] Kritische Verzeichnisse (Größe)...${NC}"
du -sh /var/log /var/cache /var/tmp /tmp /home 2>/dev/null || true
echo

echo -e "${BLUE}[3.5] Große Dateien > 1 GB (Top 10)...${NC}"
find / -xdev -type f -size +1G -printf '%s %p\n' 2>/dev/null | sort -nr | head -n 10 | awk '{printf "%.1fG  %s\n", $1/1024/1024/1024, $2}'
echo

echo -e "${BLUE}[3.6] SMART-Status (falls smartctl vorhanden)...${NC}"
if command -v smartctl &>/dev/null; then
    for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
        [[ -b "$disk" ]] || continue
        echo "--- $disk ---"
        smartctl -H "$disk" 2>/dev/null | grep -E 'SMART overall-health|PASSED|FAILED' || echo "Keine SMART-Daten"
    done
else
    echo "smartctl nicht installiert (optional: dnf install smartmontools)"
fi
echo

# -------------------------------------------------
# 4. Benutzerabfrage
# -------------------------------------------------
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Möchtest du Korrekturen durchführen?${NC}"
echo
echo "  dnf:"
echo "    • Cache leeren + Metadaten neu laden"
echo "    • dnf check + Reparaturversuche"
echo "    • Alte Kernel entfernen"
echo
echo "  Flatpak (falls installiert):"
echo "    • Unused Runtimes entfernen"
echo "    • flatpak repair"
echo "    • Updates einspielen"
echo
echo "  Filesystem:"
echo "    • Alte Logs rotieren / journal vacuum"
echo "    • /tmp und /var/tmp aufräumen (älter als 7 Tage)"
echo
read -rp "Korrekturen wirklich ausführen? [j/N]: " answer

if [[ "$answer" =~ ^[jJyY]$ ]]; then
    DO_FIX="true"
    echo -e "${GREEN}→ Korrekturmodus aktiviert${NC}"
else
    DO_FIX="false"
    echo -e "${BLUE}→ Nur Simulation (keine Änderungen)${NC}"
fi
echo

# -------------------------------------------------
# 5. Korrekturen / Simulation
# -------------------------------------------------
echo -e "${CYAN}========== Korrekturphase ==========${NC}"
echo

# --- dnf ---
echo -e "${BLUE}--- dnf ---${NC}"
run_or_sim "dnf Cache komplett leeren" dnf clean all
run_or_sim "dnf Metadaten neu laden" dnf makecache
run_or_sim "dnf check + Reparatur" dnf check --assumeyes
run_or_sim "Alte Kernel entfernen (falls >2 vorhanden)" dnf remove --oldinstallonly --assumeyes

# --- Flatpak ---
if command -v flatpak &>/dev/null; then
    echo -e "${BLUE}--- Flatpak ---${NC}"
    run_or_sim "Unused Flatpak-Runtimes entfernen" flatpak uninstall --unused -y
    run_or_sim "Flatpak Repair" flatpak repair
    run_or_sim "Flatpak Updates einspielen" flatpak update -y
fi

# --- Filesystem ---
echo -e "${BLUE}--- Filesystem ---${NC}"
run_or_sim "Journald vacuum (behalte 7 Tage)" journalctl --vacuum-time=7d
run_or_sim "Alte Dateien in /tmp löschen (>7 Tage)" find /tmp -type f -atime +7 -delete
run_or_sim "Alte Dateien in /var/tmp löschen (>7 Tage)" find /var/tmp -type f -atime +7 -delete

echo -e "${GREEN}=== Sanity-Check abgeschlossen ===${NC}"
if [[ "$DO_FIX" == "true" ]]; then
    echo -e "${GREEN}Änderungen wurden durchgeführt.${NC}"
else
    echo -e "${BLUE}Es wurden keine Änderungen vorgenommen (Simulation).${NC}"
fi
