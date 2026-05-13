# sim.ps1 — Interaktives GHDL Simulations-Skript
# Benutzung: Rechtsklick -> "Mit PowerShell ausfuehren"
#        oder im Terminal: powershell -ExecutionPolicy Bypass -File sim.ps1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GHDL Simulation + GTKWave" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Arbeitsverzeichnis = dort wo das Skript liegt
Set-Location $PSScriptRoot

# work-Ordner erstellen falls noetig
if (!(Test-Path "work")) { New-Item -ItemType Directory -Path "work" | Out-Null }
if (!(Test-Path "waves")) { New-Item -ItemType Directory -Path "waves" | Out-Null }

# =====================================================================
# Schritt 1: Alle .vhd Dateien rekursiv suchen
# =====================================================================
$srcRoot = if (Test-Path (Join-Path $PSScriptRoot "src")) { "src" } else { "." }
$srcFiles = Get-ChildItem -Path $srcRoot -Recurse -Filter "*.vhd" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike "tb_*" -and $_.FullName -notmatch '\\tb\\' }

if ($null -eq $srcFiles -or $srcFiles.Count -eq 0) {
    # Falls kein src/ Ordner: suche im aktuellen Ordner (ohne tb_*)
    $srcFiles = Get-ChildItem -Path "." -Filter "*.vhd" | Where-Object { $_.Name -notlike "tb_*" }
}

if ($null -eq $srcFiles -or $srcFiles.Count -eq 0) {
    Write-Host "FEHLER: Keine VHDL-Dateien gefunden!" -ForegroundColor Red
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}

Write-Host "Gefundene Source-Dateien:" -ForegroundColor Yellow
for ($i = 0; $i -lt $srcFiles.Count; $i++) {
    $relPath = $srcFiles[$i].FullName.Substring($PSScriptRoot.Length + 1)
    Write-Host "  [$($i+1)] $relPath" -ForegroundColor White
}
Write-Host "  [A] Alle kompilieren" -ForegroundColor Green
Write-Host ""

$srcChoice = Read-Host "Welche kompilieren? (Nummer, mehrere mit Komma, oder A fuer alle)"

if ($srcChoice -eq "A" -or $srcChoice -eq "a") {
    $selectedSrc = $srcFiles
} else {
    $indices = $srcChoice -split "," | ForEach-Object { [int]$_.Trim() - 1 }
    $selectedSrc = $indices | ForEach-Object { $srcFiles[$_] }
}

$preferredOrder = @(
    "frame_parser.vhd",
    "fcs_check_parallel.vhd",
    "crc_to_voq_buffer.vhd",
    "frame_handler.vhd",
    "round_robin.vhd",
    "voq_fifo.vhd",
    "voq_4to1.vhd",
    "crossbar_switch.vhd",
    "voq_rr_crossbar.vhd",
    "voq_rr_crossbar_top.vhd",
    "voq_rr_crossbar_switch_top.vhd"
)

$selectedSrc = $selectedSrc | Sort-Object @{ Expression = {
    $position = [array]::IndexOf($preferredOrder, $_.Name)
    if ($position -lt 0) { 999 } else { $position }
  } }, Name

# =====================================================================
# Schritt 2: Source-Dateien kompilieren
# =====================================================================
Write-Host ""
Write-Host "=== Kompiliere Source-Dateien ===" -ForegroundColor Cyan

foreach ($file in $selectedSrc) {
    Write-Host "  Kompiliere: $($file.Name)" -ForegroundColor Gray
    ghdl -a --std=08 --workdir=work $file.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FEHLER bei: $($file.Name)" -ForegroundColor Red
        Read-Host "Druecke Enter zum Beenden"
        exit 1
    }
}
Write-Host "  OK!" -ForegroundColor Green

# =====================================================================
# Schritt 3: Alle tb_*.vhd Dateien suchen
# =====================================================================
$tbFiles = Get-ChildItem -Path "tb" -Filter "tb_*.vhd" -ErrorAction SilentlyContinue

if ($null -eq $tbFiles -or $tbFiles.Count -eq 0) {
    # Falls kein tb/ Ordner: suche im aktuellen Ordner
    $tbFiles = Get-ChildItem -Path "." -Filter "tb_*.vhd"
}

if ($null -eq $tbFiles -or $tbFiles.Count -eq 0) {
    Write-Host "FEHLER: Keine Testbench-Dateien (tb_*.vhd) gefunden!" -ForegroundColor Red
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}

Write-Host ""
Write-Host "Gefundene Testbenches:" -ForegroundColor Yellow
for ($i = 0; $i -lt $tbFiles.Count; $i++) {
    Write-Host "  [$($i+1)] $($tbFiles[$i].Name)" -ForegroundColor White
}
Write-Host ""

$tbChoice = Read-Host "Welche Testbench simulieren? (Nummer)"
$tbIndex = [int]$tbChoice - 1
$selectedTb = $tbFiles[$tbIndex]

# Entity-Name = Dateiname ohne .vhd
$entity = $selectedTb.BaseName

# =====================================================================
# Schritt 4: Testbench kompilieren
# =====================================================================
Write-Host ""
Write-Host "=== Kompiliere Testbench: $($selectedTb.Name) ===" -ForegroundColor Cyan

ghdl -a --std=08 --workdir=work $selectedTb.FullName
if ($LASTEXITCODE -ne 0) {
    Write-Host "FEHLER beim Kompilieren der Testbench!" -ForegroundColor Red
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}
Write-Host "  OK!" -ForegroundColor Green

# =====================================================================
# Schritt 5: Elaborieren
# =====================================================================
Write-Host ""
Write-Host "=== Elaboriere: $entity ===" -ForegroundColor Cyan

ghdl -e --std=08 --workdir=work $entity
if ($LASTEXITCODE -ne 0) {
    Write-Host "FEHLER beim Elaborieren!" -ForegroundColor Red
    Read-Host "Druecke Enter zum Beenden"
    exit 1
}
Write-Host "  OK!" -ForegroundColor Green

# =====================================================================
# Schritt 6: Simulieren
# =====================================================================
$waveFile = "waves\$entity.ghw"

Write-Host ""
Write-Host "=== Simuliere: $entity ===" -ForegroundColor Cyan
Write-Host "  Wave-Datei: $waveFile" -ForegroundColor Gray
Write-Host ""

ghdl -r --std=08 --workdir=work $entity --wave=$waveFile --stop-time=10us
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Simulation mit Fehlern beendet (siehe oben)" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Simulation erfolgreich!" -ForegroundColor Green
}

# =====================================================================
# Schritt 7: GTKWave oeffnen
# =====================================================================
Write-Host ""
$openGtk = Read-Host "GTKWave oeffnen? (j/n)"

if ($openGtk -eq "j" -or $openGtk -eq "J" -or $openGtk -eq "") {
    if (Test-Path $waveFile) {
        Write-Host "Oeffne GTKWave..." -ForegroundColor Cyan
        Start-Process "gtkwave" -ArgumentList $waveFile
    } else {
        Write-Host "Wave-Datei nicht gefunden: $waveFile" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Fertig!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Druecke Enter zum Beenden"
