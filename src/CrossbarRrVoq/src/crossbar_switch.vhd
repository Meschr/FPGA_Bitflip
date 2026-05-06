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

library ieee;
use ieee.std_logic_1164.all;

entity crossbar_switch is
    port (
        clk     : in  std_logic;  -- Systemtakt / System clock
        reset   : in  std_logic;  -- Synchroner Reset (aktiv high) [derzeit ungenutzt]
                                  -- Synchronous reset (active high) [currently unused]

        -- -----------------------------------------------------------------
        -- MUX 0 Input-Ports (VOQ-Spalte fuer Zielport 0)
        -- Alle 4 moeglichen Quellen fuer Ausgangkanal 0
        -- MUX 0 input ports (VOQ column for destination port 0)
        -- All 4 possible sources for output channel 0
        -- -----------------------------------------------------------------
        data_m0_i0  : in  std_logic_vector(7 downto 0);  -- Eingang 0 -> MUX 0 / Input 0 -> MUX 0
        data_m0_i1  : in  std_logic_vector(7 downto 0);  -- Eingang 1 -> MUX 0 / Input 1 -> MUX 0
        data_m0_i2  : in  std_logic_vector(7 downto 0);  -- Eingang 2 -> MUX 0 / Input 2 -> MUX 0
        data_m0_i3  : in  std_logic_vector(7 downto 0);  -- Eingang 3 -> MUX 0 / Input 3 -> MUX 0

        -- -----------------------------------------------------------------
        -- MUX 1 Input-Ports (VOQ-Spalte fuer Zielport 1)
        -- MUX 1 input ports (VOQ column for destination port 1)
        -- -----------------------------------------------------------------
        data_m1_i0  : in  std_logic_vector(7 downto 0);  -- Eingang 0 -> MUX 1 / Input 0 -> MUX 1
        data_m1_i1  : in  std_logic_vector(7 downto 0);  -- Eingang 1 -> MUX 1 / Input 1 -> MUX 1
        data_m1_i2  : in  std_logic_vector(7 downto 0);  -- Eingang 2 -> MUX 1 / Input 2 -> MUX 1
        data_m1_i3  : in  std_logic_vector(7 downto 0);  -- Eingang 3 -> MUX 1 / Input 3 -> MUX 1

        -- -----------------------------------------------------------------
        -- MUX 2 Input-Ports (VOQ-Spalte fuer Zielport 2)
        -- MUX 2 input ports (VOQ column for destination port 2)
        -- -----------------------------------------------------------------
        data_m2_i0  : in  std_logic_vector(7 downto 0);  -- Eingang 0 -> MUX 2 / Input 0 -> MUX 2
        data_m2_i1  : in  std_logic_vector(7 downto 0);  -- Eingang 1 -> MUX 2 / Input 1 -> MUX 2
        data_m2_i2  : in  std_logic_vector(7 downto 0);  -- Eingang 2 -> MUX 2 / Input 2 -> MUX 2
        data_m2_i3  : in  std_logic_vector(7 downto 0);  -- Eingang 3 -> MUX 2 / Input 3 -> MUX 2

        -- -----------------------------------------------------------------
        -- MUX 3 Input-Ports (VOQ-Spalte fuer Zielport 3)
        -- MUX 3 input ports (VOQ column for destination port 3)
        -- -----------------------------------------------------------------
        data_m3_i0  : in  std_logic_vector(7 downto 0);  -- Eingang 0 -> MUX 3 / Input 0 -> MUX 3
        data_m3_i1  : in  std_logic_vector(7 downto 0);  -- Eingang 1 -> MUX 3 / Input 1 -> MUX 3
        data_m3_i2  : in  std_logic_vector(7 downto 0);  -- Eingang 2 -> MUX 3 / Input 2 -> MUX 3
        data_m3_i3  : in  std_logic_vector(7 downto 0);  -- Eingang 3 -> MUX 3 / Input 3 -> MUX 3

        -- -----------------------------------------------------------------
        -- Select-Signale (steuern welcher Eingang zum Ausgangport durchgeschalten wird)
        -- sel_0, sel_1, sel_2, sel_3: Jeweils 2 Bits, waehlen Eingang 0..3
        -- Select signals (control which input is routed to the output port)
        -- sel_0..sel_3: 2 bits each, select input 0..3
        -- -----------------------------------------------------------------
        sel_0   : in  std_logic_vector(1 downto 0);  -- MUX 0 Select: waehlt Eingang fuer Output 0 / selects input for output 0
        sel_1   : in  std_logic_vector(1 downto 0);  -- MUX 1 Select: waehlt Eingang fuer Output 1 / selects input for output 1
        sel_2   : in  std_logic_vector(1 downto 0);  -- MUX 2 Select: waehlt Eingang fuer Output 2 / selects input for output 2
        sel_3   : in  std_logic_vector(1 downto 0);  -- MUX 3 Select: waehlt Eingang fuer Output 3 / selects input for output 3

        -- -----------------------------------------------------------------
        -- Output-Ports (8-Bit Datenwort pro Zielport)
        -- Output ports (8-bit data word per destination port)
        -- -----------------------------------------------------------------
        out_data_0  : out std_logic_vector(7 downto 0);  -- Ausgang Zielport 0 / Output destination port 0
        out_data_1  : out std_logic_vector(7 downto 0);  -- Ausgang Zielport 1 / Output destination port 1
        out_data_2  : out std_logic_vector(7 downto 0);  -- Ausgang Zielport 2 / Output destination port 2
        out_data_3  : out std_logic_vector(7 downto 0)   -- Ausgang Zielport 3 / Output destination port 3
    );
