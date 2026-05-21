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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_round_robin_allreq_gpt is
end entity;

architecture sim of tb_round_robin_allreq_gpt is

    signal clk       : STD_LOGIC                    := '0';
    signal reset     : STD_LOGIC                    := '1';
    signal frame_rdy : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal eof       : STD_LOGIC                    := '0';

    signal sel    : STD_LOGIC_VECTOR(1 downto 0);
    signal grant  : STD_LOGIC_VECTOR(3 downto 0);
    signal active : STD_LOGIC;

    constant CLK_PERIOD : TIME    := 10 ns;
    constant GAP_CYCLES : NATURAL := 12;

begin

    ------------------------------------------------------------------------
    -- DUT
    ------------------------------------------------------------------------
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

    ------------------------------------------------------------------------
    -- Clock
    ------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    ------------------------------------------------------------------------
    -- Stimulus
    ------------------------------------------------------------------------
    stim_proc : process
    begin
        --------------------------------------------------------------------
        -- Reset phase
        --------------------------------------------------------------------
        frame_rdy <= "0000";
        eof       <= '0';
        reset     <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        reset <= '1';

        --------------------------------------------------------------------
        -- Always all requests active
        --------------------------------------------------------------------
        frame_rdy <= "1011";

        --------------------------------------------------------------------
        -- Generate repeated frames
        -- Each frame lasts 2 clock cycles in LOCKED, then eof is asserted
        -- Enforce a minimum gap between EOFs
        --------------------------------------------------------------------
        for i in 0 to 11 loop
            -- first cycle of frame
            eof <= '0';
            wait until rising_edge(clk);

            -- second cycle of frame
            eof <= '0';
            wait until rising_edge(clk);

            -- end of frame
            eof <= '1';
            wait until rising_edge(clk);

            -- deassert eof again
            eof <= '0';

            -- inter-frame gap (minimum 12 clocks between EOFs)
            for g in 1 to GAP_CYCLES loop
                wait until rising_edge(clk);
            end loop;
        end loop;

        --------------------------------------------------------------------
        -- Stop requesting and finish
        --------------------------------------------------------------------
        frame_rdy <= "0000";
        eof       <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        report "tb_round_robin_allreq_gpt finished." severity note;
        wait;
    end process;

end architecture;
