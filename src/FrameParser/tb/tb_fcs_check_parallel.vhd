-- ============================================================
-- Testbench: Parallel (byte-wise) stimulus for Ethernet FCS checker
-- Only change vs. serial TB: send BYTES (8-bit) per clock.
-- start_of_frame pulses on first BYTE.
-- end_of_frame pulses on first FCS BYTE (byte 60 here).
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fcs_check_parallel is
end entity;

architecture sim of tb_fcs_check_parallel is

  signal clk            : STD_LOGIC                    := '0';
  signal reset          : STD_LOGIC                    := '1';
  signal start_of_frame : STD_LOGIC                    := '0';
  signal end_of_frame   : STD_LOGIC                    := '0';
  signal data_in        : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
  signal fcs_error      : STD_LOGIC;
  signal fcs_ok         : STD_LOGIC;
  signal data_out       : STD_LOGIC_VECTOR(7 downto 0);
  signal wr_en          : STD_LOGIC;
  signal eof_out        : STD_LOGIC;

  constant CLK_PERIOD : TIME := 10 ns;

  -- Byte array type
  type t_byte_array is array (NATURAL range <>) of STD_LOGIC_VECTOR(7 downto 0);

  -- Example Ethernet packet (64 bytes total, last 4 are FCS)
  constant PKT_OK : t_byte_array(0 to 63) := (
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
  constant PKT_BAD : t_byte_array(0 to 63) := (
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
  procedure send_frame(
    constant pkt        : in t_byte_array;
    signal clk_i        : in STD_LOGIC;
    signal sof_o        : out STD_LOGIC;
    signal eof_o        : out STD_LOGIC;
    signal data_in_o    : out STD_LOGIC_VECTOR(7 downto 0);
    constant label_text : in STRING
  ) is
  begin
    for i in pkt'range loop

      -- start_of_frame on first byte
      if i = pkt'low then
        sof_o <= '1';
      else
        sof_o <= '0';
      end if;

      -- end_of_frame on last Byte of the whole frame 
      if i = (pkt'high) then
        eof_o <= '1';
      else
        eof_o <= '0';
      end if;

      data_in_o <= pkt(i);
      wait until rising_edge(clk_i);
      wait for 0 ns;

      if i < pkt'high then
        assert wr_en = '1'
        report label_text & ": wr_en not asserted during frame data"
          severity error;
        assert eof_out = '0'
        report label_text & ": eof_out asserted too early"
          severity error;
      end if;

    end loop;

    assert wr_en = '0'
    report label_text & ": wr_en must deassert on end_of_frame"
      severity error;
    assert eof_out = '1'
    report label_text & ": eof_out not asserted at frame end"
      severity error;
    assert ((fcs_ok = '1' and fcs_error = '0') or (fcs_ok = '0' and fcs_error = '1'))
    report label_text & ": expected exactly one of fcs_ok/fcs_error high at frame end"
      severity error;

    -- idle afterwards
    sof_o     <= '0';
    eof_o     <= '0';
    data_in_o <= (others => '0');
  end procedure;

begin

  -- Clock generation
  clk <= not clk after CLK_PERIOD/2;

  -- DUT instance
  dut : entity work.fcs_check_parallel
    port map(
      clk            => clk,
      reset          => reset,
      start_of_frame => start_of_frame,
      end_of_frame   => end_of_frame,
      data_in        => data_in,
      fcs_error      => fcs_error,
      fcs_ok         => fcs_ok,
      data_out       => data_out,
      wr_en          => wr_en,
      eof_out        => eof_out
    );

  -- Stimulus
  stim : process
  begin
    -- Reset
    reset          <= '0';
    start_of_frame <= '0';
    end_of_frame   <= '0';
    data_in        <= (others => '0');
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '1';
    wait until rising_edge(clk);

    -- Test 1
    send_frame(PKT_OK, clk, start_of_frame, end_of_frame, data_in, "packet 1");
    wait for 4 * CLK_PERIOD;

    -- Test 2
    send_frame(PKT_BAD, clk, start_of_frame, end_of_frame, data_in, "packet 2");
    wait for 4 * CLK_PERIOD;

    -- Test 3: reset + valid again
    reset <= '0';
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '1';
    wait until rising_edge(clk);

    send_frame(PKT_OK, clk, start_of_frame, end_of_frame, data_in, "packet 3 after reset");

    wait;
  end process;

end architecture;
