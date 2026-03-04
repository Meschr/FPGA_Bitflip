# FPGA - Bitflip

Every assignment/project should follow this project structure

## Example Project Structure

```
.
├── src/                        # VHDL source files (synthesisable)
│   └── fcs_check_serial.vhd
├── tb/                         # VHDL testbenches (simulation only)
│   ├── tb1_fcs_check_serial.vhd
│   └── tb_fcs_serial.vhd
├── waves/                      # Generated VCD waveform files (git-ignored)
├── work/                       # GHDL compiled library (git-ignored)
├── simulate.sh                 # GHDL simulation script
├── Excercise1.qpf              # Quartus project file
├── Excercise1.qsf              # Quartus settings & pin assignments
└── README.md
```

## Prerequisites

- [GHDL](https://github.com/ghdl/ghdl) — open-source VHDL simulator
- [GTKWave](https://gtkwave.sourceforge.net/) — waveform viewer (optional)
- [Intel Quartus Prime](https://www.intel.com/content/www/us/en/products/details/fpga/development-tools/quartus-prime.html) — for synthesis & programming

## How the GHDL Build System Works

GHDL compiles and runs VHDL in three stages:

### 1. Analyze (`ghdl -a`)

```
ghdl -a --workdir=work src/fcs_check_serial.vhd
ghdl -a --workdir=work tb/tb1_fcs_check_serial.vhd
```

- Parses each `.vhd` file and checks syntax and semantics.
- Stores the compiled unit (entity, architecture, package) in the `work/` library.
- **Order matters**: dependencies must be analyzed first.
  Source entities before testbenches that instantiate them.

### 2. Elaborate (`ghdl -e`)

```
ghdl -e --workdir=work fcs_check_serial_tb
```

- Links all analyzed units together for a specific **top-level entity**.
- Resolves all `entity work.<name>` instantiations.
- The top-level is always your **testbench** (it has no ports).
- Fails if any dependency was not analyzed.

### 3. Run (`ghdl -r`)

```
ghdl -r --workdir=work fcs_check_serial_tb --vcd=waves/fcs_check_serial_tb.vcd --stop-time=100us
```

- Executes the simulation.
- Processes all concurrent and sequential statements.
- Stops when it hits a bare `wait;` statement or `--stop-time`.
- Outputs a waveform file (VCD or GHW) for viewing in GTKWave.

### Key Rule

If you change **any** `.vhd` file, you must **re-analyze** it (and anything
that depends on it) before re-elaborating. The `simulate.sh` script handles
this automatically by always re-analyzing all files.

## Running Simulations

The `simulate.sh` script wraps all three GHDL stages. It takes one argument:
the **entity name** of the testbench you want to run.

> **Important:** The argument is the VHDL **entity name** declared inside
> the file (`entity <name> is`), **not** the filename. These can differ.

### Usage

```bash
# Run with default testbench (fcs_check_serial_tb)
bash simulate.sh

# Run a specific testbench by entity name
bash simulate.sh fcs_check_serial_tb
bash simulate.sh tb_fcs_serial
```

### Finding Entity Names

If you're unsure what entity names are available, run:

```bash
grep -n "^entity" tb/*.vhd
```

Example output:

```
tb/tb1_fcs_check_serial.vhd:8:entity fcs_check_serial_tb is
tb/tb_fcs_serial.vhd:8:entity tb_fcs_serial is
```

The names after `entity` are what you pass to `simulate.sh`.

### Viewing Waveforms

After a successful simulation, a VCD file is generated in the `waves/` directory:

```bash
gtkwave waves/fcs_check_serial_tb.vcd
```

## Quick Reference

| Task                       | Command                           |
| -------------------------- | --------------------------------- |
| Run default testbench      | `bash simulate.sh`                |
| Run specific testbench     | `bash simulate.sh <entity_name>`  |
| Find available testbenches | `grep -n "^entity" tb/*.vhd`      |
| View waveform              | `gtkwave waves/<entity_name>.vcd` |
| Clean build artifacts      | `rm -rf work/ waves/`             |
| Open Quartus project       | `quartus Excercise1.qpf`          |
