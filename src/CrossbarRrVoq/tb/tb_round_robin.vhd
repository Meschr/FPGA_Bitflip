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

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY tb_round_robin IS
END ENTITY tb_round_robin;

ARCHITECTURE sim OF tb_round_robin IS

    CONSTANT CLK_PERIOD : TIME := 8 ns;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    SIGNAL frame_rdy : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL eof : STD_LOGIC;
    SIGNAL sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL grant : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL active : STD_LOGIC;

BEGIN

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    dut : ENTITY work.round_robin
        PORT MAP(
            clk => clk,
            reset => reset,
            frame_rdy => frame_rdy,
            eof => eof,
            sel => sel,
            grant => grant,
            active => active
        );

    stim : PROCESS
        PROCEDURE wait_gap IS
        BEGIN
            FOR i IN 1 TO 10 LOOP
                WAIT FOR CLK_PERIOD;
                WAIT FOR 1 ns;
                ASSERT active = '0'
                REPORT "GAP FAIL: active sollte 0 bleiben" SEVERITY error;
                ASSERT grant = "0000"
                REPORT "GAP FAIL: grant sollte 0000 bleiben" SEVERITY error;
            END LOOP;
        END PROCEDURE;
    BEGIN
        frame_rdy <= "0000";
        eof <= '0';

        -----------------------------------------------------------------------
        -- TEST 1: Reset
        -----------------------------------------------------------------------
        reset <= '0';
        WAIT FOR CLK_PERIOD * 3;
        reset <= '1';
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT active = '0'
        REPORT "T1 FAIL: active nach Reset" SEVERITY error;
        ASSERT grant = "0000"
        REPORT "T1 FAIL: grant nach Reset" SEVERITY error;
        REPORT "TEST 1 PASSED: Reset";

        -----------------------------------------------------------------------
        -- TEST 2: Nur Eingang 0 hat Frame bereit
        -----------------------------------------------------------------------
        frame_rdy <= "0001";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT sel = "00"
        REPORT "T2 FAIL: sel sollte 00 sein" SEVERITY error;
        ASSERT grant = "0001"
        REPORT "T2 FAIL: grant sollte 0001 sein" SEVERITY error;
        ASSERT active = '1'
        REPORT "T2 FAIL: active sollte 1 sein" SEVERITY error;
        REPORT "TEST 2 PASSED: Eingang 0 gewählt";

        -----------------------------------------------------------------------
        -- TEST 3: Frame-Lock ? sel bleibt stabil über mehrere Takte
        -- Simuliere einen kurzen Frame (5 Bytes)
        -----------------------------------------------------------------------
        frame_rdy <= "1111"; -- andere wollen auch, aber Lock hält
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT sel = "00"
        REPORT "T3a FAIL: sel muss 00 bleiben (locked)" SEVERITY error;

        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT sel = "00"
        REPORT "T3b FAIL: sel muss 00 bleiben" SEVERITY error;

        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        ASSERT sel = "00"
        REPORT "T3c FAIL: sel muss 00 bleiben" SEVERITY error;

        -- Letztes Byte: EOF
        eof <= '1';
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        eof <= '0';

        ASSERT active = '0'
        REPORT "T3 FAIL: active sollte nach EOF 0 sein" SEVERITY error;
        wait_gap;
        REPORT "TEST 3 PASSED: Frame-Lock hält";

        -----------------------------------------------------------------------
        -- TEST 4: Nach EOF + Gap dreht Pointer weiter
        -- Pointer war auf 0, Gewinner war 0, also jetzt ptr=1
        -- Bei frame_rdy="1111" sollte Eingang 1 gewählt werden
        -----------------------------------------------------------------------
        frame_rdy <= "1111";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT sel = "01"
        REPORT "T4 FAIL: sel sollte 01 sein (ptr=1)" SEVERITY error;
        ASSERT grant = "0010"
        REPORT "T4 FAIL: grant sollte 0010 sein" SEVERITY error;
        REPORT "TEST 4 PASSED: Pointer dreht zu Eingang 1";

        -- Frame beenden
        eof <= '1';
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        eof <= '0';
        wait_gap;

        -----------------------------------------------------------------------
        -- TEST 5: Fairness ? bei dauerhafter Konkurrenz rotiert Gewinner
        -- Nach Eingang 1: ptr=2, also Eingang 2
        -----------------------------------------------------------------------
        frame_rdy <= "1111";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT sel = "10"
        REPORT "T5a FAIL: sel sollte 10 sein" SEVERITY error;
        REPORT "TEST 5a: Eingang 2 gewählt";

        eof <= '1';
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        eof <= '0';
        wait_gap;

        -- Jetzt ptr=3, also Eingang 3
        frame_rdy <= "1111";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT sel = "11"
        REPORT "T5b FAIL: sel sollte 11 sein" SEVERITY error;
        REPORT "TEST 5b: Eingang 3 gewählt";

        eof <= '1';
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        eof <= '0';
        wait_gap;

        -- Jetzt ptr=0, Wrap ? wieder Eingang 0
        frame_rdy <= "1111";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT sel = "00"
        REPORT "T5c FAIL: sel sollte 00 sein (Wrap)" SEVERITY error;
        REPORT "TEST 5c: Wrap - Eingang 0 wieder dran";
        REPORT "TEST 5 PASSED: Fairness / Rotation komplett";

        eof <= '1';
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        eof <= '0';
        wait_gap;

        -----------------------------------------------------------------------
        -- TEST 6: Kein frame_rdy ? bleibt IDLE
        -----------------------------------------------------------------------
        frame_rdy <= "0000";
        WAIT FOR CLK_PERIOD * 3;
        WAIT FOR 1 ns;

        ASSERT active = '0'
        REPORT "T6 FAIL: sollte IDLE bleiben" SEVERITY error;
        ASSERT grant = "0000"
        REPORT "T6 FAIL: kein grant ohne frame_rdy" SEVERITY error;
        REPORT "TEST 6 PASSED: Bleibt IDLE ohne Anfrage";

        -----------------------------------------------------------------------
        -- TEST 7: Nur Eingang 3 bereit, Pointer steht auf 1
        -- RR soll über 1?2?3 suchen und 3 finden
        -----------------------------------------------------------------------
        frame_rdy <= "1000"; -- nur Eingang 3
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT sel = "11"
        REPORT "T7 FAIL: sel sollte 11 sein" SEVERITY error;
        ASSERT grant = "1000"
        REPORT "T7 FAIL: grant sollte 1000 sein" SEVERITY error;
        REPORT "TEST 7 PASSED: Überspringt leere Eingänge";

        eof <= '1';
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;
        eof <= '0';
        wait_gap;

        -----------------------------------------------------------------------
        REPORT "ALLE TESTS ABGESCHLOSSEN";
        WAIT;
    END PROCESS stim;

END ARCHITECTURE sim;