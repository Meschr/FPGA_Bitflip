# sim.ps1 — Interaktives GHDL Simulations-Skript für Windows (PowerShell)
# Benutzung: powershell -ExecutionPolicy Bypass -File sim.ps1

# =======================================================================
# Farbausgabe für Windows
# =======================================================================
function Write-Cyan { Write-Host $args[0] -ForegroundColor Cyan }
function Write-Yellow { Write-Host $args[0] -ForegroundColor Yellow }
function Write-White { Write-Host $args[0] -ForegroundColor White }
function Write-Green { Write-Host $args[0] -ForegroundColor Green }
function Write-Red { Write-Host $args[0] -ForegroundColor Red }
function Write-Gray { Write-Host $args[0] -ForegroundColor Gray }

Write-Host ""
Write-Cyan "========================================"
Write-Cyan "   GHDL Simulation + GTKWave"
Write-Cyan "========================================"
Write-Host ""

# Arbeitsverzeichnis = dort wo das Skript liegt
Push-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

# work- und waves-Ordner erstellen falls nötig
if (!(Test-Path "work")) { New-Item -ItemType Directory -Path "work" | Out-Null }
if (!(Test-Path "waves")) { New-Item -ItemType Directory -Path "waves" | Out-Null }

# =======================================================================
# Schritt 1: Alle .vhd Dateien in src/ suchen
# =======================================================================
$srcFiles = Get-ChildItem -Path "src" -Filter "*.vhd" -ErrorAction SilentlyContinue

if ($null -eq $srcFiles -or $srcFiles.Count -eq 0) {
    # Falls kein src/ Ordner: suche im aktuellen Ordner (ohne tb_*)
    $srcFiles = Get-ChildItem -Path "." -Filter "*.vhd" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "tb_*" }
}

if ($null -eq $srcFiles -or $srcFiles.Count -eq 0) {
    Write-Red "FEHLER: Keine VHDL-Dateien gefunden!"
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}

# Stelle sicher, dass srcFiles ein Array ist
if ($srcFiles -isnot [array]) {
    $srcFiles = @($srcFiles)
}

# =======================================================================
# Entity-Extraktion (vereinfacht für PowerShell)
# =======================================================================

