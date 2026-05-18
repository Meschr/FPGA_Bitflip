-- ============================================================
-- Testbench: Parallel (byte-wise) stimulus for Ethernet FCS checker
-- Only change vs. serial TB: send BYTES (8-bit) per clock.
-- start_of_frame pulses on first BYTE.
-- end_of_frame pulses on first FCS BYTE (byte 60 here).
-- ============================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_fcs_check_parallel IS
END ENTITY;

ARCHITECTURE sim OF tb_fcs_check_parallel IS

  SIGNAL clk : STD_LOGIC := '0';
  SIGNAL reset : STD_LOGIC := '1';
  SIGNAL start_of_frame : STD_LOGIC := '0';
  SIGNAL end_of_frame : STD_LOGIC := '0';
  SIGNAL data_in : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL fcs_error : STD_LOGIC;
  SIGNAL fcs_ok : STD_LOGIC;
  SIGNAL data_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL wr_en : STD_LOGIC;
  SIGNAL eof_out : STD_LOGIC;

  CONSTANT CLK_PERIOD : TIME := 10 ns;

  -- Byte array type
  TYPE t_byte_array IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

  -- Example Ethernet packet (64 bytes total, last 4 are FCS)
  CONSTANT pkt_ok : t_byte_array(0 to 63) := (
    x"00", x"10", x"A4", x"7B", x"EA", x"80", x"00", x"12",
    x"34", x"56", x"78", x"90", x"08", x"00", x"45", x"00",
    x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", x"11",
    x"05", x"40", x"C0", x"A8", x"00", x"2C", x"C0", x"A8",
    x"00", x"04", x"04", x"00", x"04", x"00", x"00", x"1A",
    x"2D", x"E8", x"00", x"01", x"02", x"03", x"04", x"05",
    x"06", x"07", x"08", x"09", x"0A", x"0B", x"0C", x"0D",
    x"0E", x"0F", x"10", x"11",
    -- FCS
    x"E6", x"C5", x"3D", x"B2"
  );

  -- Corrupt packet: change one byte but KEEP same FCS => must error
  CONSTANT pkt_bad : t_byte_array(0 to 63) := (
    x"00", x"10", x"A4", x"7B", x"EA", x"80", x"00", x"12",
    x"34", x"56", x"79", x"90", x"08", x"00", x"45", x"00", -- 0x78 -> 0x79
    x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", x"11",
    x"05", x"40", x"C0", x"A8", x"00", x"2C", x"C0", x"A8",
    x"00", x"04", x"04", x"00", x"04", x"00", x"00", x"1A",
    x"2D", x"E8", x"00", x"01", x"02", x"03", x"04", x"05",
    x"06", x"07", x"08", x"09", x"0A", x"0B", x"0C", x"0D",
    x"0E", x"0F", x"10", x"11",
    -- same FCS as pkt_ok
    x"E6", x"C5", x"3D", x"B2"
  );

  -- Send frame procedure: byte per rising edge
  PROCEDURE send_frame(
    CONSTANT pkt : IN t_byte_array;
    SIGNAL clk_i : IN STD_LOGIC;
    SIGNAL sof_o : OUT STD_LOGIC;
    SIGNAL eof_o : OUT STD_LOGIC;
    SIGNAL data_in_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    CONSTANT label_text : IN STRING
  ) IS
  BEGIN
    FOR i IN pkt'RANGE LOOP

      -- start_of_frame on first byte
      IF i = pkt'low THEN
        sof_o <= '1';
      ELSE
        sof_o <= '0';
      END IF;

      -- end_of_frame on last Byte of the whole frame 
      IF i = (pkt'high) THEN
        eof_o <= '1';
      ELSE
        eof_o <= '0';
      END IF;

      data_in_o <= pkt(i);
      WAIT UNTIL rising_edge(clk_i);
      WAIT FOR 0 ns;

      IF i < pkt'high THEN
        ASSERT wr_en = '1'
          REPORT label_text & ": wr_en not asserted during frame data"
          SEVERITY error;
        ASSERT eof_out = '0'
          REPORT label_text & ": eof_out asserted too early"
          SEVERITY error;
      END IF;

    END LOOP;

    ASSERT wr_en = '0'
      REPORT label_text & ": wr_en must deassert on end_of_frame"
      SEVERITY error;
    ASSERT eof_out = '1'
      REPORT label_text & ": eof_out not asserted at frame end"
      SEVERITY error;
    ASSERT ((fcs_ok = '1' AND fcs_error = '0') OR (fcs_ok = '0' AND fcs_error = '1'))
      REPORT label_text & ": expected exactly one of fcs_ok/fcs_error high at frame end"
      SEVERITY error;

    -- idle afterwards
    sof_o <= '0';
    eof_o <= '0';
    data_in_o <= (OTHERS => '0');
  END PROCEDURE;

BEGIN

  -- Clock generation
  clk <= NOT clk AFTER CLK_PERIOD/2;

  -- DUT instance
  dut : ENTITY work.fcs_check_parallel
  PORT MAP(
    clk => clk,
    reset => reset,
    start_of_frame => start_of_frame,
    end_of_frame => end_of_frame,
    data_in => data_in,
    fcs_error => fcs_error,
    fcs_ok => fcs_ok,
    data_out => data_out,
    wr_en => wr_en,
    eof_out => eof_out
  );

  -- Stimulus
  stim : PROCESS
  BEGIN
    -- Reset
    reset <= '0';
    start_of_frame <= '0';
    end_of_frame <= '0';
    data_in <= (OTHERS => '0');
    WAIT FOR 5 * CLK_PERIOD;
    WAIT UNTIL rising_edge(clk);
    reset <= '1';
    WAIT UNTIL rising_edge(clk);

    -- Test 1
    send_frame(pkt_ok, clk, start_of_frame, end_of_frame, data_in, "packet 1");
    WAIT FOR 4 * CLK_PERIOD;

    -- Test 2
    send_frame(pkt_bad, clk, start_of_frame, end_of_frame, data_in, "packet 2");
    WAIT FOR 4 * CLK_PERIOD;

    -- Test 3: reset + valid again
    reset <= '0';
    WAIT FOR 5 * CLK_PERIOD;
    WAIT UNTIL rising_edge(clk);
    reset <= '1';
    WAIT UNTIL rising_edge(clk);

    send_frame(pkt_ok, clk, start_of_frame, end_of_frame, data_in, "packet 3 after reset");

    WAIT;
  END PROCESS;

END ARCHITECTURE;