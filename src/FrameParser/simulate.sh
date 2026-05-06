#!/bin/bash
set -e

# --- Configuration ---
WORK_DIR="work"
SRC_DIR="src"
TB_DIR="tb"
WAVE_DIR="waves"

# Default testbench entity name (override with first argument)
TB_ENTITY="${1:-fcs_check_serial_tb}"

# --- Setup ---
mkdir -p "$WORK_DIR" "$WAVE_DIR"

# --- How GHDL compilation works ---
# Step 1: ANALYZE (-a)
#   Parses each .vhd file and stores it in the work library.
#   Order matters: dependencies must be analyzed FIRST.
#   Your entity (fcs_check_serial) must come before the testbench
#   that instantiates it.
#
# Step 2: ELABORATE (-e)
#   Links everything together for a specific top-level entity.
#   Resolves all component/entity instantiations.
#
# Step 3: RUN (-r)
#   Executes the simulation. This is where your `wait` statements,
#   assertions, and reports actually run.

echo "=== Analyzing source files ==="
for f in "$SRC_DIR"/*.vhd; do
    echo "  [analyze] $f"
    ghdl -a --workdir="$WORK_DIR" "$f"
done

echo "=== Analyzing testbench files ==="
for f in "$TB_DIR"/*.vhd; do
    echo "  [analyze] $f"
    ghdl -a --workdir="$WORK_DIR" "$f"
done

echo "=== Elaborating: $TB_ENTITY ==="
ghdl -e --workdir="$WORK_DIR" "$TB_ENTITY"

echo "=== Running simulation ==="
VCD_FILE="$WAVE_DIR/${TB_ENTITY}.vcd"
ghdl -r --workdir="$WORK_DIR" "$TB_ENTITY" \
    --vcd="$VCD_FILE" \
    --stop-time=100us

echo ""
echo "=== Done. Waveform: $VCD_FILE ==="
echo "Run: gtkwave $VCD_FILE"
