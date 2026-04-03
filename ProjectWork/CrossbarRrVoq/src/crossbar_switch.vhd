-- =============================================================================
-- Modul: crossbar_switch
-- Beschreibung:
--   4x4 Crossbar-Switch mit Pure-MUX-Architektur.
--   Vier unabhaengige 4:1 Multiplexer (einer pro Ausgangsport).
--   Jeder MUX waehlt seinen Eingang ueber ein 2-Bit Select-Signal.
--
--   Topologie (als Beispiel):
--     Input 0 ----+
--     Input 1 ----+--> MUX 0 --> Output 0 (unter Kontrolle von sel_0)
--     Input 2 ----+
--     Input 3 ----+
--
--   Implementierung: "with...select" concurrent statements (kein sequentieller Code)
--   Timing: Kombinatorisch, keine Register in den MUXen selbst
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity crossbar_switch is
    port (
        clk     : in  std_logic;  -- Systemtakt
        reset   : in  std_logic;  -- Synchroner Reset (aktiv high) [derzeit ungenutzt]

        -- -----------------------------------------------------------------
        -- MUX 0 Input-Ports (VOQ-Spalte fuer Zielport 0)
        -- Alle 4 moeglichen Quellen fuer Ausgangkanal 0
        -- -----------------------------------------------------------------
        data_m0_i0  : in  std_logic_vector(7 downto 0);  -- Eingang 0 -> MUX 0
        data_m0_i1  : in  std_logic_vector(7 downto 0);  -- Eingang 1 -> MUX 0
        data_m0_i2  : in  std_logic_vector(7 downto 0);  -- Eingang 2 -> MUX 0
        data_m0_i3  : in  std_logic_vector(7 downto 0);  -- Eingang 3 -> MUX 0

        -- -----------------------------------------------------------------
        -- MUX 1 Input-Ports (VOQ-Spalte fuer Zielport 1)
        -- -----------------------------------------------------------------
        data_m1_i0  : in  std_logic_vector(7 downto 0);  -- Eingang 0 -> MUX 1
        data_m1_i1  : in  std_logic_vector(7 downto 0);  -- Eingang 1 -> MUX 1
        data_m1_i2  : in  std_logic_vector(7 downto 0);  -- Eingang 2 -> MUX 1
        data_m1_i3  : in  std_logic_vector(7 downto 0);  -- Eingang 3 -> MUX 1

        -- -----------------------------------------------------------------
        -- MUX 2 Input-Ports (VOQ-Spalte fuer Zielport 2)
        -- -----------------------------------------------------------------
        data_m2_i0  : in  std_logic_vector(7 downto 0);  -- Eingang 0 -> MUX 2
        data_m2_i1  : in  std_logic_vector(7 downto 0);  -- Eingang 1 -> MUX 2
        data_m2_i2  : in  std_logic_vector(7 downto 0);  -- Eingang 2 -> MUX 2
        data_m2_i3  : in  std_logic_vector(7 downto 0);  -- Eingang 3 -> MUX 2

        -- -----------------------------------------------------------------
        -- MUX 3 Input-Ports (VOQ-Spalte fuer Zielport 3)
        -- -----------------------------------------------------------------
        data_m3_i0  : in  std_logic_vector(7 downto 0);  -- Eingang 0 -> MUX 3
        data_m3_i1  : in  std_logic_vector(7 downto 0);  -- Eingang 1 -> MUX 3
        data_m3_i2  : in  std_logic_vector(7 downto 0);  -- Eingang 2 -> MUX 3
        data_m3_i3  : in  std_logic_vector(7 downto 0);  -- Eingang 3 -> MUX 3

        -- -----------------------------------------------------------------
        -- Select-Signale (steuern welcher Eingang zum Ausgangport durchgeschalten wird)
        -- sel_0, sel_1, sel_2, sel_3: Jeweils 2 Bits, waehlen Eingang 0..3
        -- -----------------------------------------------------------------
        sel_0   : in  std_logic_vector(1 downto 0);  -- MUX 0 Select: waehlt Eingang fuer Output 0
        sel_1   : in  std_logic_vector(1 downto 0);  -- MUX 1 Select: waehlt Eingang fuer Output 1
        sel_2   : in  std_logic_vector(1 downto 0);  -- MUX 2 Select: waehlt Eingang fuer Output 2
        sel_3   : in  std_logic_vector(1 downto 0);  -- MUX 3 Select: waehlt Eingang fuer Output 3

        -- -----------------------------------------------------------------
        -- Output-Ports (8-Bit Datenwort pro Zielport)
        -- -----------------------------------------------------------------
        out_data_0  : out std_logic_vector(7 downto 0);  -- Ausgang Zielport 0
        out_data_1  : out std_logic_vector(7 downto 0);  -- Ausgang Zielport 1
        out_data_2  : out std_logic_vector(7 downto 0);  -- Ausgang Zielport 2
        out_data_3  : out std_logic_vector(7 downto 0)   -- Ausgang Zielport 3
    );
end entity crossbar_switch;

architecture rtl of crossbar_switch is

    -- Interne Signale fuer die MUX-Ausgaenge (vor eventueller Registrierung)
    signal mux0_out : std_logic_vector(7 downto 0);
    signal mux1_out : std_logic_vector(7 downto 0);
    signal mux2_out : std_logic_vector(7 downto 0);
    signal mux3_out : std_logic_vector(7 downto 0);

begin

    ---------------------------------------------------------------------------
    -- Vier 4:1 Multiplexer mit "with...select"-Konstrukt
    -- Diese sind rein kombinatorisch (kein Takt) und werden in Hardware als
    -- MUX-Fabric der FPGA-Slice implementiert.
    ---------------------------------------------------------------------------

    -- MUX 0: Waehlt einen der vier Eingaenge unter Kontrolle von sel_0
    with sel_0 select
        mux0_out <= data_m0_i0 when "00",  -- sel_0="00": durchschalten data_m0_i0
                    data_m0_i1 when "01",  -- sel_0="01": durchschalten data_m0_i1
                    data_m0_i2 when "10",  -- sel_0="10": durchschalten data_m0_i2
                    data_m0_i3 when others;  -- sel_0="11": durchschalten data_m0_i3

    -- MUX 1: Waehlt einen der vier Eingaenge unter Kontrolle von sel_1
    with sel_1 select
        mux1_out <= data_m1_i0 when "00",
                    data_m1_i1 when "01",
                    data_m1_i2 when "10",
                    data_m1_i3 when others;

    -- MUX 2: Waehlt einen der vier Eingaenge unter Kontrolle von sel_2
    with sel_2 select
        mux2_out <= data_m2_i0 when "00",
                    data_m2_i1 when "01",
                    data_m2_i2 when "10",
                    data_m2_i3 when others;

    -- MUX 3: Waehlt einen der vier Eingaenge unter Kontrolle von sel_3
    with sel_3 select
        mux3_out <= data_m3_i0 when "00",
                    data_m3_i1 when "01",
                    data_m3_i2 when "10",
                    data_m3_i3 when others;

    ---------------------------------------------------------------------------
    -- Output-Verbindung (kombinatorisch)
    -- Die MUX-Ausgaenge werden direkt auf die Aunsgangsports durchgereicht.
    -- (Ggf. koennte hier eine Registrierung (seq. Logic) eingefuegt werden
    -- fuer besseres Timing in großen Designs)
    ---------------------------------------------------------------------------

    out_data_0 <= mux0_out;
    out_data_1 <= mux1_out;
    out_data_2 <= mux2_out;
    out_data_3 <= mux3_out;

end architecture rtl;
