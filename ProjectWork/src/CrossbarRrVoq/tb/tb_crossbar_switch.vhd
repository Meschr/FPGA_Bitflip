-------------------------------------------------------------------------------
-- tb_crossbar_switch.vhd
-- Testbench für 4x4 Crossbar-MUX (Select von Testbench)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tb_crossbar_switch is
end entity tb_crossbar_switch;

architecture sim of tb_crossbar_switch is

    constant CLK_PERIOD : time := 8 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- MUX Eingänge
    signal data_m0_i0, data_m0_i1, data_m0_i2, data_m0_i3 : std_logic_vector(7 downto 0);
    signal data_m1_i0, data_m1_i1, data_m1_i2, data_m1_i3 : std_logic_vector(7 downto 0);
    signal data_m2_i0, data_m2_i1, data_m2_i2, data_m2_i3 : std_logic_vector(7 downto 0);
    signal data_m3_i0, data_m3_i1, data_m3_i2, data_m3_i3 : std_logic_vector(7 downto 0);

    -- Select
    signal sel_0, sel_1, sel_2, sel_3 : std_logic_vector(1 downto 0);

    -- Ausgänge
    signal out_data_0, out_data_1, out_data_2, out_data_3 : std_logic_vector(7 downto 0);

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.crossbar_switch
        port map (
            clk   => clk,   reset => reset,
            data_m0_i0 => data_m0_i0, data_m0_i1 => data_m0_i1,
            data_m0_i2 => data_m0_i2, data_m0_i3 => data_m0_i3,
            data_m1_i0 => data_m1_i0, data_m1_i1 => data_m1_i1,
            data_m1_i2 => data_m1_i2, data_m1_i3 => data_m1_i3,
            data_m2_i0 => data_m2_i0, data_m2_i1 => data_m2_i1,
            data_m2_i2 => data_m2_i2, data_m2_i3 => data_m2_i3,
            data_m3_i0 => data_m3_i0, data_m3_i1 => data_m3_i1,
            data_m3_i2 => data_m3_i2, data_m3_i3 => data_m3_i3,
            sel_0 => sel_0, sel_1 => sel_1,
            sel_2 => sel_2, sel_3 => sel_3,
            out_data_0 => out_data_0, out_data_1 => out_data_1,
            out_data_2 => out_data_2, out_data_3 => out_data_3
        );

    stim : process
    begin
        -- Daten: 0xMI (M = MUX/Dest, I = Input/Source)
        data_m0_i0 <= x"00"; data_m0_i1 <= x"01";
        data_m0_i2 <= x"02"; data_m0_i3 <= x"03";
        data_m1_i0 <= x"10"; data_m1_i1 <= x"11";
        data_m1_i2 <= x"12"; data_m1_i3 <= x"13";
        data_m2_i0 <= x"20"; data_m2_i1 <= x"21";
        data_m2_i2 <= x"22"; data_m2_i3 <= x"23";
        data_m3_i0 <= x"30"; data_m3_i1 <= x"31";
        data_m3_i2 <= x"32"; data_m3_i3 <= x"33";

        sel_0 <= "00"; sel_1 <= "00"; sel_2 <= "00"; sel_3 <= "00";

        -----------------------------------------------------------------------
        -- TEST 1: Reset
        -----------------------------------------------------------------------
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert out_data_0 = x"00"
            report "T1 FAIL: nach Reset nicht Null" severity error;
        report "TEST 1 PASSED: Reset";

        -----------------------------------------------------------------------
        -- TEST 2: Straight-through (Out0?In0, Out1?In1, Out2?In2, Out3?In3)
        -----------------------------------------------------------------------
        sel_0 <= "00"; sel_1 <= "01"; sel_2 <= "10"; sel_3 <= "11";
        wait for CLK_PERIOD; wait for 1 ns;

        assert out_data_0 = x"00"
            report "T2: out0 erwartet 0x00" severity error;
        assert out_data_1 = x"11"
            report "T2: out1 erwartet 0x11" severity error;
        assert out_data_2 = x"22"
            report "T2: out2 erwartet 0x22" severity error;
        assert out_data_3 = x"33"
            report "T2: out3 erwartet 0x33" severity error;
        report "TEST 2 PASSED: Straight-through";

        -----------------------------------------------------------------------
        -- TEST 3: Reverse (Out0?In3, Out1?In2, Out2?In1, Out3?In0)
        -----------------------------------------------------------------------
        sel_0 <= "11"; sel_1 <= "10"; sel_2 <= "01"; sel_3 <= "00";
        wait for CLK_PERIOD; wait for 1 ns;

        assert out_data_0 = x"03"
            report "T3: out0 erwartet 0x03" severity error;
        assert out_data_1 = x"12"
            report "T3: out1 erwartet 0x12" severity error;
        assert out_data_2 = x"21"
            report "T3: out2 erwartet 0x21" severity error;
        assert out_data_3 = x"30"
            report "T3: out3 erwartet 0x30" severity error;
        report "TEST 3 PASSED: Reverse";

        -----------------------------------------------------------------------
        -- TEST 4: Broadcast (alle MUXe wählen Input 2)
        -----------------------------------------------------------------------
        sel_0 <= "10"; sel_1 <= "10"; sel_2 <= "10"; sel_3 <= "10";
        wait for CLK_PERIOD; wait for 1 ns;

        assert out_data_0 = x"02"
            report "T4: out0 erwartet 0x02" severity error;
        assert out_data_1 = x"12"
            report "T4: out1 erwartet 0x12" severity error;
        assert out_data_2 = x"22"
            report "T4: out2 erwartet 0x22" severity error;
        assert out_data_3 = x"32"
            report "T4: out3 erwartet 0x32" severity error;
        report "TEST 4 PASSED: Broadcast (alle von In2)";

        -----------------------------------------------------------------------
        -- TEST 5: Dynamische Umschaltung
        -----------------------------------------------------------------------
        sel_0 <= "00";
        wait for CLK_PERIOD; wait for 1 ns;
        assert out_data_0 = x"00"
            report "T5a: out0 erwartet 0x00" severity error;

        sel_0 <= "01";
        wait for CLK_PERIOD; wait for 1 ns;
        assert out_data_0 = x"01"
            report "T5b: out0 erwartet 0x01" severity error;

        sel_0 <= "10";
        wait for CLK_PERIOD; wait for 1 ns;
        assert out_data_0 = x"02"
            report "T5c: out0 erwartet 0x02" severity error;

        sel_0 <= "11";
        wait for CLK_PERIOD; wait for 1 ns;
        assert out_data_0 = x"03"
            report "T5d: out0 erwartet 0x03" severity error;
        report "TEST 5 PASSED: Dynamische Umschaltung";

        -----------------------------------------------------------------------
        -- TEST 6: Datenänderung bei festem Select
        -----------------------------------------------------------------------
        sel_0 <= "00";
        data_m0_i0 <= x"AA";
        wait for CLK_PERIOD; wait for 1 ns;
        assert out_data_0 = x"AA"
            report "T6a: out0 erwartet 0xAA" severity error;

        data_m0_i0 <= x"FF";
        wait for CLK_PERIOD; wait for 1 ns;
        assert out_data_0 = x"FF"
            report "T6b: out0 erwartet 0xFF" severity error;
        report "TEST 6 PASSED: Datenänderung";

        -----------------------------------------------------------------------
        report "ALLE TESTS ABGESCHLOSSEN";
        wait;
    end process stim;

end architecture sim;