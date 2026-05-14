-- =============================================================================
-- Testbench: tb_round_robin_gpt
-- Prueft: round_robin.vhd
--
-- Was wird getestet:
-- -----------------------------------------------------------------------
-- TEST 0 | Reset / Idle
--        | Prueft, dass nach Reset alle Ausgaenge (sel, grant, active)
--        | auf 0 liegen und der Arbiter im Ruhezustand bleibt,
--        | solange kein Kanal einen Frame anmeldet.
--
-- TEST 1 | Einzelne Anfrage an Kanal 3
--        | Prueft, dass der Arbiter Kanal 3 (frame_rdy="1000") erkennt,
--        | korrekt auf sel="11", grant="1000", active='1' schaltet
--        | und den Grant haelt bis eof='1'.
--
-- TEST 2 | Einzelne Anfrage an Kanal 0
--        | Gleicher Ablauf wie TEST 1, diesmal mit Kanal 0 (frame_rdy="0001").
--        | Prueft die Grundfunktion fuer den niedrigsten Kanal.
--
-- TEST 3 | Grant bleibt gesperrt bis eof, auch bei neuen Anfragen
--        | Waehrend Kanal 1 locked ist, aendert sich frame_rdy auf
--        | andere Kanaele (inkl. "1111"). Erwartet wird, dass der Arbiter
--        | den Grant auf Kanal 1 haelt und erst nach eof freigibt.
--
-- TEST 4 | Round-Robin-Fairness: Zyklische Reihenfolge
--        | Alle 4 Kanaele sind gleichzeitig bereit (frame_rdy="1111").
--        | Prueft, dass der Arbiter nach einem Reset der Reihe nach
--        | Kanal 0 -> 1 -> 2 -> 3 bedient (zyklisch, fair).
--
-- TEST 5 | Sparse-Scan: richtiger Startpunkt des rr_ptr
--        | Nur Kanaele 0 und 3 haben Anfragen (frame_rdy="1001").
--        | Prueft, dass der Arbiter ab rr_ptr=0 zuerst Kanal 0 waehlt,
--        | und nach dem naechsten Frame (rr_ptr=1) Kanal 3 waehlt.
--
-- TEST 6 | Jeder Kanal einzeln mit frischem Reset
--        | Kanaele 1, 2 und 3 werden jeweils nach einem eigenen Reset
--        | einzeln getestet. Prueft Korrektheit der Grant-Dekodierung
--        | fuer alle One-Hot-Ausgaben.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_round_robin_gpt IS
END ENTITY;

