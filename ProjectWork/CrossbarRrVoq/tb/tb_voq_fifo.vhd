-------------------------------------------------------------------------------
-- tb_voq_fifo.vhd
-- Testbench für generischen VOQ-FIFO
--
-- Tests:
--   1. Reset: alles Null, empty, nicht full
--   2. Einen kurzen Frame schreiben (10 Bytes + EOF)
--   3. frame_rdy erst NACH EOF prüfen
--   4. Frame auslesen und Daten vergleichen
--   5. Zwei Frames hintereinander schreiben und lesen
--   6. Gleichzeitiges Lesen und Schreiben
--   7. Full-Signal bei vollem FIFO
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_voq_fifo is
end entity tb_voq_fifo;

architecture sim of tb_voq_fifo is

    constant CLK_PERIOD : time := 8 ns;
    -- Kleiner FIFO für schnellere Simulation
    constant TEST_DEPTH : integer := 32;

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal wr_en     : std_logic := '0';
    signal wr_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof    : std_logic := '0';
    signal rd_en     : std_logic := '0';
    signal rd_data   : std_logic_vector(7 downto 0);
    signal rd_eof    : std_logic;
    signal frame_rdy : std_logic;
    signal full      : std_logic;
    signal empty     : std_logic;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.voq_fifo
        generic map (DEPTH => TEST_DEPTH)
        port map (
            clk       => clk,
            reset     => reset,
            flush     => '0',  -- Kein Flush in diesem Testbench
            wr_en     => wr_en,
            wr_data   => wr_data,
            wr_eof    => wr_eof,
            rd_en     => rd_en,
            rd_data   => rd_data,
            rd_eof    => rd_eof,
            frame_rdy => frame_rdy,
            full      => full,
            empty     => empty
        );

    stim : process
    begin
        -----------------------------------------------------------------------
        -- TEST 1: Reset
        -----------------------------------------------------------------------
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';
        wait until rising_edge(clk); wait for 1 ns;

        assert empty = '1'
            report "T1 FAIL: nicht empty nach Reset" severity error;
        assert full = '0'
            report "T1 FAIL: full nach Reset" severity error;
        assert frame_rdy = '0'
            report "T1 FAIL: frame_rdy nach Reset" severity error;
        report "TEST 1 PASSED: Reset";

        -----------------------------------------------------------------------
        -- TEST 2: Kurzen Frame schreiben (5 Bytes: 0xA0..0xA4, dann EOF)
        -----------------------------------------------------------------------
        report "TEST 2: Frame schreiben...";

        -- Bytes 0..3 (ohne EOF)
        for i in 0 to 3 loop
            wr_en   <= '1';
            wr_data <= std_logic_vector(to_unsigned(16#A0# + i, 8));
            wr_eof  <= '0';
            wait for CLK_PERIOD;
        end loop;

        -- frame_rdy darf noch NICHT gesetzt sein
        wait for 1 ns;
        assert frame_rdy = '0'
            report "T2 FAIL: frame_rdy vor EOF gesetzt!" severity error;

        -- Letztes Byte mit EOF
        wr_data <= x"A4";
        wr_eof  <= '1';
        wait for CLK_PERIOD;
        wr_en  <= '0';
        wr_eof <= '0';
        wait until rising_edge(clk); wait for 1 ns;

        -----------------------------------------------------------------------
        -- TEST 3: frame_rdy muss jetzt gesetzt sein
        -----------------------------------------------------------------------
        assert frame_rdy = '1'
            report "T3 FAIL: frame_rdy nicht gesetzt nach EOF" severity error;
        assert empty = '0'
            report "T3 FAIL: FIFO zeigt empty obwohl Frame drin" severity error;
        report "TEST 3 PASSED: frame_rdy nach EOF";

        -----------------------------------------------------------------------
        -- TEST 4: Frame auslesen und Daten prüfen
        -----------------------------------------------------------------------
        report "TEST 4: Frame auslesen...";

        -- Erste Lesung: rd_en setzen, Daten kommen einen Takt später (BRAM)
        rd_en <= '1';
        wait until rising_edge(clk); wait for 1 ns;  -- Byte 0 liegt in rd_reg

        assert rd_data = x"A0"
            report "T4 FAIL: Byte 0 erwartet 0xA0, got 0x" & to_hstring(rd_data) severity error;
        assert rd_eof = '0'
            report "T4 FAIL: EOF bei Byte 0" severity error;

        wait until rising_edge(clk); wait for 1 ns;
        assert rd_data = x"A1"
            report "T4 FAIL: Byte 1 erwartet 0xA1" severity error;

        wait until rising_edge(clk); wait for 1 ns;
        assert rd_data = x"A2"
            report "T4 FAIL: Byte 2 erwartet 0xA2" severity error;

        wait until rising_edge(clk); wait for 1 ns;
        assert rd_data = x"A3"
            report "T4 FAIL: Byte 3 erwartet 0xA3" severity error;

        wait until rising_edge(clk); wait for 1 ns;
        assert rd_data = x"A4"
            report "T4 FAIL: Byte 4 erwartet 0xA4" severity error;
        assert rd_eof = '1'
            report "T4 FAIL: EOF nicht gesetzt bei letztem Byte" severity error;

        rd_en <= '0';
        wait until rising_edge(clk); wait for 1 ns;

        -- frame_rdy muss wieder '0' sein (kein weiterer Frame)
        assert frame_rdy = '0'
            report "T4 FAIL: frame_rdy noch gesetzt nach Auslesen" severity error;
        report "TEST 4 PASSED: Frame korrekt ausgelesen";

        -----------------------------------------------------------------------
        -- TEST 5: Zwei Frames hintereinander
        -----------------------------------------------------------------------
        report "TEST 5: Zwei Frames...";

        -- Frame 1: 3 Bytes (0xB0, 0xB1, 0xB2+EOF)
        wr_en <= '1';
        wr_data <= x"B0"; wr_eof <= '0'; wait for CLK_PERIOD;
        wr_data <= x"B1"; wr_eof <= '0'; wait for CLK_PERIOD;
        wr_data <= x"B2"; wr_eof <= '1'; wait for CLK_PERIOD;
        wr_eof <= '0';

        -- Frame 2: 2 Bytes (0xC0, 0xC1+EOF)
        wr_data <= x"C0"; wr_eof <= '0'; wait for CLK_PERIOD;
        wr_data <= x"C1"; wr_eof <= '1'; wait for CLK_PERIOD;
        wr_en <= '0'; wr_eof <= '0';
        wait until rising_edge(clk); wait for 1 ns;

        assert frame_rdy = '1'
            report "T5 FAIL: frame_rdy nicht gesetzt" severity error;

        -- Frame 1 auslesen
        rd_en <= '1';
        wait until rising_edge(clk); wait for 1 ns;  -- liest 0xB0
        assert rd_data = x"B0"
            report "T5 FAIL: Frame1 Byte0" severity error;

        wait until rising_edge(clk); wait for 1 ns;  -- liest 0xB1
        wait until rising_edge(clk); wait for 1 ns;  -- liest 0xB2+EOF
        assert rd_data = x"B2"
            report "T5 FAIL: Frame1 letztes Byte" severity error;
        assert rd_eof = '1'
            report "T5 FAIL: Frame1 EOF fehlt" severity error;

        -- frame_rdy muss noch '1' sein (Frame 2 liegt noch drin)
        wait until rising_edge(clk); wait for 1 ns;
        assert frame_rdy = '1'
            report "T5 FAIL: frame_rdy sollte noch 1 sein (Frame 2 drin)" severity error;

        -- Frame 2 auslesen
        -- rd_en ist noch '1', liest weiter
        assert rd_data = x"C0"
            report "T5 FAIL: Frame2 Byte0" severity error;

        wait until rising_edge(clk); wait for 1 ns;  -- liest 0xC1+EOF
        assert rd_data = x"C1"
            report "T5 FAIL: Frame2 Byte1" severity error;
        assert rd_eof = '1'
            report "T5 FAIL: Frame2 EOF fehlt" severity error;

        rd_en <= '0';
        wait until rising_edge(clk); wait for 1 ns;

        assert frame_rdy = '0'
            report "T5 FAIL: frame_rdy nach beiden Frames" severity error;
        assert empty = '1'
            report "T5 FAIL: nicht empty nach beiden Frames" severity error;
        report "TEST 5 PASSED: Zwei Frames hintereinander";

        -----------------------------------------------------------------------
        -- TEST 6: Gleichzeitiges Lesen und Schreiben
        -----------------------------------------------------------------------
        report "TEST 6: Gleichzeitig lesen und schreiben...";

        -- Erst einen Frame reinschreiben
        wr_en <= '1';
        wr_data <= x"D0"; wr_eof <= '0'; wait for CLK_PERIOD;
        wr_data <= x"D1"; wr_eof <= '1'; wait for CLK_PERIOD;
        wr_en <= '0'; wr_eof <= '0';
        wait for CLK_PERIOD;

        -- Jetzt gleichzeitig: neuen Frame schreiben UND alten lesen
        wr_en <= '1'; rd_en <= '1';
        wr_data <= x"E0"; wr_eof <= '0';
        wait for CLK_PERIOD;
        wr_data <= x"E1"; wr_eof <= '1';
        wait for CLK_PERIOD;
        wr_en <= '0'; wr_eof <= '0';

        -- Alten Frame fertig lesen
        wait for CLK_PERIOD;
        rd_en <= '0';
        wait until rising_edge(clk); wait for 1 ns;

        -- Neuer Frame muss noch drin sein
        assert frame_rdy = '1'
            report "T6 FAIL: neuer Frame fehlt" severity error;
        report "TEST 6 PASSED: Gleichzeitiges Lesen/Schreiben";

        -- Aufräumen: restlichen Frame auslesen (E1+EOF, 1 Byte)
        -- Nur 1 Takt rd_en, dann 1 Takt warten damit rd_valid die EOF-Auswertung abschließt
        rd_en <= '1';
        wait for CLK_PERIOD;
        rd_en <= '0';
        wait for CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 7: Full-Signal (FIFO mit DEPTH=32 füllen)
        -----------------------------------------------------------------------
        report "TEST 7: Full-Signal...";

        -- 31 Bytes schreiben (DEPTH-1 = full)
        wr_en <= '1'; wr_eof <= '0';
        for i in 0 to 29 loop
            wr_data <= std_logic_vector(to_unsigned(i, 8));
            wait for CLK_PERIOD;
        end loop;
        -- Letztes Byte
        wr_data <= x"FF";
        wait for CLK_PERIOD;
        wait for 1 ns;

        assert full = '1'
            report "T7 FAIL: full nicht gesetzt bei vollem FIFO" severity error;

        wr_en <= '0';
        report "TEST 7 PASSED: Full-Signal";

        -----------------------------------------------------------------------
        report "ALLE TESTS ABGESCHLOSSEN";
        wait;
    end process stim;

end architecture sim;
