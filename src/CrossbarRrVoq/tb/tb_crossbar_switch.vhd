-------------------------------------------------------------------------------
-- tb_crossbar_switch.vhd
-- Testbench für 4x4 Crossbar-MUX (Select von Testbench)
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY tb_crossbar_switch IS
END ENTITY tb_crossbar_switch;

ARCHITECTURE sim OF tb_crossbar_switch IS

    CONSTANT CLK_PERIOD : TIME := 8 ns;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';

    -- MUX Eingänge
    SIGNAL data_m0_i0, data_m0_i1, data_m0_i2, data_m0_i3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data_m1_i0, data_m1_i1, data_m1_i2, data_m1_i3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data_m2_i0, data_m2_i1, data_m2_i2, data_m2_i3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data_m3_i0, data_m3_i1, data_m3_i2, data_m3_i3 : STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- Select
    SIGNAL sel_0, sel_1, sel_2, sel_3 : STD_LOGIC_VECTOR(1 DOWNTO 0);

    -- Ausgänge
    SIGNAL out_data_0, out_data_1, out_data_2, out_data_3 : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    dut : ENTITY work.crossbar_switch
        PORT MAP(
            clk => clk, reset => reset,
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

    stim : PROCESS
    BEGIN
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
        -- TEST 1: Reset
        -----------------------------------------------------------------------
        reset <= '1';
        WAIT FOR CLK_PERIOD * 3;
        reset <= '0';
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT out_data_0 = x"00"
        REPORT "T1 FAIL: nach Reset nicht Null" SEVERITY error;
        REPORT "TEST 1 PASSED: Reset";

        -----------------------------------------------------------------------
        -- TEST 2: Straight-through (Out0?In0, Out1?In1, Out2?In2, Out3?In3)
        -----------------------------------------------------------------------
        sel_0 <= "00";
        sel_1 <= "01";
        sel_2 <= "10";
        sel_3 <= "11";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT out_data_0 = x"00"
        REPORT "T2: out0 erwartet 0x00" SEVERITY error;
        ASSERT out_data_1 = x"11"
        REPORT "T2: out1 erwartet 0x11" SEVERITY error;
        ASSERT out_data_2 = x"22"
        REPORT "T2: out2 erwartet 0x22" SEVERITY error;
        ASSERT out_data_3 = x"33"
        REPORT "T2: out3 erwartet 0x33" SEVERITY error;
        REPORT "TEST 2 PASSED: Straight-through";

        -----------------------------------------------------------------------
        -- TEST 3: Reverse (Out0?In3, Out1?In2, Out2?In1, Out3?In0)
        -----------------------------------------------------------------------
        sel_0 <= "11";
        sel_1 <= "10";
        sel_2 <= "01";
        sel_3 <= "00";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT out_data_0 = x"03"
        REPORT "T3: out0 erwartet 0x03" SEVERITY error;
        ASSERT out_data_1 = x"12"
        REPORT "T3: out1 erwartet 0x12" SEVERITY error;
        ASSERT out_data_2 = x"21"
        REPORT "T3: out2 erwartet 0x21" SEVERITY error;
        ASSERT out_data_3 = x"30"
        REPORT "T3: out3 erwartet 0x30" SEVERITY error;
        REPORT "TEST 3 PASSED: Reverse";

        -----------------------------------------------------------------------
        -- TEST 4: Broadcast (alle MUXe wählen Input 2)
        -----------------------------------------------------------------------
        sel_0 <= "10";
        sel_1 <= "10";
        sel_2 <= "10";
        sel_3 <= "10";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT out_data_0 = x"02"
        REPORT "T4: out0 erwartet 0x02" SEVERITY error;
        ASSERT out_data_1 = x"12"
        REPORT "T4: out1 erwartet 0x12" SEVERITY error;
        ASSERT out_data_2 = x"22"
        REPORT "T4: out2 erwartet 0x22" SEVERITY error;
        ASSERT out_data_3 = x"32"
        REPORT "T4: out3 erwartet 0x32" SEVERITY error;
        REPORT "TEST 4 PASSED: Broadcast (alle von In2)";

        -----------------------------------------------------------------------
        -- TEST 5: Dynamische Umschaltung
        -----------------------------------------------------------------------
        sel_0 <= "00";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT out_data_0 = x"00"
        REPORT "T5a: out0 erwartet 0x00" SEVERITY error;

        sel_0 <= "01";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT out_data_0 = x"01"
        REPORT "T5b: out0 erwartet 0x01" SEVERITY error;

        sel_0 <= "10";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT out_data_0 = x"02"
        REPORT "T5c: out0 erwartet 0x02" SEVERITY error;

        sel_0 <= "11";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT out_data_0 = x"03"
        REPORT "T5d: out0 erwartet 0x03" SEVERITY error;
        REPORT "TEST 5 PASSED: Dynamische Umschaltung";

        -----------------------------------------------------------------------
        -- TEST 6: Datenänderung bei festem Select
        -----------------------------------------------------------------------
        sel_0 <= "00";
        data_m0_i0 <= x"AA";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT out_data_0 = x"AA"
        REPORT "T6a: out0 erwartet 0xAA" SEVERITY error;

        data_m0_i0 <= x"FF";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT out_data_0 = x"FF"
        REPORT "T6b: out0 erwartet 0xFF" SEVERITY error;
        REPORT "TEST 6 PASSED: Datenänderung";

        -----------------------------------------------------------------------
        REPORT "ALLE TESTS ABGESCHLOSSEN";
        WAIT;
    END PROCESS stim;

END ARCHITECTURE sim;