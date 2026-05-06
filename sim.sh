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

# =====================================================================
# VHDL-Abhängigkeitsanalyse
# =====================================================================

# Extrahiert alle Entity-Namen, die eine Datei definiert
extract_entity_names() {
    local file="$1"
    grep -i "^[[:space:]]*entity[[:space:]]" "$file" 2>/dev/null | \
        sed -E 's/^[[:space:]]*entity[[:space:]]+([a-zA-Z0-9_]+).*/\1/' | \
        tr '[:upper:]' '[:lower:]'
}

# Extrahiert alle Abhängigkeiten
extract_dependencies() {
    local file="$1"
    (
        # Match: entity work.entity_name
        grep -i "entity[[:space:]]*work\." "$file" 2>/dev/null | \
            sed -E 's/.*entity[[:space:]]*work\.([a-zA-Z0-9_]+).*/\1/'
        
        # Match: instance_name : component_name port map
        grep -iE "[a-zA-Z0-9_]+[[:space:]]*:[[:space:]]*[a-zA-Z0-9_]+[[:space:]]+(port|generic)[[:space:]]*map" "$file" 2>/dev/null | \
            sed -E 's/[a-zA-Z0-9_]+[[:space:]]*:[[:space:]]*([a-zA-Z0-9_]+).*/\1/'
    ) | tr '[:upper:]' '[:lower:]' | sort | uniq
}

# Build entity->file map and find dependencies
declare -A entity_to_file
declare -A entity_dependencies

echo -e "${CYAN}=== Analysiere Entities und Abhängigkeiten ===${NC}"
for file in "${srcFiles[@]}"; do
    for entity in $(extract_entity_names "$file"); do
        entity_to_file["$entity"]="$file"
        echo -e "  ${GRAY}Entity '$entity' in $(basename "$file")${NC}"
    done
done

echo ""
for file in "${srcFiles[@]}"; do
    deps=$(extract_dependencies "$file")
    if [ -n "$deps" ]; then
        echo -e "  ${GRAY}$(basename "$file") depends on:${NC}"
        for dep in $deps; do
            echo -e "    ${GRAY}→ $dep${NC}"
        done
        entity_dependencies["$file"]="$deps"
    fi
done

# Show available top entities
echo ""
echo -e "${YELLOW}Verfuegbare Top-Level Entities:${NC}"
declare -a entities=()
for entity in "${!entity_to_file[@]}"; do
    entities+=("$entity")
done

# Sort entities
IFS=$'\n' sorted_entities=($(sort <<<"${entities[*]}"))
unset IFS

for i in "${!sorted_entities[@]}"; do
    entity="${sorted_entities[$i]}"
    file="${entity_to_file[$entity]}"
    echo -e "  ${WHITE}[$((i+1))] $entity ($(basename "$file"))${NC}"
done
echo ""

read -rp "Welche Top-Entity kompilieren? (Nummer): " entityChoice
entityIndex=$((entityChoice - 1))
selected_entity="${sorted_entities[$entityIndex]}"

# Recursively find all dependencies
declare -a selectedSrc=()
declare -A processed_entities=()
declare -A added_files=()

add_with_dependencies() {
    local entity="$1"
    entity=$(echo "$entity" | tr '[:upper:]' '[:lower:]')
    
    # Already processed?
    if [[ "${processed_entities[$entity]}" == "1" ]]; then
        return
    fi
    processed_entities["$entity"]="1"
    
    # Find file for this entity
    if [[ -n "${entity_to_file[$entity]}" ]]; then
        local file="${entity_to_file[$entity]}"
        
        # Recursively add dependencies first
        local deps="${entity_dependencies[$file]}"
        for dep in $deps; do
            add_with_dependencies "$dep"
        done
        
        # Add this file (if not already added)
        if [[ "${added_files[$file]}" != "1" ]]; then
            selectedSrc+=("$file")
            added_files["$file"]="1"
            echo -e "  ${GREEN}Added: $entity from $(basename "$file")${NC}"
        fi
    fi
}

echo ""
echo -e "${CYAN}=== Bestimme Abhängigkeiten von '$selected_entity' ===${NC}"
add_with_dependencies "$selected_entity"

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