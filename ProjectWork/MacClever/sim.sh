#!/usr/bin/env bash
# sim.sh — Interaktives GHDL Simulations-Skript für Linux
# Benutzung: chmod +x sim.sh && ./sim.sh

# Farben
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   GHDL Simulation + GTKWave${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Arbeitsverzeichnis = dort wo das Skript liegt
cd "$(dirname "$0")"

# work- und waves-Ordner erstellen falls nötig
mkdir -p work waves

# =====================================================================
# Schritt 1: Alle .vhd Dateien in src/ suchen
# =====================================================================
mapfile -t srcFiles < <(find src -name "*.vhd" 2>/dev/null | sort)

if [ ${#srcFiles[@]} -eq 0 ]; then
    # Falls kein src/ Ordner: suche im aktuellen Ordner (ohne tb_*)
    mapfile -t srcFiles < <(find . -maxdepth 1 -name "*.vhd" ! -name "tb_*" | sort)
fi

if [ ${#srcFiles[@]} -eq 0 ]; then
    echo -e "${RED}FEHLER: Keine VHDL-Dateien gefunden!${NC}"
    read -rp "Druecke Enter zum Beenden"
    exit 1
fi

echo -e "${YELLOW}Gefundene Source-Dateien:${NC}"
for i in "${!srcFiles[@]}"; do
    echo -e "  ${WHITE}[$((i+1))] $(basename "${srcFiles[$i]}")${NC}"
done
echo -e "  ${GREEN}[A] Alle kompilieren${NC}"
echo ""

read -rp "Welche kompilieren? (Nummer, mehrere mit Komma, oder A fuer alle): " srcChoice

# =====================================================================
# VHDL-Abhängigkeitsanalyse
# =====================================================================

# Extrahiert alle Pakete, die eine Datei definiert
extract_package_names() {
    local file="$1"
    grep -i "^[[:space:]]*package[[:space:]]" "$file" 2>/dev/null | \
        sed -E 's/^[[:space:]]*package[[:space:]]+(body[[:space:]]+)?([a-zA-Z0-9_]+).*/\2/' | \
        tr '[:upper:]' '[:lower:]'
}

# Extrahiert alle Abhängigkeiten (use-Statements) einer Datei
extract_dependencies() {
    local file="$1"
    grep -i "^[[:space:]]*use[[:space:]]" "$file" 2>/dev/null | \
        sed -E 's/^[[:space:]]*use[[:space:]]+([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+).*/\2/' | \
        tr '[:upper:]' '[:lower:]' | sort | uniq
}

# Topologische Sortierung: kompiliert Dateien in richtiger Abhängigkeitsreihenfolge
topological_sort() {
    declare -A packages
    declare -A dependencies
    declare -a ordered=()
    declare -a remaining=("$@")
    local iterations=0
    local max_iterations=${#remaining[@]}

    # Schritt 1: Alle Pakete sammeln
    for file in "${remaining[@]}"; do
        for pkg in $(extract_package_names "$file"); do
            packages["$pkg"]="$file"
        done
    done

    # Schritt 2: Abhängigkeiten sammeln
    for file in "${remaining[@]}"; do
        dependencies["$file"]="$(extract_dependencies "$file")"
    done

    # Schritt 3: Topologisch sortieren
    while [ ${#remaining[@]} -gt 0 ] && [ $iterations -lt $((max_iterations + 10)) ]; do
        iterations=$((iterations + 1))
        local progress=0

        for i in "${!remaining[@]}"; do
            local file="${remaining[$i]}"
            local deps="${dependencies[$file]}"
            local can_compile=1

            # Prüfe ob alle Abhängigkeiten erfüllt sind
            for dep in $deps; do
                if [[ -n "${packages[$dep]}" ]]; then
                    local dep_file="${packages[$dep]}"
                    # Prüfe ob dep_file schon kompiliert ist
                    local found=0
                    for compiled in "${ordered[@]}"; do
                        [[ "$compiled" == "$dep_file" ]] && found=1 && break
                    done
                    if [ $found -eq 0 ]; then
                        can_compile=0
                        break
                    fi
                fi
            done

            if [ $can_compile -eq 1 ]; then
                ordered+=("$file")
                unset 'remaining[$i]'
                progress=1
            fi
        done

        remaining=("${remaining[@]}")  # Kompakte Array ohne Lücken

        if [ $progress -eq 0 ] && [ ${#remaining[@]} -gt 0 ]; then
            # Keine Fortschritte → zirkuläre Abhängigkeiten? Restliche anhängen
            echo -e "${YELLOW}  Warnung: Ggfs. zirkuläre Abhängigkeiten. Kompiliere Rest in Reihenfolge...${NC}" >&2
            ordered+=("${remaining[@]}")
            remaining=()
        fi
    done

    printf '%s\n' "${ordered[@]}"
}

selectedSrc=()

if [[ "$srcChoice" =~ ^[Aa]$ ]]; then
    # Automatische topologische Sortierung
    echo -e "${CYAN}  Analysiere Abhängigkeiten...${NC}"
    mapfile -t selectedSrc < <(topological_sort "${srcFiles[@]}")
    if [ ${#selectedSrc[@]} -eq 0 ]; then
        selectedSrc=("${srcFiles[@]}")
    fi
else
    IFS=',' read -ra indices <<< "$srcChoice"
    for idx in "${indices[@]}"; do
        idx=$(echo "$idx" | tr -d ' ')
        selectedSrc+=("${srcFiles[$((idx-1))]}")
    done
fi

# =====================================================================
# Schritt 2: Source-Dateien kompilieren
# =====================================================================
echo ""
echo -e "${CYAN}=== Kompiliere Source-Dateien ===${NC}"

for file in "${selectedSrc[@]}"; do
    echo -e "  ${GRAY}Kompiliere: $(basename "$file")${NC}"
    ghdl -a --std=08 --workdir=work "$file"
    if [ $? -ne 0 ]; then
        echo -e "${RED}FEHLER bei: $(basename "$file")${NC}"
        read -rp "Druecke Enter zum Beenden"
        exit 1
    fi
done
echo -e "  ${GREEN}OK!${NC}"

# =====================================================================
# Schritt 3: Alle tb_*.vhd Dateien suchen
# =====================================================================
mapfile -t tbFiles < <(find tb -name "tb_*.vhd" 2>/dev/null | sort)

if [ ${#tbFiles[@]} -eq 0 ]; then
    mapfile -t tbFiles < <(find . -maxdepth 1 -name "tb_*.vhd" | sort)
fi

if [ ${#tbFiles[@]} -eq 0 ]; then
    echo -e "${RED}FEHLER: Keine Testbench-Dateien (tb_*.vhd) gefunden!${NC}"
    read -rp "Druecke Enter zum Beenden"
    exit 1
fi

echo ""
echo -e "${YELLOW}Gefundene Testbenches:${NC}"
for i in "${!tbFiles[@]}"; do
    echo -e "  ${WHITE}[$((i+1))] $(basename "${tbFiles[$i]}")${NC}"
done
echo ""

read -rp "Welche Testbench simulieren? (Nummer): " tbChoice
tbIndex=$((tbChoice - 1))
selectedTb="${tbFiles[$tbIndex]}"

# Entity-Name = Dateiname ohne .vhd
entity="$(basename "${selectedTb%.vhd}")"

# =====================================================================
# Schritt 4: Testbench kompilieren
# =====================================================================
echo ""
echo -e "${CYAN}=== Kompiliere Testbench: $(basename "$selectedTb") ===${NC}"

ghdl -a --std=08 --workdir=work "$selectedTb"
if [ $? -ne 0 ]; then
    echo -e "${RED}FEHLER beim Kompilieren der Testbench!${NC}"
    read -rp "Druecke Enter zum Beenden"
    exit 1
fi
echo -e "  ${GREEN}OK!${NC}"

# =====================================================================
# Schritt 5: Elaborieren
# =====================================================================
echo ""
echo -e "${CYAN}=== Elaboriere: $entity ===${NC}"

ghdl -e --std=08 --workdir=work "$entity"
if [ $? -ne 0 ]; then
    echo -e "${RED}FEHLER beim Elaborieren!${NC}"
    read -rp "Druecke Enter zum Beenden"
    exit 1
fi
echo -e "  ${GREEN}OK!${NC}"

# =====================================================================
# Schritt 6: Simulieren
# =====================================================================
waveFile="waves/${entity}.ghw"

echo ""
echo -e "${CYAN}=== Simuliere: $entity ===${NC}"
echo -e "  ${GRAY}Wave-Datei: $waveFile${NC}"
echo ""

ghdl -r --std=08 --workdir=work "$entity" --wave="$waveFile" --stop-time=1000us
simResult=$?

if [ $simResult -ne 0 ]; then
    echo ""
    echo -e "${YELLOW}Simulation mit Fehlern beendet (siehe oben)${NC}"
else
    echo ""
    echo -e "${GREEN}Simulation erfolgreich!${NC}"
fi

# =====================================================================
# Schritt 7: GTKWave öffnen
# =====================================================================
echo ""
read -rp "GTKWave oeffnen? (j/n) [j]: " openGtk
openGtk="${openGtk:-j}"

if [[ "$openGtk" =~ ^[Jj]$ ]]; then
    if [ -f "$waveFile" ]; then
        echo -e "${CYAN}Oeffne GTKWave...${NC}"
        gtkwave "$waveFile" &
    else
        echo -e "${RED}Wave-Datei nicht gefunden: $waveFile${NC}"
    fi
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Fertig!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
read -rp "Druecke Enter zum Beenden"