end entity crossbar_switch;

architecture rtl of crossbar_switch is

    -- Interne Signale fuer die MUX-Ausgaenge (vor eventueller Registrierung)
    -- Internal signals for the MUX outputs (before optional output registration)
    signal mux0_out : std_logic_vector(7 downto 0);
    signal mux1_out : std_logic_vector(7 downto 0);
    signal mux2_out : std_logic_vector(7 downto 0);
    signal mux3_out : std_logic_vector(7 downto 0);

begin

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
    with sel_0 select
        mux0_out <= data_m0_i0 when "00",  -- sel_0="00": durchschalten data_m0_i0 / forward data_m0_i0
                    data_m0_i1 when "01",  -- sel_0="01": durchschalten data_m0_i1 / forward data_m0_i1
                    data_m0_i2 when "10",  -- sel_0="10": durchschalten data_m0_i2 / forward data_m0_i2
                    data_m0_i3 when others;  -- sel_0="11": durchschalten data_m0_i3 / forward data_m0_i3

    -- MUX 1: Waehlt einen der vier Eingaenge unter Kontrolle von sel_1
    -- MUX 1: Selects one of the four inputs controlled by sel_1
    with sel_1 select
        mux1_out <= data_m1_i0 when "00",
                    data_m1_i1 when "01",
                    data_m1_i2 when "10",
                    data_m1_i3 when others;

    -- MUX 2: Waehlt einen der vier Eingaenge unter Kontrolle von sel_2
    -- MUX 2: Selects one of the four inputs controlled by sel_2
    with sel_2 select
        mux2_out <= data_m2_i0 when "00",
                    data_m2_i1 when "01",
                    data_m2_i2 when "10",
                    data_m2_i3 when others;

    -- MUX 3: Waehlt einen der vier Eingaenge unter Kontrolle von sel_3
    -- MUX 3: Selects one of the four inputs controlled by sel_3
    with sel_3 select
        mux3_out <= data_m3_i0 when "00",
                    data_m3_i1 when "01",
                    data_m3_i2 when "10",
                    data_m3_i3 when others;

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

end architecture rtl;