function Extract-EntityNames {
    param([string]$filePath)
    
    $content = Get-Content $filePath -Raw
    $matches = [regex]::Matches($content, 'entity\s+([a-zA-Z0-9_]+)\s+is', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    $entities = @()
    foreach ($match in $matches) {
        $entities += $match.Groups[1].Value.ToLower()
    }
    return $entities
}

# Build entity->file map
$entityToFile = @{}

Write-Cyan "=== Analysiere Entities ===" 
foreach ($file in $srcFiles) {
    $entities = Extract-EntityNames $file.FullName
    foreach ($entity in $entities) {
        $entityToFile[$entity] = $file
        Write-Gray "  Entity '$entity' in $($file.Name)"
    }
}

# =======================================================================
# Top-Level Entity auswählen
# =======================================================================
Write-Host ""
Write-Yellow "Verfuegbare Top-Level Entities:"

$sortedEntities = @($entityToFile.Keys | Sort-Object)

for ($i = 0; $i -lt $sortedEntities.Count; $i++) {
    $entity = $sortedEntities[$i]
    $file = $entityToFile[$entity]
    Write-White "  [$($i+1)] $entity ($($file.Name))"
}
Write-Host ""

$entityChoice = Read-Host "Welche Top-Entity kompilieren? (Nummer)"
$entityIndex = [int]$entityChoice - 1

if ($entityIndex -lt 0 -or $entityIndex -ge $sortedEntities.Count) {
    Write-Red "FEHLER: Ungültige Auswahl!"
    exit 1
}

$selectedEntity = $sortedEntities[$entityIndex]
$selectedFile = $entityToFile[$selectedEntity]

# =======================================================================
# Schritt 2: Source-Dateien kompilieren
# =======================================================================
Write-Host ""
Write-Cyan "=== Kompiliere Source-Dateien ==="
Write-Gray "  Kompiliere: $($selectedFile.Name)"

ghdl -a --std=08 --workdir=work $selectedFile.FullName
if ($LASTEXITCODE -ne 0) {
    Write-Red "FEHLER beim Kompilieren der Quelle!"
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}
Write-Green "  OK!"

# =======================================================================
# Schritt 3: Alle tb_*.vhd Dateien suchen
# =======================================================================
$tbFiles = @()
$tbFiles += @(Get-ChildItem -Path "src" -Filter "tb_*.vhd" -ErrorAction SilentlyContinue)
$tbFiles += @(Get-ChildItem -Path "tb" -Filter "tb_*.vhd" -ErrorAction SilentlyContinue)
$tbFiles += @(Get-ChildItem -Path "." -Filter "tb_*.vhd" -ErrorAction SilentlyContinue -MaxDepth 1)

# Duplikate entfernen
$tbFiles = $tbFiles | Sort-Object -Property FullName -Unique

if ($null -eq $tbFiles -or $tbFiles.Count -eq 0) {
    Write-Red "FEHLER: Keine Testbench-Dateien (tb_*.vhd) gefunden!"
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}

if ($tbFiles -isnot [array]) {
    $tbFiles = @($tbFiles)
}

Write-Host ""
Write-Yellow "Gefundene Testbenches:"

for ($i = 0; $i -lt $tbFiles.Count; $i++) {
    Write-White "  [$($i+1)] $($tbFiles[$i].Name)"
}
Write-Host ""

$tbChoice = Read-Host "Welche Testbench simulieren? (Nummer)"
$tbIndex = [int]$tbChoice - 1

if ($tbIndex -lt 0 -or $tbIndex -ge $tbFiles.Count) {
    Write-Red "FEHLER: Ungültige Auswahl!"
    exit 1
}

$selectedTb = $tbFiles[$tbIndex]
$entity = $selectedTb.BaseName

# =======================================================================
# Schritt 4: Testbench kompilieren
# =======================================================================
Write-Host ""
Write-Cyan "=== Kompiliere Testbench: $($selectedTb.Name) ==="

ghdl -a --std=08 --workdir=work $selectedTb.FullName
if ($LASTEXITCODE -ne 0) {
    Write-Red "FEHLER beim Kompilieren der Testbench!"
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}
Write-Green "  OK!"

# =======================================================================
# Schritt 5: Elaborieren
# =======================================================================
Write-Host ""
Write-Cyan "=== Elaboriere: $entity ==="

ghdl -e --std=08 --workdir=work $entity
if ($LASTEXITCODE -ne 0) {
    Write-Red "FEHLER beim Elaborieren!"
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}
Write-Green "  OK!"

# =======================================================================
# Schritt 6: Simulieren
# =======================================================================
$waveFile = "waves\${entity}.ghw"

Write-Host ""
Write-Cyan "=== Simuliere: $entity ==="
Write-Gray "  Wave-Datei: $waveFile"
Write-Host ""

ghdl -r --std=08 --workdir=work $entity --wave=$waveFile --stop-time=1000us
$simResult = $LASTEXITCODE

if ($simResult -ne 0) {
    Write-Host ""
    Write-Yellow "Simulation mit Fehlern beendet (siehe oben)"
} else {
    Write-Host ""
    Write-Green "Simulation erfolgreich!"
}

# =======================================================================
# Schritt 7: GTKWave öffnen
# =======================================================================
Write-Host ""
$openGtk = Read-Host "GTKWave oeffnen? (j/n) [j]"
if ([string]::IsNullOrWhiteSpace($openGtk)) {
    $openGtk = "j"
}

if ($openGtk -match "^[Jj]$") {
    if (Test-Path $waveFile) {
        Write-Cyan "Oeffne GTKWave..."
        Start-Process "gtkwave" -ArgumentList $waveFile
    } else {
        Write-Red "Wave-Datei nicht gefunden: $waveFile"
    }
}

Write-Host ""
Write-Cyan "========================================"
Write-Cyan "   Fertig!"
Write-Cyan "========================================"
Write-Host ""
Read-Host "Druecke Enter zum Beenden"

Pop-Location
