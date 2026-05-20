-------------------------------------------------------------------------------
-- tb_round_robin.vhd
-- Testbench für Round-Robin Arbiter mit Frame-Lock
--
-- Tests:
--   1. Reset: alles idle
--   2. Ein Eingang bereit: wird sofort gewählt
--   3. Frame-Lock: sel bleibt stabil während Frame läuft
--   4. Nach EOF: Pointer dreht weiter, nächster wird gewählt
--   5. Fairness: bei dauerhafter Konkurrenz rotiert der Gewinner
--   6. Kein frame_rdy: bleibt in IDLE
--   7. Priorität springt korrekt (Pointer-Wrap von 3 auf 0)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tb_round_robin is
end entity tb_round_robin;

architecture sim of tb_round_robin is

    constant CLK_PERIOD : TIME := 8 ns;

    signal clk       : STD_LOGIC := '0';
    signal reset     : STD_LOGIC := '1';
    signal frame_rdy : STD_LOGIC_VECTOR(3 downto 0);
    signal eof       : STD_LOGIC;
    signal sel       : STD_LOGIC_VECTOR(1 downto 0);
    signal grant     : STD_LOGIC_VECTOR(3 downto 0);
    signal active    : STD_LOGIC;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.round_robin
        port map(
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy,
            eof       => eof,
            sel       => sel,
            grant     => grant,
            active    => active
        );

    stim : process
        procedure wait_gap is
        begin
            for i in 1 to 10 loop
                wait for CLK_PERIOD;
                wait for 1 ns;
                assert active = '0'
                report "GAP FAIL: active sollte 0 bleiben" severity error;
                assert grant = "0000"
                report "GAP FAIL: grant sollte 0000 bleiben" severity error;
            end loop;
        end procedure;
    begin
        frame_rdy <= "0000";
        eof       <= '0';

        -----------------------------------------------------------------------
        -- TEST 1: Reset
        -----------------------------------------------------------------------
        reset <= '0';
        wait for CLK_PERIOD * 3;
        reset <= '1';
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert active = '0'
        report "T1 FAIL: active nach Reset" severity error;
        assert grant = "0000"
        report "T1 FAIL: grant nach Reset" severity error;
        report "TEST 1 PASSED: Reset";

        -----------------------------------------------------------------------
        -- TEST 2: Nur Eingang 0 hat Frame bereit
        -----------------------------------------------------------------------
        frame_rdy <= "0001";
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert sel = "00"
        report "T2 FAIL: sel sollte 00 sein" severity error;
        assert grant = "0001"
        report "T2 FAIL: grant sollte 0001 sein" severity error;
        assert active = '1'
        report "T2 FAIL: active sollte 1 sein" severity error;
        report "TEST 2 PASSED: Eingang 0 gewählt";

        -----------------------------------------------------------------------
        -- TEST 3: Frame-Lock ? sel bleibt stabil über mehrere Takte
        -- Simuliere einen kurzen Frame (5 Bytes)
        -----------------------------------------------------------------------
        frame_rdy <= "1111"; -- andere wollen auch, aber Lock hält
        wait for CLK_PERIOD;
        wait for 1 ns;
        assert sel = "00"
        report "T3a FAIL: sel muss 00 bleiben (locked)" severity error;

        wait for CLK_PERIOD;
        wait for 1 ns;
        assert sel = "00"
        report "T3b FAIL: sel muss 00 bleiben" severity error;

        wait for CLK_PERIOD;
        wait for 1 ns;
        assert sel = "00"
        report "T3c FAIL: sel muss 00 bleiben" severity error;

        -- Letztes Byte: EOF
        eof <= '1';
        wait for CLK_PERIOD;
        wait for 1 ns;
        eof <= '0';

        assert active = '0'
        report "T3 FAIL: active sollte nach EOF 0 sein" severity error;
        wait_gap;
        report "TEST 3 PASSED: Frame-Lock hält";

        -----------------------------------------------------------------------
        -- TEST 4: Nach EOF + Gap dreht Pointer weiter
        -- Pointer war auf 0, Gewinner war 0, also jetzt ptr=1
        -- Bei frame_rdy="1111" sollte Eingang 1 gewählt werden
        -----------------------------------------------------------------------
        frame_rdy <= "1111";
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert sel = "01"
        report "T4 FAIL: sel sollte 01 sein (ptr=1)" severity error;
        assert grant = "0010"
        report "T4 FAIL: grant sollte 0010 sein" severity error;
        report "TEST 4 PASSED: Pointer dreht zu Eingang 1";

        -- Frame beenden
        eof <= '1';
        wait for CLK_PERIOD;
        wait for 1 ns;
        eof <= '0';
        wait_gap;

        -----------------------------------------------------------------------
        -- TEST 5: Fairness ? bei dauerhafter Konkurrenz rotiert Gewinner
        -- Nach Eingang 1: ptr=2, also Eingang 2
        -----------------------------------------------------------------------
        frame_rdy <= "1111";
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert sel = "10"
        report "T5a FAIL: sel sollte 10 sein" severity error;
        report "TEST 5a: Eingang 2 gewählt";

        eof <= '1';
        wait for CLK_PERIOD;
        wait for 1 ns;
        eof <= '0';
        wait_gap;

        -- Jetzt ptr=3, also Eingang 3
        frame_rdy <= "1111";
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert sel = "11"
        report "T5b FAIL: sel sollte 11 sein" severity error;
        report "TEST 5b: Eingang 3 gewählt";

        eof <= '1';
        wait for CLK_PERIOD;
        wait for 1 ns;
        eof <= '0';
        wait_gap;

        -- Jetzt ptr=0, Wrap ? wieder Eingang 0
        frame_rdy <= "1111";
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert sel = "00"
        report "T5c FAIL: sel sollte 00 sein (Wrap)" severity error;
        report "TEST 5c: Wrap - Eingang 0 wieder dran";
        report "TEST 5 PASSED: Fairness / Rotation komplett";

        eof <= '1';
        wait for CLK_PERIOD;
        wait for 1 ns;
        eof <= '0';
        wait_gap;

        -----------------------------------------------------------------------
        -- TEST 6: Kein frame_rdy ? bleibt IDLE
        -----------------------------------------------------------------------
        frame_rdy <= "0000";
        wait for CLK_PERIOD * 3;
        wait for 1 ns;

        assert active = '0'
        report "T6 FAIL: sollte IDLE bleiben" severity error;
        assert grant = "0000"
        report "T6 FAIL: kein grant ohne frame_rdy" severity error;
        report "TEST 6 PASSED: Bleibt IDLE ohne Anfrage";

        -----------------------------------------------------------------------
        -- TEST 7: Nur Eingang 3 bereit, Pointer steht auf 1
        -- RR soll über 1?2?3 suchen und 3 finden
        -----------------------------------------------------------------------
        frame_rdy <= "1000"; -- nur Eingang 3
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert sel = "11"
        report "T7 FAIL: sel sollte 11 sein" severity error;
        assert grant = "1000"
        report "T7 FAIL: grant sollte 1000 sein" severity error;
        report "TEST 7 PASSED: Überspringt leere Eingänge";

        eof <= '1';
        wait for CLK_PERIOD;
        wait for 1 ns;
        eof <= '0';
        wait_gap;

        -----------------------------------------------------------------------
        report "ALLE TESTS ABGESCHLOSSEN";
        wait;
    end process stim;

end architecture sim;
