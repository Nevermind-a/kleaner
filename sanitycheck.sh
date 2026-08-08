#!/bin/bash
# Rocky Linux – dnf Sanity-Check mit optionaler Korrektur
# Speichern als: rocky-dnf-sanitycheck.sh
# Ausführen:   sudo bash rocky-dnf-sanitycheck.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Rocky Linux dnf Sanity-Check ===${NC}"
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
        "$@"
    else
        echo -e "  ${BLUE}[SIMULATION]${NC} $*"
    fi
    echo
}

# -------------------------------------------------
# 1. Grundlegende Checks (immer nur lesen)
# -------------------------------------------------
echo -e "${BLUE}[1/6] Prüfe dnf-Installation und Version...${NC}"
if ! command -v dnf &>/dev/null; then
    echo -e "${RED}dnf ist nicht installiert!${NC}"
    exit 1
fi
dnf --version | head -n1
echo

echo -e "${BLUE}[2/6] Prüfe Repository-Status...${NC}"
dnf repolist -v 2>&1 | head -n 30
echo

echo -e "${BLUE}[3/6] Prüfe auf defekte / fehlende Abhängigkeiten (dnf check)...${NC}"
CHECK_OUTPUT=$(dnf check 2>&1 || true)
if [[ -z "$CHECK_OUTPUT" ]]; then
    echo -e "${GREEN}Keine Probleme gefunden.${NC}"
else
    echo -e "${YELLOW}$CHECK_OUTPUT${NC}"
fi
echo

echo -e "${BLUE}[4/6] Prüfe Cache und Metadaten...${NC}"
dnf clean --help >/dev/null  # nur sicherstellen, dass clean existiert
echo "Aktuelle Cache-Größe:"
du -sh /var/cache/dnf 2>/dev/null || echo "Cache-Verzeichnis nicht vorhanden"
echo

echo -e "${BLUE}[5/6] Prüfe auf ausstehende Updates (nur Anzeige)...${NC}"
dnf check-update --quiet || true
echo

# -------------------------------------------------
# 2. Benutzerabfrage
# -------------------------------------------------
echo -e "${YELLOW}Möchtest du Korrekturen durchführen?${NC}"
echo "  - Cache leeren"
echo "  - Metadaten neu laden"
echo "  - dnf check + auto-repair (soweit möglich)"
echo "  - ggf. fehlende Abhängigkeiten beheben"
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
# 3. Korrekturen / Simulation
# -------------------------------------------------
echo -e "${BLUE}[6/6] Korrekturphase...${NC}"
echo

run_or_sim "Cache komplett leeren" dnf clean all

run_or_sim "Metadaten neu laden" dnf makecache

# dnf check mit automatischer Reparatur (soweit dnf das kann)
run_or_sim "Abhängigkeiten prüfen und reparieren" dnf check --assumeyes

# Optional: fehlende Pakete / broken packages
run_or_sim "Fehlende Abhängigkeiten installieren (falls vorhanden)" \
    dnf install --assumeyes --skip-broken $(rpm -qa --qf '%{NAME}\n' | head -0) 2>/dev/null || true

# Zusätzliche sinnvolle Aufräum-Aktion
run_or_sim "Alte Kernel-Pakete entfernen (nur wenn > 2 vorhanden)" \
    dnf remove --oldinstallonly --assumeyes 2>/dev/null || true

echo -e "${GREEN}=== Sanity-Check abgeschlossen ===${NC}"
if [[ "$DO_FIX" == "true" ]]; then
    echo -e "${GREEN}Änderungen wurden durchgeführt.${NC}"
else
    echo -e "${BLUE}Es wurden keine Änderungen vorgenommen (Simulation).${NC}"
fi
