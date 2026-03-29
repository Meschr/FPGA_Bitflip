-------------------------------------------------------------------------------
-- crossbar_switch.vhd
-- 4x4 Crossbar ? reiner MUX-Fabric
--
-- 4 unabhängige 4:1 MUXe, implementiert mit "with...select"
-- Select-Signale kommen von außen (Testbench / später Scheduler)
-- Registered outputs für sauberes Timing auf dem FPGA
--
-- DTU Fotonik - FPGA Design for Communications Systems
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity crossbar_switch is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;

        -- MUX 0 Eingänge (VOQ-Spalte für Destination 0)
        data_m0_i0  : in  std_logic_vector(7 downto 0);
        data_m0_i1  : in  std_logic_vector(7 downto 0);
        data_m0_i2  : in  std_logic_vector(7 downto 0);
        data_m0_i3  : in  std_logic_vector(7 downto 0);

        -- MUX 1 Eingänge (VOQ-Spalte für Destination 1)
        data_m1_i0  : in  std_logic_vector(7 downto 0);
        data_m1_i1  : in  std_logic_vector(7 downto 0);
        data_m1_i2  : in  std_logic_vector(7 downto 0);
        data_m1_i3  : in  std_logic_vector(7 downto 0);

        -- MUX 2 Eingänge (VOQ-Spalte für Destination 2)
        data_m2_i0  : in  std_logic_vector(7 downto 0);
        data_m2_i1  : in  std_logic_vector(7 downto 0);
        data_m2_i2  : in  std_logic_vector(7 downto 0);
        data_m2_i3  : in  std_logic_vector(7 downto 0);

        -- MUX 3 Eingänge (VOQ-Spalte für Destination 3)
        data_m3_i0  : in  std_logic_vector(7 downto 0);
        data_m3_i1  : in  std_logic_vector(7 downto 0);
        data_m3_i2  : in  std_logic_vector(7 downto 0);
        data_m3_i3  : in  std_logic_vector(7 downto 0);

        -- Select-Signale (2 Bit pro MUX, von außen)
        sel_0   : in  std_logic_vector(1 downto 0);
        sel_1   : in  std_logic_vector(1 downto 0);
        sel_2   : in  std_logic_vector(1 downto 0);
        sel_3   : in  std_logic_vector(1 downto 0);

        -- Ausgänge (8-bit GMII)
        out_data_0  : out std_logic_vector(7 downto 0);
        out_data_1  : out std_logic_vector(7 downto 0);
        out_data_2  : out std_logic_vector(7 downto 0);
        out_data_3  : out std_logic_vector(7 downto 0)
    );
end entity crossbar_switch;

architecture rtl of crossbar_switch is

    -- Combinational MUX outputs (vor den Registern)
    signal mux0_out : std_logic_vector(7 downto 0);
    signal mux1_out : std_logic_vector(7 downto 0);
    signal mux2_out : std_logic_vector(7 downto 0);
    signal mux3_out : std_logic_vector(7 downto 0);

begin

    ---------------------------------------------------------------------------
    -- 4× MUX mit "with...select" (concurrent, kein Process)
    ---------------------------------------------------------------------------

    -- MUX 0: wählt welcher Eingang auf Tx0 geht
    with sel_0 select
        mux0_out <= data_m0_i0 when "00",
                    data_m0_i1 when "01",
                    data_m0_i2 when "10",
                    data_m0_i3 when others;

    -- MUX 1: wählt welcher Eingang auf Tx1 geht
    with sel_1 select
        mux1_out <= data_m1_i0 when "00",
                    data_m1_i1 when "01",
                    data_m1_i2 when "10",
                    data_m1_i3 when others;

    -- MUX 2: wählt welcher Eingang auf Tx2 geht
    with sel_2 select
        mux2_out <= data_m2_i0 when "00",
                    data_m2_i1 when "01",
                    data_m2_i2 when "10",
                    data_m2_i3 when others;

    -- MUX 3: wählt welcher Eingang auf Tx3 geht
    with sel_3 select
        mux3_out <= data_m3_i0 when "00",
                    data_m3_i1 when "01",
                    data_m3_i2 when "10",
                    data_m3_i3 when others;

    ---------------------------------------------------------------------------
    -- Output-Register (1 Takt Latenz, sauberes Timing)
    ---------------------------------------------------------------------------
    reg_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                out_data_0 <= (others => '0');
                out_data_1 <= (others => '0');
                out_data_2 <= (others => '0');
                out_data_3 <= (others => '0');
            else
                out_data_0 <= mux0_out;
                out_data_1 <= mux1_out;
                out_data_2 <= mux2_out;
                out_data_3 <= mux3_out;
            end if;
        end if;
    end process reg_proc;

end architecture rtl;