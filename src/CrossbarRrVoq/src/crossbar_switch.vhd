-- =============================================================================
-- Modul: crossbar_switch
-- Module: crossbar_switch
--
-- Beschreibung:
--   4x4 Crossbar-Switch mit Pure-MUX-Architektur.
--   Vier unabhaengige 4:1 Multiplexer (einer pro Ausgangsport).
--   Jeder MUX waehlt seinen Eingang ueber ein 2-Bit Select-Signal.
--
-- Description:
--   4x4 crossbar switch using a pure-MUX architecture.
--   Four independent 4:1 multiplexers (one per output port).
--   Each MUX selects its input via a 2-bit select signal.
--
--   Topologie (als Beispiel) / Topology (example):
--     Input 0 ----+
--     Input 1 ----+--> MUX 0 --> Output 0 (unter Kontrolle von sel_0 / controlled by sel_0)
--     Input 2 ----+
--     Input 3 ----+
--
--   Implementierung: "with...select" concurrent statements (kein sequentieller Code)
--   Implementation:  "with...select" concurrent statements (no sequential code)
--
--   Timing: Kombinatorisch, keine Register in den MUXen selbst
--   Timing: Combinational, no registers inside the MUXes themselves
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY crossbar_switch IS
    PORT (
        clk : IN STD_LOGIC; -- Systemtakt / System clock
        reset : IN STD_LOGIC; -- Synchroner Reset (aktiv high) [derzeit ungenutzt]
        -- Synchronous reset (active high) [currently unused]

        -- -----------------------------------------------------------------
        -- MUX 0 Input-Ports (VOQ-Spalte fuer Zielport 0)
        -- Alle 4 moeglichen Quellen fuer Ausgangkanal 0
        -- MUX 0 input ports (VOQ column for destination port 0)
        -- All 4 possible sources for output channel 0
        -- -----------------------------------------------------------------
        data_m0_i0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 0 -> MUX 0 / Input 0 -> MUX 0
        data_m0_i1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 1 -> MUX 0 / Input 1 -> MUX 0
        data_m0_i2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 2 -> MUX 0 / Input 2 -> MUX 0
        data_m0_i3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 3 -> MUX 0 / Input 3 -> MUX 0

        -- -----------------------------------------------------------------
        -- MUX 1 Input-Ports (VOQ-Spalte fuer Zielport 1)
        -- MUX 1 input ports (VOQ column for destination port 1)
        -- -----------------------------------------------------------------
        data_m1_i0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 0 -> MUX 1 / Input 0 -> MUX 1
        data_m1_i1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 1 -> MUX 1 / Input 1 -> MUX 1
        data_m1_i2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 2 -> MUX 1 / Input 2 -> MUX 1
        data_m1_i3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 3 -> MUX 1 / Input 3 -> MUX 1

        -- -----------------------------------------------------------------
        -- MUX 2 Input-Ports (VOQ-Spalte fuer Zielport 2)
        -- MUX 2 input ports (VOQ column for destination port 2)
        -- -----------------------------------------------------------------
        data_m2_i0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 0 -> MUX 2 / Input 0 -> MUX 2
        data_m2_i1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 1 -> MUX 2 / Input 1 -> MUX 2
        data_m2_i2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 2 -> MUX 2 / Input 2 -> MUX 2
        data_m2_i3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 3 -> MUX 2 / Input 3 -> MUX 2

        -- -----------------------------------------------------------------
        -- MUX 3 Input-Ports (VOQ-Spalte fuer Zielport 3)
        -- MUX 3 input ports (VOQ column for destination port 3)
        -- -----------------------------------------------------------------
        data_m3_i0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 0 -> MUX 3 / Input 0 -> MUX 3
        data_m3_i1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 1 -> MUX 3 / Input 1 -> MUX 3
        data_m3_i2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 2 -> MUX 3 / Input 2 -> MUX 3
        data_m3_i3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Eingang 3 -> MUX 3 / Input 3 -> MUX 3

        -- -----------------------------------------------------------------
        -- Select-Signale (steuern welcher Eingang zum Ausgangport durchgeschalten wird)
        -- sel_0, sel_1, sel_2, sel_3: Jeweils 2 Bits, waehlen Eingang 0..3
        -- Select signals (control which input is routed to the output port)
        -- sel_0..sel_3: 2 bits each, select input 0..3
        -- -----------------------------------------------------------------
        sel_0 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- MUX 0 Select: waehlt Eingang fuer Output 0 / selects input for output 0
        sel_1 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- MUX 1 Select: waehlt Eingang fuer Output 1 / selects input for output 1
        sel_2 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- MUX 2 Select: waehlt Eingang fuer Output 2 / selects input for output 2
        sel_3 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- MUX 3 Select: waehlt Eingang fuer Output 3 / selects input for output 3

        -- -----------------------------------------------------------------
        -- Output-Ports (8-Bit Datenwort pro Zielport)
        -- Output ports (8-bit data word per destination port)
        -- -----------------------------------------------------------------
        out_data_0 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Ausgang Zielport 0 / Output destination port 0
        out_data_1 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Ausgang Zielport 1 / Output destination port 1
        out_data_2 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Ausgang Zielport 2 / Output destination port 2
        out_data_3 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) -- Ausgang Zielport 3 / Output destination port 3
    );
