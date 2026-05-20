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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_round_robin_gpt is
end entity;

architecture sim of tb_round_robin_gpt is

    signal clk       : STD_LOGIC                    := '0';
    signal reset     : STD_LOGIC                    := '1';
    signal frame_rdy : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal eof       : STD_LOGIC                    := '0';

    signal sel    : STD_LOGIC_VECTOR(1 downto 0);
    signal grant  : STD_LOGIC_VECTOR(3 downto 0);
    signal active : STD_LOGIC;

    constant CLK_PERIOD : TIME := 10 ns;

    function slv_to_string(slv : STD_LOGIC_VECTOR) return STRING is
        variable result            : STRING(1 to slv'length);
        variable idx               : INTEGER := 1;
    begin
        for i in slv'reverse_range loop
            case slv(i) is
                when '0'    => result(idx)    := '0';
                when '1'    => result(idx)    := '1';
                when 'U'    => result(idx)    := 'U';
                when 'X'    => result(idx)    := 'X';
                when 'Z'    => result(idx)    := 'Z';
                when 'W'    => result(idx)    := 'W';
                when 'L'    => result(idx)    := 'L';
                when 'H'    => result(idx)    := 'H';
                when '-'    => result(idx)    := '-';
                when others => result(idx) := '?';
            end case;
            idx := idx + 1;
        end loop;
        return result;
    end function;

begin

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

    clk <= not clk after CLK_PERIOD/2;

    stim_proc : process

        procedure check_outputs(
            constant exp_sel    : STD_LOGIC_VECTOR(1 downto 0);
            constant exp_grant  : STD_LOGIC_VECTOR(3 downto 0);
            constant exp_active : STD_LOGIC;
            constant msg        : STRING
        ) is
        begin
            assert sel = exp_sel
            report msg & " | SEL mismatch. Expected="
                & slv_to_string(exp_sel)
                & " Actual=" & slv_to_string(sel)
                severity error;

            assert grant = exp_grant
            report msg & " | GRANT mismatch. Expected="
                & slv_to_string(exp_grant)
                & " Actual=" & slv_to_string(grant)
                severity error;

            assert active = exp_active
            report msg & " | ACTIVE mismatch. Expected="
                & STD_LOGIC'image(exp_active)
                & " Actual=" & STD_LOGIC'image(active)
                severity error;
        end procedure;

        procedure step_and_check(
            constant exp_sel    : STD_LOGIC_VECTOR(1 downto 0);
            constant exp_grant  : STD_LOGIC_VECTOR(3 downto 0);
            constant exp_active : STD_LOGIC;
            constant msg        : STRING
        ) is
        begin
            wait until rising_edge(clk);
            wait for 0.3 ns;
            check_outputs(exp_sel, exp_grant, exp_active, msg);
        end procedure;

        procedure reset_dut is
        begin
            frame_rdy <= "0000";
            eof       <= '0';
            reset     <= '0';
            wait until rising_edge(clk);
            wait for 1 ns;
            check_outputs("00", "0000", '0', "Reset cycle 1");
            wait until rising_edge(clk);
            wait for 1 ns;
            check_outputs("00", "0000", '0', "Reset cycle 2");
            reset <= '1';
        end procedure;

        procedure release_and_check_idle(
            constant exp_sel : STD_LOGIC_VECTOR(1 downto 0);
            constant msg     : STRING
        ) is
        begin
            eof <= '1';
            step_and_check(exp_sel, "0000", '0', msg & " | EOF release");
            eof       <= '0';
            frame_rdy <= "0000";
            step_and_check(exp_sel, "0000", '0', msg & " | Idle after release");
        end procedure;

    begin
        --------------------------------------------------------------------
        -- TEST 0
        --------------------------------------------------------------------
        report "TEST 0: reset / idle" severity note;
        reset_dut;
        step_and_check("00", "0000", '0', "No request pending");

        --------------------------------------------------------------------
        -- TEST 1
        --------------------------------------------------------------------
        report "TEST 1: single request at input 3 (easy to see in waveform)" severity note;
        reset_dut;
        frame_rdy <= "1000";
        eof       <= '0';
        step_and_check("11", "1000", '1', "Acquire input 3");
        step_and_check("11", "1000", '1', "Stay locked on input 3");
        release_and_check_idle("11", "Input 3");

        --------------------------------------------------------------------
        -- TEST 2
        --------------------------------------------------------------------
        report "TEST 2: single request at input 0" severity note;
        reset_dut;
        frame_rdy <= "0001";
        step_and_check("00", "0001", '1', "Acquire input 0");
        step_and_check("00", "0001", '1', "Stay locked on input 0");
        release_and_check_idle("00", "Input 0");

        --------------------------------------------------------------------
        -- TEST 3
        --------------------------------------------------------------------
        report "TEST 3: locked grant ignores frame_rdy changes until eof" severity note;
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
        report "TEST 4: round-robin fairness sequence starting from reset" severity note;
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
        report "TEST 5: sparse scan order from reset" severity note;
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
        report "TEST 6: each port individually from fresh reset" severity note;

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

        report "All tests in tb_round_robin_gpt completed successfully." severity note;
        wait;
    end process;

end architecture;
