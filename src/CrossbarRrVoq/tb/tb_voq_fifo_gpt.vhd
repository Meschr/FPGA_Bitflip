-- =============================================================================
-- Testbench: tb_voq_fifo_gpt
-- Prueft: voq_fifo.vhd  (DEPTH = 16, Datenwortbreite = 8 Bit)
--
-- Was wird getestet:
-- -----------------------------------------------------------------------
-- Reset        | Prueft, dass nach Reset empty='1', full='0',
--              | frame_rdy='0' und rd_valid='0' korrekt anliegen.
--
-- TEST 1       | Einzelnes vollstaendiges Frame (3 Bytes)
--              | - frame_rdy darf erst nach dem letzten Byte (wr_eof='1')
--              |   auf '1' gehen, nicht schon nach dem ersten/zweiten Byte
--              | - Alle 3 Bytes werden der Reihe nach ausgelesen und auf
--              |   korrekten Inhalt, rd_valid und rd_eof geprueft
--              | - Nach dem Lesen: frame_rdy='0', empty='1'
--
-- TEST 2       | Zwei Frames direkt hintereinander (A: 2 Bytes, B: 3 Bytes)
--              | - Beide Frames werden zuerst vollstaendig geschrieben,
--              |   dann Byte fuer Byte ausgelesen
--              | - Prueft, dass frame_rdy nach Frame A noch '1' bleibt
--              |   (Frame B liegt noch im FIFO)
--              | - Nach komplettem Auslesen: frame_rdy='0', empty='1'
--
-- TEST 3       | Unvollstaendiges Frame (kein wr_eof)
--              | - 2 Bytes werden geschrieben, aber wr_eof bleibt '0'
--              | - frame_rdy muss '0' bleiben, da kein Frame abgeschlossen
--
-- TEST 4       | Flush-Funktion
--              | - Ausloesung von flush='1' waehrend das unvollstaendige
--              |   Frame aus TEST 3 noch im FIFO liegt
--              | - Danach: empty='1', frame_rdy='0', rd_valid='0'
--              | - Prueft, dass Flush den FIFO-Inhalt vollstaendig loescht
--
-- TEST 5       | Gleichzeitiges Lesen und Schreiben
--              | - Erst ein 1-Byte-Frame schreiben, dann in einem Takt
--              |   gleichzeitig rd_en='1' und wr_en='1' anlegen
--              | - Prueft, dass der alte Byte korrekt gelesen und der neue
--              |   gleichzeitig eingeschrieben wird (kein Datenverlust)
--              | - Neues Frame wird vervollstaendigt und korrekt ausgelesen
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_voq_fifo_gpt IS
END ENTITY tb_voq_fifo_gpt;

