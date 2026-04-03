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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_voq_fifo_gpt is
end entity tb_voq_fifo_gpt;

architecture sim of tb_voq_fifo_gpt is

    constant CLK_PERIOD : time := 10 ns;
    constant DEPTH_C    : integer := 16;

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal flush     : std_logic := '0';

    signal wr_en     : std_logic := '0';
    signal wr_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof    : std_logic := '0';

    signal rd_en     : std_logic := '0';
    signal rd_data   : std_logic_vector(7 downto 0);
    signal rd_eof    : std_logic;
    signal rd_valid  : std_logic;

    signal frame_rdy : std_logic;
    signal full      : std_logic;
    signal empty     : std_logic;

    procedure write_byte(
        signal clk_s     : in  std_logic;
        signal wr_en_s   : out std_logic;
        signal wr_data_s : out std_logic_vector(7 downto 0);
        signal wr_eof_s  : out std_logic;
        constant data_c  : in  std_logic_vector(7 downto 0);
        constant eof_c   : in  std_logic
    ) is
    begin
        wait until falling_edge(clk_s);
        wr_en_s   <= '1';
        wr_data_s <= data_c;
        wr_eof_s  <= eof_c;

        wait until rising_edge(clk_s);
        wait for 1 ns;

        wait until falling_edge(clk_s);
        wr_en_s   <= '0';
        wr_data_s <= (others => '0');
        wr_eof_s  <= '0';
    end procedure;

    procedure start_continuous_read(
        signal clk_s   : in  std_logic;
        signal rd_en_s : out std_logic
    ) is
    begin
        wait until falling_edge(clk_s);
        rd_en_s <= '1';
    end procedure;

    procedure stop_continuous_read(
        signal clk_s   : in  std_logic;
        signal rd_en_s : out std_logic
    ) is
    begin
        wait until falling_edge(clk_s);
        rd_en_s <= '0';
    end procedure;

    procedure expect_cycle(
        constant valid_c : in std_logic;
        constant data_c  : in std_logic_vector(7 downto 0);
        constant eof_c   : in std_logic;
        constant msg_c   : in string
    ) is
    begin
        assert rd_valid = valid_c
            report "rd_valid mismatch: " & msg_c
            severity error;

        if valid_c = '1' then
            assert rd_data = data_c
                report "rd_data mismatch: " & msg_c
                severity error;

            assert rd_eof = eof_c
                report "rd_eof mismatch: " & msg_c
                severity error;
        end if;
    end procedure;