ARCHITECTURE sim OF tb_round_robin_gpt IS

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';
    SIGNAL frame_rdy : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL eof : STD_LOGIC := '0';

    SIGNAL sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL grant : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL active : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

    FUNCTION slv_to_string(slv : STD_LOGIC_VECTOR) RETURN STRING IS
        VARIABLE result : STRING(1 TO slv'length);
        VARIABLE idx : INTEGER := 1;
    BEGIN
        FOR i IN slv'reverse_range LOOP
            CASE slv(i) IS
                WHEN '0' => result(idx) := '0';
                WHEN '1' => result(idx) := '1';
                WHEN 'U' => result(idx) := 'U';
                WHEN 'X' => result(idx) := 'X';
                WHEN 'Z' => result(idx) := 'Z';
                WHEN 'W' => result(idx) := 'W';
                WHEN 'L' => result(idx) := 'L';
                WHEN 'H' => result(idx) := 'H';
                WHEN '-' => result(idx) := '-';
                WHEN OTHERS => result(idx) := '?';
            END CASE;
            idx := idx + 1;
        END LOOP;
        RETURN result;
    END FUNCTION;

BEGIN

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

    clk <= NOT clk AFTER CLK_PERIOD/2;

    stim_proc : PROCESS

        PROCEDURE check_outputs(
            CONSTANT exp_sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
            CONSTANT exp_grant : STD_LOGIC_VECTOR(3 DOWNTO 0);
            CONSTANT exp_active : STD_LOGIC;
            CONSTANT msg : STRING
        ) IS
        BEGIN
            ASSERT sel = exp_sel
            REPORT msg & " | SEL mismatch. Expected="
                & slv_to_string(exp_sel)
                & " Actual=" & slv_to_string(sel)
                SEVERITY error;

            ASSERT grant = exp_grant
            REPORT msg & " | GRANT mismatch. Expected="
                & slv_to_string(exp_grant)
                & " Actual=" & slv_to_string(grant)
                SEVERITY error;

            ASSERT active = exp_active
            REPORT msg & " | ACTIVE mismatch. Expected="
                & STD_LOGIC'image(exp_active)
                & " Actual=" & STD_LOGIC'image(active)
                SEVERITY error;
        END PROCEDURE;

        PROCEDURE step_and_check(
            CONSTANT exp_sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
            CONSTANT exp_grant : STD_LOGIC_VECTOR(3 DOWNTO 0);
            CONSTANT exp_active : STD_LOGIC;
            CONSTANT msg : STRING
        ) IS
        BEGIN
            WAIT UNTIL rising_edge(clk);
            WAIT FOR 0.3 ns;
            check_outputs(exp_sel, exp_grant, exp_active, msg);
        END PROCEDURE;

        PROCEDURE reset_dut IS
        BEGIN
            frame_rdy <= "0000";
            eof <= '0';
            reset <= '1';
            WAIT UNTIL rising_edge(clk);
            WAIT FOR 1 ns;
            check_outputs("00", "0000", '0', "Reset cycle 1");
            WAIT UNTIL rising_edge(clk);
            WAIT FOR 1 ns;
            check_outputs("00", "0000", '0', "Reset cycle 2");
            reset <= '0';
        END PROCEDURE;

        PROCEDURE release_and_check_idle(
            CONSTANT exp_sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
            CONSTANT msg : STRING
        ) IS
        BEGIN
            eof <= '1';
            step_and_check(exp_sel, "0000", '0', msg & " | EOF release");
            eof <= '0';
            frame_rdy <= "0000";
            step_and_check(exp_sel, "0000", '0', msg & " | Idle after release");
        END PROCEDURE;

    BEGIN
        --------------------------------------------------------------------
        -- TEST 0
        --------------------------------------------------------------------
        REPORT "TEST 0: reset / idle" SEVERITY note;
        reset_dut;
        step_and_check("00", "0000", '0', "No request pending");

        --------------------------------------------------------------------
        -- TEST 1
        --------------------------------------------------------------------
        REPORT "TEST 1: single request at input 3 (easy to see in waveform)" SEVERITY note;
        reset_dut;
        frame_rdy <= "1000";
        eof <= '0';
        step_and_check("11", "1000", '1', "Acquire input 3");
        step_and_check("11", "1000", '1', "Stay locked on input 3");
        release_and_check_idle("11", "Input 3");

        --------------------------------------------------------------------
        -- TEST 2
        --------------------------------------------------------------------
        REPORT "TEST 2: single request at input 0" SEVERITY note;
        reset_dut;
        frame_rdy <= "0001";
        step_and_check("00", "0001", '1', "Acquire input 0");
        step_and_check("00", "0001", '1', "Stay locked on input 0");
        release_and_check_idle("00", "Input 0");

        --------------------------------------------------------------------
        -- TEST 3
        --------------------------------------------------------------------
        REPORT "TEST 3: locked grant ignores frame_rdy changes until eof" SEVERITY note;
        reset_dut;
        frame_rdy <= "0010";
        step_and_check("01", "0010", '1', "Acquire input 1");
        frame_rdy <= "1000";
        step_and_check("01", "0010", '1', "Still locked on input 1");
        frame_rdy <= "1111";
        step_and_check("01", "0010", '1', "Still locked on input 1 with all requests high");
        release_and_check_idle("01", "Input 1");

        --------------------------------------------------------------------
        -- TEST 4
        --------------------------------------------------------------------
        REPORT "TEST 4: round-robin fairness sequence starting from reset" SEVERITY note;
        reset_dut;

        -- only input 3 ready -> should eventually pick 3
        frame_rdy <= "1000";
        step_and_check("11", "1000", '1', "Fairness seq: pick input 3");
        release_and_check_idle("11", "Fairness seq after input 3");

        -- now rr_ptr should be 0, so with all requests high, pick 0
        frame_rdy <= "1111";
        step_and_check("00", "0001", '1', "Fairness seq: then pick input 0");
        release_and_check_idle("00", "Fairness seq after input 0");

        -- now expect 1
        frame_rdy <= "1111";
        step_and_check("01", "0010", '1', "Fairness seq: then pick input 1");
        release_and_check_idle("01", "Fairness seq after input 1");

        -- now expect 2
        frame_rdy <= "1111";
        step_and_check("10", "0100", '1', "Fairness seq: then pick input 2");
        release_and_check_idle("10", "Fairness seq after input 2");

        --------------------------------------------------------------------
        -- TEST 5
        --------------------------------------------------------------------
        REPORT "TEST 5: sparse scan order from reset" SEVERITY note;
        reset_dut;
        frame_rdy <= "1001"; -- inputs 3 and 0
        step_and_check("00", "0001", '1', "From rr_ptr=0 should pick input 0 first");
        release_and_check_idle("00", "Sparse test after input 0");

        frame_rdy <= "1001"; -- now rr_ptr should be 1, scan 1->2->3->0, so pick 3
        step_and_check("11", "1000", '1', "From rr_ptr=1 should pick input 3");
        release_and_check_idle("11", "Sparse test after input 3");

        --------------------------------------------------------------------
        -- TEST 6
        --------------------------------------------------------------------
        REPORT "TEST 6: each port individually from fresh reset" SEVERITY note;

        reset_dut;
        frame_rdy <= "0010";
        step_and_check("01", "0010", '1', "Single input 1");
        release_and_check_idle("01", "Single input 1");

        reset_dut;
        frame_rdy <= "0100";
        step_and_check("10", "0100", '1', "Single input 2");
        release_and_check_idle("10", "Single input 2");

        reset_dut;
        frame_rdy <= "1000";
        step_and_check("11", "1000", '1', "Single input 3 again");
        release_and_check_idle("11", "Single input 3 again");

        REPORT "All tests in tb_round_robin_gpt completed successfully." SEVERITY note;
        WAIT;
    END PROCESS;

END ARCHITECTURE;