ARCHITECTURE sim OF tb_voq_fifo_gpt IS

    CONSTANT CLK_PERIOD : TIME := 10 ns;
    CONSTANT DEPTH_C : INTEGER := 16;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';
    SIGNAL flush : STD_LOGIC := '0';

    SIGNAL wr_en : STD_LOGIC := '0';
    SIGNAL wr_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL wr_eof : STD_LOGIC := '0';

    SIGNAL rd_en : STD_LOGIC := '0';
    SIGNAL rd_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL rd_eof : STD_LOGIC;
    SIGNAL rd_valid : STD_LOGIC;

    SIGNAL frame_rdy : STD_LOGIC;
    SIGNAL full : STD_LOGIC;
    SIGNAL empty : STD_LOGIC;

    PROCEDURE write_byte(
        SIGNAL clk_s : IN STD_LOGIC;
        SIGNAL wr_en_s : OUT STD_LOGIC;
        SIGNAL wr_data_s : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        SIGNAL wr_eof_s : OUT STD_LOGIC;
        CONSTANT data_c : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        CONSTANT eof_c : IN STD_LOGIC
    ) IS
    BEGIN
        WAIT UNTIL falling_edge(clk_s);
        wr_en_s <= '1';
        wr_data_s <= data_c;
        wr_eof_s <= eof_c;

        WAIT UNTIL rising_edge(clk_s);
        WAIT FOR 1 ns;

        WAIT UNTIL falling_edge(clk_s);
        wr_en_s <= '0';
        wr_data_s <= (OTHERS => '0');
        wr_eof_s <= '0';
    END PROCEDURE;

    PROCEDURE start_continuous_read(
        SIGNAL clk_s : IN STD_LOGIC;
        SIGNAL rd_en_s : OUT STD_LOGIC
    ) IS
    BEGIN
        WAIT UNTIL falling_edge(clk_s);
        rd_en_s <= '1';
    END PROCEDURE;

    PROCEDURE stop_continuous_read(
        SIGNAL clk_s : IN STD_LOGIC;
        SIGNAL rd_en_s : OUT STD_LOGIC
    ) IS
    BEGIN
        WAIT UNTIL falling_edge(clk_s);
        rd_en_s <= '0';
    END PROCEDURE;

    PROCEDURE expect_cycle(
        CONSTANT valid_c : IN STD_LOGIC;
        CONSTANT data_c : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        CONSTANT eof_c : IN STD_LOGIC;
        CONSTANT msg_c : IN STRING
    ) IS
    BEGIN
        ASSERT rd_valid = valid_c
        REPORT "rd_valid mismatch: " & msg_c
            SEVERITY error;

        IF valid_c = '1' THEN
            ASSERT rd_data = data_c
            REPORT "rd_data mismatch: " & msg_c
                SEVERITY error;

            ASSERT rd_eof = eof_c
            REPORT "rd_eof mismatch: " & msg_c
                SEVERITY error;
        END IF;
    END PROCEDURE;

