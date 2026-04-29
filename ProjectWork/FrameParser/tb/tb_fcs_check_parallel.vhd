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

  --------------------------------------------------------------------------
  -- DUT component (ADAPT THIS to your actual parallel entity name/ports)
  --------------------------------------------------------------------------
  component fcs_check_parallel is
    port (
      clk            : in  std_logic;
      reset          : in  std_logic;
      start_of_frame : in  std_logic;
      end_of_frame   : in  std_logic;
      data_in        : in  std_logic_vector(7 downto 0);
      fcs_error      : out std_logic
    );
  end component;

  signal clk            : std_logic := '0';
  signal reset          : std_logic := '1';
  signal start_of_frame : std_logic := '0';
  signal end_of_frame   : std_logic := '0';
  signal data_in        : std_logic_vector(7 downto 0) := (others => '0');
  signal fcs_error      : std_logic;

  constant CLK_PERIOD : time := 10 ns;

  -- Byte array type
  type t_byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

  -- Example Ethernet packet (64 bytes total, last 4 are FCS)
  constant pkt_ok : t_byte_array(0 to 63) := (
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
  constant pkt_bad : t_byte_array(0 to 63) := (
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
    constant pkt : in t_byte_array;
    signal   clk : in std_logic;
    signal   start_of_frame : out std_logic;
    signal   end_of_frame   : out std_logic;
    signal   data_in        : out std_logic_vector(7 downto 0)
  ) is
  begin
    for i in pkt'range loop

      -- start_of_frame on first byte
      if i = pkt'low then
        start_of_frame <= '1';
      else
        start_of_frame <= '0';
      end if;

      -- end_of_frame on last Byte of the whole frame 
      if i = (pkt'high) then
        end_of_frame <= '1';
      else
        end_of_frame <= '0';
      end if;

      data_in <= pkt(i);
      wait until rising_edge(clk);

    end loop;

    -- idle afterwards
    start_of_frame <= '0';
    end_of_frame   <= '0';
    data_in        <= (others => '0');
  end procedure;

begin

  -- Clock generation
  clk <= not clk after CLK_PERIOD/2;

  -- DUT instance
  dut : fcs_check_parallel
    port map (
      clk            => clk,
      reset          => reset,
      start_of_frame => start_of_frame,
      end_of_frame   => end_of_frame,
      data_in        => data_in,
      fcs_error      => fcs_error
    );

  -- Stimulus
  stim : process
  begin
    -- Reset
    reset <= '1';
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);

    -- Test 1: valid
    send_frame(pkt_ok, clk, start_of_frame, end_of_frame, data_in);
    wait for 20 * CLK_PERIOD;

    -- Test 2: corrupt
    send_frame(pkt_bad, clk, start_of_frame, end_of_frame, data_in);
    wait for 20 * CLK_PERIOD;

    -- Test 3: reset + valid again
    reset <= '1';
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);

    send_frame(pkt_ok, clk, start_of_frame, end_of_frame, data_in);
    wait for 20 * CLK_PERIOD;

    wait;
  end process;

end architecture;