END ENTITY crossbar_switch;

ARCHITECTURE rtl OF crossbar_switch IS

    -- Interne Signale fuer die MUX-Ausgaenge (vor eventueller Registrierung)
    -- Internal signals for the MUX outputs (before optional output registration)
    SIGNAL mux0_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mux1_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mux2_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mux3_out : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    ---------------------------------------------------------------------------
    -- Vier 4:1 Multiplexer mit "with...select"-Konstrukt
    -- Four 4:1 multiplexers using the "with...select" construct
    --
    -- Diese sind rein kombinatorisch (kein Takt) und werden in Hardware als
    -- MUX-Fabric der FPGA-Slice implementiert.
    -- These are purely combinational (no clock) and are implemented in hardware
    -- as MUX fabric within FPGA slices.
    ---------------------------------------------------------------------------

    -- MUX 0: Waehlt einen der vier Eingaenge unter Kontrolle von sel_0
    -- MUX 0: Selects one of the four inputs controlled by sel_0
    WITH sel_0 SELECT
        mux0_out <= data_m0_i0 WHEN "00", -- sel_0="00": durchschalten data_m0_i0 / forward data_m0_i0
        data_m0_i1 WHEN "01", -- sel_0="01": durchschalten data_m0_i1 / forward data_m0_i1
        data_m0_i2 WHEN "10", -- sel_0="10": durchschalten data_m0_i2 / forward data_m0_i2
        data_m0_i3 WHEN OTHERS; -- sel_0="11": durchschalten data_m0_i3 / forward data_m0_i3

    -- MUX 1: Waehlt einen der vier Eingaenge unter Kontrolle von sel_1
    -- MUX 1: Selects one of the four inputs controlled by sel_1
    WITH sel_1 SELECT
        mux1_out <= data_m1_i0 WHEN "00",
        data_m1_i1 WHEN "01",
        data_m1_i2 WHEN "10",
        data_m1_i3 WHEN OTHERS;

    -- MUX 2: Waehlt einen der vier Eingaenge unter Kontrolle von sel_2
    -- MUX 2: Selects one of the four inputs controlled by sel_2
    WITH sel_2 SELECT
        mux2_out <= data_m2_i0 WHEN "00",
        data_m2_i1 WHEN "01",
        data_m2_i2 WHEN "10",
        data_m2_i3 WHEN OTHERS;

    -- MUX 3: Waehlt einen der vier Eingaenge unter Kontrolle von sel_3
    -- MUX 3: Selects one of the four inputs controlled by sel_3
    WITH sel_3 SELECT
        mux3_out <= data_m3_i0 WHEN "00",
        data_m3_i1 WHEN "01",
        data_m3_i2 WHEN "10",
        data_m3_i3 WHEN OTHERS;

    ---------------------------------------------------------------------------
    -- Output-Verbindung (kombinatorisch)
    -- Output connection (combinational)
    --
    -- Die MUX-Ausgaenge werden direkt auf die Aunsgangsports durchgereicht.
    -- The MUX outputs are passed directly to the output ports.
    -- (Ggf. koennte hier eine Registrierung (seq. Logic) eingefuegt werden
    -- fuer besseres Timing in großen Designs)
    -- (Optionally, output registers could be inserted here for better
    -- timing closure in larger designs)
    ---------------------------------------------------------------------------

    out_data_0 <= mux0_out;
    out_data_1 <= mux1_out;
    out_data_2 <= mux2_out;
    out_data_3 <= mux3_out;

END ARCHITECTURE rtl;