BEGIN

    dut : ENTITY work.voq_fifo
        GENERIC MAP(
            DEPTH => DEPTH_C
        )
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => flush,
            wr_en => wr_en,
            wr_data => wr_data,
            wr_eof => wr_eof,
            rd_en => rd_en,
            rd_data => rd_data,
            rd_eof => rd_eof,
            rd_valid => rd_valid,
            frame_rdy => frame_rdy,
            full => full,
            empty => empty
        );

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    stim_proc : PROCESS
    BEGIN
        REPORT "Starting tb_voq_fifo_gpt" SEVERITY note;

        -----------------------------------------------------------------------
        -- Reset
        -----------------------------------------------------------------------
        reset <= '1';
        flush <= '0';
        wr_en <= '0';
        wr_eof <= '0';
        rd_en <= '0';

        WAIT FOR 3 * CLK_PERIOD;
        WAIT UNTIL falling_edge(clk);
        reset <= '0';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        ASSERT empty = '1' REPORT "FIFO should be empty after reset" SEVERITY error;
        ASSERT full = '0' REPORT "FIFO should not be full after reset" SEVERITY error;
        ASSERT frame_rdy = '0' REPORT "frame_rdy should be 0 after reset" SEVERITY error;
        ASSERT rd_valid = '0' REPORT "rd_valid should be 0 after reset" SEVERITY error;

        -----------------------------------------------------------------------
        -- TEST 1: Single complete frame, continuous read without gaps
        -----------------------------------------------------------------------
        REPORT "TEST 1: Single complete frame continuous read" SEVERITY note;

        write_byte(clk, wr_en, wr_data, wr_eof, x"11", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"22", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"33", '1');

        ASSERT frame_rdy = '1'
        REPORT "frame_rdy should be 1 after complete frame written"
            SEVERITY error;

        start_continuous_read(clk, rd_en);

        -- first cycle after asserting rd_en: pipeline fill
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"11", '0', "TEST 1 / byte 1");

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"22", '0', "TEST 1 / byte 2");

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"33", '1', "TEST 1 / byte 3");

        stop_continuous_read(clk, rd_en);

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT frame_rdy = '0'
        REPORT "frame_rdy should return to 0 after frame has been read"
            SEVERITY error;
        ASSERT empty = '1'
        REPORT "FIFO should be empty after TEST 1"
            SEVERITY error;

        -----------------------------------------------------------------------
        -- TEST 2: Two frames back-to-back, each read continuously
        -----------------------------------------------------------------------
        REPORT "TEST 2: Two frames back-to-back continuous read" SEVERITY note;

        write_byte(clk, wr_en, wr_data, wr_eof, x"A1", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"A2", '1');

        write_byte(clk, wr_en, wr_data, wr_eof, x"B1", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"B2", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"B3", '1');

        ASSERT frame_rdy = '1'
        REPORT "frame_rdy should be 1 when frames are stored"
            SEVERITY error;

        start_continuous_read(clk, rd_en);

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"A1", '0', "TEST 2 / frame A byte 1");

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"A2", '1', "TEST 2 / frame A byte 2");

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"B1", '0', "TEST 2 / frame B byte 1");

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"B2", '0', "TEST 2 / frame B byte 2");

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"B3", '1', "TEST 2 / frame B byte 3");

        stop_continuous_read(clk, rd_en);

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT frame_rdy = '0'
        REPORT "frame_rdy should be 0 after both frames are read"
            SEVERITY error;
        ASSERT empty = '1'
        REPORT "FIFO should be empty after TEST 2"
            SEVERITY error;

        -----------------------------------------------------------------------
        -- TEST 3: Incomplete frame must not raise frame_rdy
        -----------------------------------------------------------------------
        REPORT "TEST 3: Incomplete frame" SEVERITY note;

        write_byte(clk, wr_en, wr_data, wr_eof, x"C1", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"C2", '0');

        ASSERT frame_rdy = '0'
        REPORT "frame_rdy must remain 0 for incomplete frame"
            SEVERITY error;

        -----------------------------------------------------------------------
        -- TEST 4: Flush
        -----------------------------------------------------------------------
        REPORT "TEST 4: Flush" SEVERITY note;

        WAIT UNTIL falling_edge(clk);
        flush <= '1';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        WAIT UNTIL falling_edge(clk);
        flush <= '0';

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        ASSERT empty = '1'
        REPORT "FIFO should be empty after flush"
            SEVERITY error;
        ASSERT frame_rdy = '0'
        REPORT "frame_rdy should be 0 after flush"
            SEVERITY error;
        ASSERT rd_valid = '0'
        REPORT "rd_valid should be 0 after flush"
            SEVERITY error;

        -----------------------------------------------------------------------
        -- TEST 5: Simultaneous read and write
        -----------------------------------------------------------------------
        REPORT "TEST 5: Simultaneous read and write" SEVERITY note;

        write_byte(clk, wr_en, wr_data, wr_eof, x"D1", '1');
        ASSERT frame_rdy = '1'
        REPORT "frame_rdy should be 1 before simultaneous read/write test"
            SEVERITY error;

        -- One cycle: read D1 while writing E1
        WAIT UNTIL falling_edge(clk);
        rd_en <= '1';
        wr_en <= '1';
        wr_data <= x"E1";
        wr_eof <= '0';

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"D1", '1', "TEST 5 / simultaneous cycle");

        -- IMPORTANT: stop read immediately so E1 is not consumed in next cycle
        WAIT UNTIL falling_edge(clk);
        rd_en <= '0';
        wr_en <= '0';
        wr_data <= (OTHERS => '0');
        wr_eof <= '0';

        -- now check status after simultaneous read/write
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT frame_rdy = '0'
        REPORT "frame_rdy should be 0 because only incomplete frame remains"
            SEVERITY error;
        ASSERT empty = '0'
        REPORT "FIFO should not be empty because one byte remains stored"
            SEVERITY error;

        -- Finish the new frame
        write_byte(clk, wr_en, wr_data, wr_eof, x"E2", '1');
        ASSERT frame_rdy = '1'
        REPORT "frame_rdy should be 1 after completing new frame"
            SEVERITY error;

        start_continuous_read(clk, rd_en);

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"E1", '0', "TEST 5 / frame E byte 1");

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        expect_cycle('1', x"E2", '1', "TEST 5 / frame E byte 2");

        stop_continuous_read(clk, rd_en);

        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT empty = '1'
        REPORT "FIFO should be empty after TEST 5"
            SEVERITY error;
        ASSERT frame_rdy = '0'
        REPORT "frame_rdy should be 0 after TEST 5"
            SEVERITY error;

        REPORT "All tests in tb_voq_fifo_gpt passed." SEVERITY note;
        WAIT;
    END PROCESS;

END ARCHITECTURE sim;