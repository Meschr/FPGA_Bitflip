-------------------------------------------------------------------------------
-- tb_switch_core.vhd
-- Testbench für das Top-Level switch_core
--
-- Testfälle:
--   1) Reset / Idle
--   2) Einzelner Frame auf Out0
--   3) Multiple Quellen auf Out0 (Round-Robin)
--   4) Multicast eines Frames auf Out0 und Out1
--   5) Reset während Betrieb
--   6) Unabhängige Frames auf allen Ausgängen
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

entity tb_switch_core is
end entity tb_switch_core;

architecture sim of tb_switch_core is

    constant CLK_PERIOD : time := 10 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- Schreibseite der VOQ-Matrix
    signal wr_data_in0 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in0  : std_logic := '0';
    signal wr_en_in0   : std_logic_vector(3 downto 0) := (others => '0');

    signal wr_data_in1 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in1  : std_logic := '0';
    signal wr_en_in1   : std_logic_vector(3 downto 0) := (others => '0');

    signal wr_data_in2 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in2  : std_logic := '0';
    signal wr_en_in2   : std_logic_vector(3 downto 0) := (others => '0');

    signal wr_data_in3 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in3  : std_logic := '0';
    signal wr_en_in3   : std_logic_vector(3 downto 0) := (others => '0');

    -- Backpressure
    signal full_in0 : std_logic_vector(3 downto 0);
    signal full_in1 : std_logic_vector(3 downto 0);
    signal full_in2 : std_logic_vector(3 downto 0);
    signal full_in3 : std_logic_vector(3 downto 0);

    -- Ausgänge
    signal out_data_0 : std_logic_vector(7 downto 0);
    signal out_data_1 : std_logic_vector(7 downto 0);
    signal out_data_2 : std_logic_vector(7 downto 0);
    signal out_data_3 : std_logic_vector(7 downto 0);

    ---------------------------------------------------------------------------
    -- Hilfsprozeduren
    ---------------------------------------------------------------------------
    procedure wait_cycles(n : natural) is
    begin
        for i in 1 to n loop
            wait until rising_edge(clk);
        end loop;
    end procedure wait_cycles;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.switch_core
        port map (
            clk         => clk,
            reset       => reset,

            wr_data_in0 => wr_data_in0,
            wr_eof_in0  => wr_eof_in0,
            wr_en_in0   => wr_en_in0,

            wr_data_in1 => wr_data_in1,
            wr_eof_in1  => wr_eof_in1,
            wr_en_in1   => wr_en_in1,

            wr_data_in2 => wr_data_in2,
            wr_eof_in2  => wr_eof_in2,
            wr_en_in2   => wr_en_in2,

            wr_data_in3 => wr_data_in3,
            wr_eof_in3  => wr_eof_in3,
            wr_en_in3   => wr_en_in3,

            full_in0    => full_in0,
            full_in1    => full_in1,
            full_in2    => full_in2,
            full_in3    => full_in3,

            out_data_0  => out_data_0,
            out_data_1  => out_data_1,
            out_data_2  => out_data_2,
            out_data_3  => out_data_3
        );

    debug : process
    begin
        wait until rising_edge(clk);
        if now >= 100 ns and now <= 350 ns then
            report "DBG @ " & time'image(now) &
                   " out0=" & to_hstring(out_data_0) &
                   " out1=" & to_hstring(out_data_1) &
                   " out2=" & to_hstring(out_data_2) &
                   " out3=" & to_hstring(out_data_3)
                severity note;
        end if;
    end process debug;

    stim : process
        variable got10 : boolean := false;
        variable got11 : boolean := false;
        variable got12 : boolean := false;
        variable got13 : boolean := false;
        variable gotDE : boolean := false;
        variable gotAD : boolean := false;
        variable gotA0 : boolean := false;
        variable gotB1 : boolean := false;
        variable gotC2 : boolean := false;
        variable gotD3 : boolean := false;
    begin

        -------------------------------------------------------------------
        -- TEST 1: Reset und Idle
        -------------------------------------------------------------------
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');
        reset <= '1';
        wait_cycles(3);

        reset <= '0';
        wait_cycles(2);

        assert full_in0 = "0000" and full_in1 = "0000" and
               full_in2 = "0000" and full_in3 = "0000"
            report "T1 FAIL: full-Signale müssen 0 sein nach Reset" severity error;

        report "TEST 1 PASSED: Reset und Idle";

        -------------------------------------------------------------------
        -- TEST 2: Einzelner Frame auf Out0
        -------------------------------------------------------------------
        wr_data_in0 <= x"AA"; wr_eof_in0 <= '0'; wr_en_in0 <= "0001";
        wait_cycles(1);
        wr_data_in0 <= x"BB"; wr_eof_in0 <= '1'; wr_en_in0 <= "0001";
        wait_cycles(1);
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');

        wait_cycles(4);

        assert out_data_0 = x"AA"
            report "T2 FAIL: erstes Byte auf Out0 falsch, got " &
                   integer'image(to_integer(unsigned(out_data_0))) severity error;

        wait_cycles(1);

        assert out_data_0 = x"BB"
            report "T2 FAIL: zweites Byte auf Out0 falsch, got " &
                   integer'image(to_integer(unsigned(out_data_0))) severity error;

        report "TEST 2 PASSED: Einzelner Frame auf Out0";

        reset <= '1';
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');
        wait_cycles(3);

        reset <= '0';
        wait_cycles(2);

        -------------------------------------------------------------------
        -- TEST 3: Mehrere Quellen auf Out0 (Round-Robin)
        -------------------------------------------------------------------
        wr_data_in0 <= x"10"; wr_eof_in0 <= '1'; wr_en_in0 <= "0001";
        wr_data_in1 <= x"11"; wr_eof_in1 <= '1'; wr_en_in1 <= "0001";
        wr_data_in2 <= x"12"; wr_eof_in2 <= '1'; wr_en_in2 <= "0001";
        wr_data_in3 <= x"13"; wr_eof_in3 <= '1'; wr_en_in3 <= "0001";
        wait_cycles(1);
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');

        wait_cycles(4);
        got10 := false;
        got11 := false;
        got12 := false;
        got13 := false;

        if out_data_0 = x"10" then got10 := true; end if;
        if out_data_0 = x"11" then got11 := true; end if;
        if out_data_0 = x"12" then got12 := true; end if;
        if out_data_0 = x"13" then got13 := true; end if;

        for i in 0 to 19 loop
            wait until rising_edge(clk);
            if out_data_0 = x"10" then got10 := true; end if;
            if out_data_0 = x"11" then got11 := true; end if;
            if out_data_0 = x"12" then got12 := true; end if;
            if out_data_0 = x"13" then got13 := true; end if;
        end loop;

        assert got10 and got11 and got12 and got13
            report "T3 FAIL: Round-Robin auf Out0 did not deliver all bytes" severity error;

        report "TEST 3 PASSED: Round-Robin auf Out0";

        reset <= '1';
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');
        wait_cycles(3);

        reset <= '0';
        wait_cycles(2);

        -------------------------------------------------------------------
        -- TEST 4: Multicast von In0 auf Out0 und Out1
        -------------------------------------------------------------------
        wr_data_in0 <= x"DE"; wr_eof_in0 <= '0'; wr_en_in0 <= "0011";
        wait_cycles(1);
        wr_data_in0 <= x"AD"; wr_eof_in0 <= '1'; wr_en_in0 <= "0011";
        wait_cycles(1);
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');

        wait_cycles(4);

        gotDE := false;
        gotAD := false;

        if out_data_0 = x"DE" and out_data_1 = x"DE" then gotDE := true; end if;
        if out_data_0 = x"AD" and out_data_1 = x"AD" then gotAD := true; end if;

        for i in 0 to 19 loop
            wait until rising_edge(clk);
            if out_data_0 = x"DE" and out_data_1 = x"DE" then gotDE := true; end if;
            if out_data_0 = x"AD" and out_data_1 = x"AD" then gotAD := true; end if;
        end loop;

        assert gotDE and gotAD
            report "T4 FAIL: Multicast In0 -> Out0/Out1 did not deliver both bytes" severity error;

        report "TEST 4 PASSED: Multicast In0 -> Out0/Out1";

        -------------------------------------------------------------------
        -- TEST 5: Reset während Betrieb
        -------------------------------------------------------------------
        reset <= '1';
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');
        wait_cycles(3);

        reset <= '0';
        wait_cycles(2);

        assert full_in0 = "0000" and full_in1 = "0000" and
               full_in2 = "0000" and full_in3 = "0000"
            report "T5 FAIL: full-Signale müssen 0 sein nach Reset" severity error;

        report "TEST 5 PASSED: Reset während Betrieb";

        reset <= '1';
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');
        wait_cycles(3);

        reset <= '0';
        wait_cycles(2);

        -------------------------------------------------------------------
        -- TEST 6: Unabhängige Frames auf allen Ausgängen
        -------------------------------------------------------------------
        wr_data_in0 <= x"A0"; wr_eof_in0 <= '1'; wr_en_in0 <= "0001";
        wr_data_in1 <= x"B1"; wr_eof_in1 <= '1'; wr_en_in1 <= "0010";
        wr_data_in2 <= x"C2"; wr_eof_in2 <= '1'; wr_en_in2 <= "0100";
        wr_data_in3 <= x"D3"; wr_eof_in3 <= '1'; wr_en_in3 <= "1000";
        wait_cycles(1);
        wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
        wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
        wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
        wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');

        wait_cycles(4);

        gotA0 := false;
        gotB1 := false;
        gotC2 := false;
        gotD3 := false;

        if out_data_0 = x"A0" then gotA0 := true; end if;
        if out_data_1 = x"B1" then gotB1 := true; end if;
        if out_data_2 = x"C2" then gotC2 := true; end if;
        if out_data_3 = x"D3" then gotD3 := true; end if;

        for i in 0 to 19 loop
            wait until rising_edge(clk);
            if out_data_0 = x"A0" then gotA0 := true; end if;
            if out_data_1 = x"B1" then gotB1 := true; end if;
            if out_data_2 = x"C2" then gotC2 := true; end if;
            if out_data_3 = x"D3" then gotD3 := true; end if;
        end loop;

        assert gotA0 and gotB1 and gotC2 and gotD3
            report "T6 FAIL: Unabhängige Frames did not appear on all outputs" severity error;

        report "TEST 6 PASSED: Unabhängige Frames auf allen Ausgängen";

        report "ALLE TESTS ABGESCHLOSSEN";
        wait;
    end process stim;

end architecture sim;
