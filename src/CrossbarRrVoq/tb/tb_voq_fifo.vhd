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

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_voq_fifo IS
END ENTITY tb_voq_fifo;

ARCHITECTURE sim OF tb_voq_fifo IS

    CONSTANT CLK_PERIOD : TIME := 8 ns;
    -- Kleiner FIFO für schnellere Simulation
    CONSTANT TEST_DEPTH : INTEGER := 32;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    SIGNAL wr_en : STD_LOGIC := '0';
    SIGNAL wr_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL wr_eof : STD_LOGIC := '0';
    SIGNAL rd_en : STD_LOGIC := '0';
    SIGNAL rd_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL rd_eof : STD_LOGIC;
    SIGNAL frame_rdy : STD_LOGIC;
    SIGNAL full : STD_LOGIC;
    SIGNAL empty : STD_LOGIC;

BEGIN

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    dut : ENTITY work.voq_fifo
        GENERIC MAP(DEPTH => TEST_DEPTH)
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => '0', -- Kein Flush in diesem Testbench
            wr_en => wr_en,
            wr_data => wr_data,
            wr_eof => wr_eof,
            rd_en => rd_en,
            rd_data => rd_data,
            rd_eof => rd_eof,
            frame_rdy => frame_rdy,
            full => full,
            empty => empty
        );

    stim : PROCESS
    BEGIN
        -----------------------------------------------------------------------
        -- TEST 1: Reset
        -----------------------------------------------------------------------
        reset <= '1';
        WAIT FOR CLK_PERIOD * 3;
        reset <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        ASSERT empty = '1'
        REPORT "T1 FAIL: nicht empty nach Reset" SEVERITY error;
        ASSERT full = '0'
        REPORT "T1 FAIL: full nach Reset" SEVERITY error;
        ASSERT frame_rdy = '0'
        REPORT "T1 FAIL: frame_rdy nach Reset" SEVERITY error;
        REPORT "TEST 1 PASSED: Reset";

        -----------------------------------------------------------------------
        -- TEST 2: Kurzen Frame schreiben (5 Bytes: 0xA0..0xA4, dann EOF)
        -----------------------------------------------------------------------
        REPORT "TEST 2: Frame schreiben...";

        -- Bytes 0..3 (ohne EOF)
        FOR i IN 0 TO 3 LOOP
            wr_en <= '1';
            wr_data <= STD_LOGIC_VECTOR(to_unsigned(16#A0# + i, 8));
            wr_eof <= '0';
            WAIT FOR CLK_PERIOD;
        END LOOP;

        -- frame_rdy darf noch NICHT gesetzt sein
        WAIT FOR 1 ns;
        ASSERT frame_rdy = '0'
        REPORT "T2 FAIL: frame_rdy vor EOF gesetzt!" SEVERITY error;

        -- Letztes Byte mit EOF
        wr_data <= x"A4";
        wr_eof <= '1';
        WAIT FOR CLK_PERIOD;
        wr_en <= '0';
        wr_eof <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        -----------------------------------------------------------------------
        -- TEST 3: frame_rdy muss jetzt gesetzt sein
        -----------------------------------------------------------------------
        ASSERT frame_rdy = '1'
        REPORT "T3 FAIL: frame_rdy nicht gesetzt nach EOF" SEVERITY error;
        ASSERT empty = '0'
        REPORT "T3 FAIL: FIFO zeigt empty obwohl Frame drin" SEVERITY error;
        REPORT "TEST 3 PASSED: frame_rdy nach EOF";

        -----------------------------------------------------------------------
        -- TEST 4: Frame auslesen und Daten prüfen
        -----------------------------------------------------------------------
        REPORT "TEST 4: Frame auslesen...";

        -- Erste Lesung: rd_en setzen, Daten kommen einen Takt später (BRAM)
        rd_en <= '1';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns; -- Byte 0 liegt in rd_reg

        ASSERT rd_data = x"A0"
        REPORT "T4 FAIL: Byte 0 erwartet 0xA0, got 0x" & to_hstring(rd_data) SEVERITY error;
        ASSERT rd_eof = '0'
        REPORT "T4 FAIL: EOF bei Byte 0" SEVERITY error;

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT rd_data = x"A1"
        REPORT "T4 FAIL: Byte 1 erwartet 0xA1" SEVERITY error;

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT rd_data = x"A2"
        REPORT "T4 FAIL: Byte 2 erwartet 0xA2" SEVERITY error;

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT rd_data = x"A3"
        REPORT "T4 FAIL: Byte 3 erwartet 0xA3" SEVERITY error;

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT rd_data = x"A4"
        REPORT "T4 FAIL: Byte 4 erwartet 0xA4" SEVERITY error;
        ASSERT rd_eof = '1'
        REPORT "T4 FAIL: EOF nicht gesetzt bei letztem Byte" SEVERITY error;

        rd_en <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        -- frame_rdy muss wieder '0' sein (kein weiterer Frame)
        ASSERT frame_rdy = '0'
        REPORT "T4 FAIL: frame_rdy noch gesetzt nach Auslesen" SEVERITY error;
        REPORT "TEST 4 PASSED: Frame korrekt ausgelesen";

        -----------------------------------------------------------------------
        -- TEST 5: Zwei Frames hintereinander
        -----------------------------------------------------------------------
        REPORT "TEST 5: Zwei Frames...";

        -- Frame 1: 3 Bytes (0xB0, 0xB1, 0xB2+EOF)
        wr_en <= '1';
        wr_data <= x"B0";
        wr_eof <= '0';
        WAIT FOR CLK_PERIOD;
        wr_data <= x"B1";
        wr_eof <= '0';
        WAIT FOR CLK_PERIOD;
        wr_data <= x"B2";
        wr_eof <= '1';
        WAIT FOR CLK_PERIOD;
        wr_eof <= '0';

        -- Frame 2: 2 Bytes (0xC0, 0xC1+EOF)
        wr_data <= x"C0";
        wr_eof <= '0';
        WAIT FOR CLK_PERIOD;
        wr_data <= x"C1";
        wr_eof <= '1';
        WAIT FOR CLK_PERIOD;
        wr_en <= '0';
        wr_eof <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        ASSERT frame_rdy = '1'
        REPORT "T5 FAIL: frame_rdy nicht gesetzt" SEVERITY error;

        -- Frame 1 auslesen
        rd_en <= '1';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns; -- liest 0xB0
        ASSERT rd_data = x"B0"
        REPORT "T5 FAIL: Frame1 Byte0" SEVERITY error;

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns; -- liest 0xB1
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns; -- liest 0xB2+EOF
        ASSERT rd_data = x"B2"
        REPORT "T5 FAIL: Frame1 letztes Byte" SEVERITY error;
        ASSERT rd_eof = '1'
        REPORT "T5 FAIL: Frame1 EOF fehlt" SEVERITY error;

        -- frame_rdy muss noch '1' sein (Frame 2 liegt noch drin)
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT frame_rdy = '1'
        REPORT "T5 FAIL: frame_rdy sollte noch 1 sein (Frame 2 drin)" SEVERITY error;

        -- Frame 2 auslesen
        -- rd_en ist noch '1', liest weiter
        ASSERT rd_data = x"C0"
        REPORT "T5 FAIL: Frame2 Byte0" SEVERITY error;

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns; -- liest 0xC1+EOF
        ASSERT rd_data = x"C1"
        REPORT "T5 FAIL: Frame2 Byte1" SEVERITY error;
        ASSERT rd_eof = '1'
        REPORT "T5 FAIL: Frame2 EOF fehlt" SEVERITY error;

        rd_en <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        ASSERT frame_rdy = '0'
        REPORT "T5 FAIL: frame_rdy nach beiden Frames" SEVERITY error;
        ASSERT empty = '1'
        REPORT "T5 FAIL: nicht empty nach beiden Frames" SEVERITY error;
        REPORT "TEST 5 PASSED: Zwei Frames hintereinander";

        -----------------------------------------------------------------------
        -- TEST 6: Gleichzeitiges Lesen und Schreiben
        -----------------------------------------------------------------------
        REPORT "TEST 6: Gleichzeitig lesen und schreiben...";

        -- Erst einen Frame reinschreiben
        wr_en <= '1';
        wr_data <= x"D0";
        wr_eof <= '0';
        WAIT FOR CLK_PERIOD;
        wr_data <= x"D1";
        wr_eof <= '1';
        WAIT FOR CLK_PERIOD;
        wr_en <= '0';
        wr_eof <= '0';
        WAIT FOR CLK_PERIOD;

        -- Jetzt gleichzeitig: neuen Frame schreiben UND alten lesen
        wr_en <= '1';
        rd_en <= '1';
        wr_data <= x"E0";
        wr_eof <= '0';
        WAIT FOR CLK_PERIOD;
        wr_data <= x"E1";
        wr_eof <= '1';
        WAIT FOR CLK_PERIOD;
        wr_en <= '0';
        wr_eof <= '0';

        -- Alten Frame fertig lesen
        WAIT FOR CLK_PERIOD;
        rd_en <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        -- Neuer Frame muss noch drin sein
        ASSERT frame_rdy = '1'
        REPORT "T6 FAIL: neuer Frame fehlt" SEVERITY error;
        REPORT "TEST 6 PASSED: Gleichzeitiges Lesen/Schreiben";

        -- Aufräumen: restlichen Frame auslesen (E1+EOF, 1 Byte)
        -- Nur 1 Takt rd_en, dann 1 Takt warten damit rd_valid die EOF-Auswertung abschließt
        rd_en <= '1';
        WAIT FOR CLK_PERIOD;
        rd_en <= '0';
        WAIT FOR CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 7: Full-Signal (FIFO mit DEPTH=32 füllen)
        -----------------------------------------------------------------------
        REPORT "TEST 7: Full-Signal...";

        -- 31 Bytes schreiben (DEPTH-1 = full)
        wr_en <= '1';
        wr_eof <= '0';
        FOR i IN 0 TO 29 LOOP
            wr_data <= STD_LOGIC_VECTOR(to_unsigned(i, 8));
            WAIT FOR CLK_PERIOD;
        END LOOP;
        -- Letztes Byte
        wr_data <= x"FF";
        WAIT FOR CLK_PERIOD;
        WAIT FOR 1 ns;

        ASSERT full = '1'
        REPORT "T7 FAIL: full nicht gesetzt bei vollem FIFO" SEVERITY error;

        wr_en <= '0';
        REPORT "TEST 7 PASSED: Full-Signal";

        -----------------------------------------------------------------------
        REPORT "ALLE TESTS ABGESCHLOSSEN";
        WAIT;
    END PROCESS stim;

END ARCHITECTURE sim;