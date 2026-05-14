-- =============================================================================
-- Testbench: tb_round_robin_allreq_gpt
-- Prueft: round_robin.vhd
--
-- Fokus: Visueller Wellenform-Test fuer Round-Robin-Fairness
-- -----------------------------------------------------------------------
-- Diese TB ist kein Assertion-Test, sondern ein Stimuli-Generator zum
-- Beobachten des Verhaltens im Waveform-Viewer .
--
-- Szenario:
--   - frame_rdy = "1011" (Kanaele 0, 1 und 3 sind dauerhaft bereit,
--                          Kanal 2 hat absichtlich keine Anfrage)
--   - Es werden 12 aufeinanderfolgende Frames simuliert
--   - Jedes Frame dauert 2 Takte im LOCKED-Zustand, dann folgt eof='1'
--     fuer einen Takt, danach beginnt das naechste Frame
--
-- Was man in der Wellenform sehen sollte:
--   - Der Arbiter wechselt nach jedem eof reihum zwischen Kanal 0, 1, 3
--     (Kanal 2 wird uebersprungen, da frame_rdy(2) = '0')
--   - Der rr_ptr schreitet zyklisch voran: 0->1->2->3->0->...
--     wobei Kanal 2 keine Anfrage hat und uebersprungen wird
--   - grant und sel wechseln nach jedem eof auf den naechsten Kanal
--   - active bleibt '1' waehrend LOCKED, faellt kurz auf '0' beim Wechsel
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_round_robin_allreq_gpt IS
END ENTITY;

ARCHITECTURE sim OF tb_round_robin_allreq_gpt IS

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    SIGNAL frame_rdy : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL eof : STD_LOGIC := '0';

    SIGNAL sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL grant : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL active : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    ------------------------------------------------------------------------
    -- DUT
    ------------------------------------------------------------------------
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

    ------------------------------------------------------------------------
    -- Clock
    ------------------------------------------------------------------------
    clk <= NOT clk AFTER CLK_PERIOD/2;

    ------------------------------------------------------------------------
    -- Stimulus
    ------------------------------------------------------------------------
    stim_proc : PROCESS
    BEGIN
        --------------------------------------------------------------------
        -- Reset phase
        --------------------------------------------------------------------
        frame_rdy <= "0000";
        eof <= '0';

        WAIT UNTIL rising_edge(clk);
        WAIT UNTIL rising_edge(clk);

        reset <= '0';

        --------------------------------------------------------------------
        -- Always all requests active
        --------------------------------------------------------------------
        frame_rdy <= "1011";

        --------------------------------------------------------------------
        -- Generate repeated frames
        -- Each frame lasts 2 clock cycles in LOCKED, then eof is asserted
        --------------------------------------------------------------------
        FOR i IN 0 TO 11 LOOP
            -- first cycle of frame
            eof <= '0';
            WAIT UNTIL rising_edge(clk);

            -- second cycle of frame
            eof <= '0';
            WAIT UNTIL rising_edge(clk);

            -- end of frame
            eof <= '1';
            WAIT UNTIL rising_edge(clk);

            -- deassert eof again
            eof <= '0';
        END LOOP;

        --------------------------------------------------------------------
        -- Stop requesting and finish
        --------------------------------------------------------------------
        frame_rdy <= "0000";
        eof <= '0';

        WAIT UNTIL rising_edge(clk);
        WAIT UNTIL rising_edge(clk);

        REPORT "tb_round_robin_allreq_gpt finished." SEVERITY note;
        WAIT;
    END PROCESS;

END ARCHITECTURE;