begin

    dut : entity work.voq_fifo
        generic map (
            DEPTH => DEPTH_C
        )
        port map (
            clk       => clk,
            reset     => reset,
            flush     => flush,
            wr_en     => wr_en,
            wr_data   => wr_data,
            wr_eof    => wr_eof,
            rd_en     => rd_en,
            rd_data   => rd_data,
            rd_eof    => rd_eof,
            rd_valid  => rd_valid,
            frame_rdy => frame_rdy,
            full      => full,
            empty     => empty
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim_proc : process
    begin
        report "Starting tb_voq_fifo_gpt" severity note;

        -----------------------------------------------------------------------
        -- Reset
        -----------------------------------------------------------------------
        reset <= '1';
        flush <= '0';
        wr_en <= '0';
        wr_eof <= '0';
        rd_en <= '0';

        wait for 3 * CLK_PERIOD;
        wait until falling_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert empty = '1' report "FIFO should be empty after reset" severity error;
        assert full = '0' report "FIFO should not be full after reset" severity error;
        assert frame_rdy = '0' report "frame_rdy should be 0 after reset" severity error;
        assert rd_valid = '0' report "rd_valid should be 0 after reset" severity error;

        -----------------------------------------------------------------------
        -- TEST 1: Single complete frame, continuous read without gaps
        -----------------------------------------------------------------------
        report "TEST 1: Single complete frame continuous read" severity note;

        write_byte(clk, wr_en, wr_data, wr_eof, x"11", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"22", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"33", '1');

        assert frame_rdy = '1'
            report "frame_rdy should be 1 after complete frame written"
            severity error;

        start_continuous_read(clk, rd_en);

        -- first cycle after asserting rd_en: pipeline fill
        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"11", '0', "TEST 1 / byte 1");

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"22", '0', "TEST 1 / byte 2");

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"33", '1', "TEST 1 / byte 3");

        stop_continuous_read(clk, rd_en);

        wait until rising_edge(clk);
        wait for 1 ns;
        assert frame_rdy = '0'
            report "frame_rdy should return to 0 after frame has been read"
            severity error;
        assert empty = '1'
            report "FIFO should be empty after TEST 1"
            severity error;

        -----------------------------------------------------------------------
        -- TEST 2: Two frames back-to-back, each read continuously
        -----------------------------------------------------------------------
        report "TEST 2: Two frames back-to-back continuous read" severity note;

        write_byte(clk, wr_en, wr_data, wr_eof, x"A1", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"A2", '1');

        write_byte(clk, wr_en, wr_data, wr_eof, x"B1", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"B2", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"B3", '1');

        assert frame_rdy = '1'
            report "frame_rdy should be 1 when frames are stored"
            severity error;

        start_continuous_read(clk, rd_en);

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"A1", '0', "TEST 2 / frame A byte 1");

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"A2", '1', "TEST 2 / frame A byte 2");

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"B1", '0', "TEST 2 / frame B byte 1");

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"B2", '0', "TEST 2 / frame B byte 2");

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"B3", '1', "TEST 2 / frame B byte 3");

        stop_continuous_read(clk, rd_en);

        wait until rising_edge(clk);
        wait for 1 ns;
        assert frame_rdy = '0'
            report "frame_rdy should be 0 after both frames are read"
            severity error;
        assert empty = '1'
            report "FIFO should be empty after TEST 2"
            severity error;

        -----------------------------------------------------------------------
        -- TEST 3: Incomplete frame must not raise frame_rdy
        -----------------------------------------------------------------------
        report "TEST 3: Incomplete frame" severity note;

        write_byte(clk, wr_en, wr_data, wr_eof, x"C1", '0');
        write_byte(clk, wr_en, wr_data, wr_eof, x"C2", '0');

        assert frame_rdy = '0'
            report "frame_rdy must remain 0 for incomplete frame"
            severity error;

        -----------------------------------------------------------------------
        -- TEST 4: Flush
        -----------------------------------------------------------------------
        report "TEST 4: Flush" severity note;

        wait until falling_edge(clk);
        flush <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        wait until falling_edge(clk);
        flush <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert empty = '1'
            report "FIFO should be empty after flush"
            severity error;
        assert frame_rdy = '0'
            report "frame_rdy should be 0 after flush"
            severity error;
        assert rd_valid = '0'
            report "rd_valid should be 0 after flush"
            severity error;

        -----------------------------------------------------------------------
        -- TEST 5: Simultaneous read and write
        -----------------------------------------------------------------------
        report "TEST 5: Simultaneous read and write" severity note;

        write_byte(clk, wr_en, wr_data, wr_eof, x"D1", '1');
        assert frame_rdy = '1'
            report "frame_rdy should be 1 before simultaneous read/write test"
            severity error;

        -- One cycle: read D1 while writing E1
        wait until falling_edge(clk);
        rd_en   <= '1';
        wr_en   <= '1';
        wr_data <= x"E1";
        wr_eof  <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"D1", '1', "TEST 5 / simultaneous cycle");

        -- IMPORTANT: stop read immediately so E1 is not consumed in next cycle
        wait until falling_edge(clk);
        rd_en   <= '0';
        wr_en   <= '0';
        wr_data <= (others => '0');
        wr_eof  <= '0';

        -- now check status after simultaneous read/write
        wait until rising_edge(clk);
        wait for 1 ns;
        assert frame_rdy = '0'
            report "frame_rdy should be 0 because only incomplete frame remains"
            severity error;
        assert empty = '0'
            report "FIFO should not be empty because one byte remains stored"
            severity error;

        -- Finish the new frame
        write_byte(clk, wr_en, wr_data, wr_eof, x"E2", '1');
        assert frame_rdy = '1'
            report "frame_rdy should be 1 after completing new frame"
            severity error;

        start_continuous_read(clk, rd_en);

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"E1", '0', "TEST 5 / frame E byte 1");

        wait until rising_edge(clk);
        wait for 1 ns;
        expect_cycle('1', x"E2", '1', "TEST 5 / frame E byte 2");

        stop_continuous_read(clk, rd_en);

        wait until rising_edge(clk);
        wait for 1 ns;
        assert empty = '1'
            report "FIFO should be empty after TEST 5"
            severity error;
        assert frame_rdy = '0'
            report "frame_rdy should be 0 after TEST 5"
            severity error;

        report "All tests in tb_voq_fifo_gpt passed." severity note;
        wait;
    end process;

end architecture sim;