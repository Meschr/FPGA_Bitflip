-------------------------------------------------------------------------------
-- tb_crossbar_switch.vhd
-- Testbench for 4x4 crossbar MUX (selects driven by testbench)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tb_crossbar_switch is
end entity tb_crossbar_switch;

architecture sim of tb_crossbar_switch is

    constant STEP_TIME : TIME := 8 ns;

    -- MUX Eingänge
    signal data_m0_i0, data_m0_i1, data_m0_i2, data_m0_i3 : STD_LOGIC_VECTOR(7 downto 0);
    signal data_m1_i0, data_m1_i1, data_m1_i2, data_m1_i3 : STD_LOGIC_VECTOR(7 downto 0);
    signal data_m2_i0, data_m2_i1, data_m2_i2, data_m2_i3 : STD_LOGIC_VECTOR(7 downto 0);
    signal data_m3_i0, data_m3_i1, data_m3_i2, data_m3_i3 : STD_LOGIC_VECTOR(7 downto 0);

    -- Select
    signal sel_0, sel_1, sel_2, sel_3 : STD_LOGIC_VECTOR(1 downto 0);

    -- Ausgänge
    signal out_data_0, out_data_1, out_data_2, out_data_3 : STD_LOGIC_VECTOR(7 downto 0);

begin

    dut : entity work.crossbar_switch
        port map(
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
        data_m0_i0 <= x"00";
        data_m0_i1 <= x"01";
        data_m0_i2 <= x"02";
        data_m0_i3 <= x"03";
        data_m1_i0 <= x"10";
        data_m1_i1 <= x"11";
        data_m1_i2 <= x"12";
        data_m1_i3 <= x"13";
        data_m2_i0 <= x"20";
        data_m2_i1 <= x"21";
        data_m2_i2 <= x"22";
        data_m2_i3 <= x"23";
        data_m3_i0 <= x"30";
        data_m3_i1 <= x"31";
        data_m3_i2 <= x"32";
        data_m3_i3 <= x"33";

        sel_0 <= "00";
        sel_1 <= "00";
        sel_2 <= "00";
        sel_3 <= "00";

        -----------------------------------------------------------------------
        -- TEST 1: Straight-through (Out0?In0, Out1?In1, Out2?In2, Out3?In3)
        -----------------------------------------------------------------------
        sel_0 <= "00";
        sel_1 <= "01";
        sel_2 <= "10";
        sel_3 <= "11";
        wait for STEP_TIME;
        wait for 1 ns;

        assert out_data_0 = x"00"
        report "T1: out0 erwartet 0x00" severity error;
        assert out_data_1 = x"11"
        report "T1: out1 erwartet 0x11" severity error;
        assert out_data_2 = x"22"
        report "T1: out2 erwartet 0x22" severity error;
        assert out_data_3 = x"33"
        report "T1: out3 erwartet 0x33" severity error;
        report "TEST 1 PASSED: Straight-through";

        -----------------------------------------------------------------------
        -- TEST 2: Reverse (Out0?In3, Out1?In2, Out2?In1, Out3?In0)
        -----------------------------------------------------------------------
        sel_0 <= "11";
        sel_1 <= "10";
        sel_2 <= "01";
        sel_3 <= "00";
        wait for STEP_TIME;
        wait for 1 ns;

        assert out_data_0 = x"03"
        report "T2: out0 erwartet 0x03" severity error;
        assert out_data_1 = x"12"
        report "T2: out1 erwartet 0x12" severity error;
        assert out_data_2 = x"21"
        report "T2: out2 erwartet 0x21" severity error;
        assert out_data_3 = x"30"
        report "T2: out3 erwartet 0x30" severity error;
        report "TEST 2 PASSED: Reverse";

        -----------------------------------------------------------------------
        -- TEST 3: Broadcast (alle MUXe wählen Input 2)
        -----------------------------------------------------------------------
        sel_0 <= "10";
        sel_1 <= "10";
        sel_2 <= "10";
        sel_3 <= "10";
        wait for STEP_TIME;
        wait for 1 ns;

        assert out_data_0 = x"02"
        report "T3: out0 erwartet 0x02" severity error;
        assert out_data_1 = x"12"
        report "T3: out1 erwartet 0x12" severity error;
        assert out_data_2 = x"22"
        report "T3: out2 erwartet 0x22" severity error;
        assert out_data_3 = x"32"
        report "T3: out3 erwartet 0x32" severity error;
        report "TEST 3 PASSED: Broadcast (alle von In2)";

        -----------------------------------------------------------------------
        -- TEST 4: Dynamische Umschaltung
        -----------------------------------------------------------------------
        sel_0 <= "00";
        wait for STEP_TIME;
        wait for 1 ns;
        assert out_data_0 = x"00"
        report "T4a: out0 erwartet 0x00" severity error;

        sel_0 <= "01";
        wait for STEP_TIME;
        wait for 1 ns;
        assert out_data_0 = x"01"
        report "T4b: out0 erwartet 0x01" severity error;

        sel_0 <= "10";
        wait for STEP_TIME;
        wait for 1 ns;
        assert out_data_0 = x"02"
        report "T4c: out0 erwartet 0x02" severity error;

        sel_0 <= "11";
        wait for STEP_TIME;
        wait for 1 ns;
        assert out_data_0 = x"03"
        report "T4d: out0 erwartet 0x03" severity error;
        report "TEST 4 PASSED: Dynamische Umschaltung";

        -----------------------------------------------------------------------
        -- TEST 5: Datenänderung bei festem Select
        -----------------------------------------------------------------------
        sel_0      <= "00";
        data_m0_i0 <= x"AA";
        wait for STEP_TIME;
        wait for 1 ns;
        assert out_data_0 = x"AA"
        report "T5a: out0 erwartet 0xAA" severity error;

        data_m0_i0 <= x"FF";
        wait for STEP_TIME;
        wait for 1 ns;
        assert out_data_0 = x"FF"
        report "T5b: out0 erwartet 0xFF" severity error;
        report "TEST 5 PASSED: Datenänderung";

        -----------------------------------------------------------------------
        report "ALLE TESTS ABGESCHLOSSEN";
        wait;
    end process stim;

end architecture sim;
