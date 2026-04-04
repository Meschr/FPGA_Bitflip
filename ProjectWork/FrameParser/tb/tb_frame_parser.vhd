library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac_pkg.all;

entity tb_frame_parser is
end entity tb_frame_parser;

architecture sim of tb_frame_parser is

  signal clk         : std_logic := '0';
  signal reset       : std_logic := '1';
  signal data_in     : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid  : std_logic := '0';
  signal header_done : std_logic := '0';
  signal drop_frame  : std_logic := '0';

  signal sof         : std_logic;
  signal eof         : std_logic;
  signal lof         : std_logic;
  signal dst_mac     : mac_addr_t;
  signal src_mac     : mac_addr_t;
  signal mac_valid   : std_logic;
  signal ethertype   : std_logic_vector(15 downto 0);

  -- -------------------------------------------------------
  -- Takt: 10 ns Periode = 100 MHz
  -- -------------------------------------------------------
  constant CLK_PERIOD : time := 10 ns;

  type byte_array_t is array(natural range <>) of std_logic_vector(7 downto 0);

  constant PREAMBLE_AND_SFD : byte_array_t(0 to 7) := (
    x"55", x"55", x"55", x"55", x"55", x"55", x"55", x"D5"
  );

  constant HEADER : byte_array_t(0 to 13) := (
    x"AA", x"BB", x"CC", x"DD", x"EE", x"FF",  -- dst MAC
    x"11", x"22", x"33", x"44", x"55", x"66",  -- src MAC
    x"08", x"00"                                     -- EtherType
  );

  constant EXP_DST : mac_addr_t := x"AABBCCDDEEFF";
  constant EXP_SRC : mac_addr_t := x"112233445566";
  constant EXP_ETH : std_logic_vector(15 downto 0) := x"0800";

  -- -------------------------------------------------------
  -- Hilfsprozedur: Byte senden
  -- -------------------------------------------------------
  procedure send_byte (
    signal clk   : in  std_logic;
    signal dout  : out std_logic_vector(7 downto 0);
    signal dv    : out std_logic;
    constant val : in  std_logic_vector(7 downto 0)
  ) is
  begin
    dout <= val;
    dv   <= '1';
    wait until rising_edge(clk);
    dv   <= '0';
  end procedure;

  procedure send_stream (
    signal clk   : in  std_logic;
    signal dout  : out std_logic_vector(7 downto 0);
    signal dv    : out std_logic;
    constant arr : in  byte_array_t
  ) is
  begin
    for i in arr'range loop
      send_byte(clk, dout, dv, arr(i));
      wait for CLK_PERIOD;
    end loop;
  end procedure;

begin

  -- -------------------------------------------------------
  -- DUT Instanz
  -- -------------------------------------------------------
  DUT : entity work.frame_parser
    port map (
      clk         => clk,
      reset       => reset,
      data_in     => data_in,
      data_valid  => data_valid,
      header_done => header_done,
      drop_frame  => drop_frame,
      sof         => sof,
      eof         => eof,
      lof         => lof,
      dst_mac     => dst_mac,
      src_mac     => src_mac,
      mac_valid   => mac_valid,
      ethertype   => ethertype
    );

  -- -------------------------------------------------------
  -- Taktezeugung
  -- -------------------------------------------------------
  p_clk : process
  begin
    clk <= '0'; wait for CLK_PERIOD / 2;
    clk <= '1'; wait for CLK_PERIOD / 2;
  end process;

  -- -------------------------------------------------------
  -- Stimuli
  -- -------------------------------------------------------
  p_stim : process
  begin
    -- Hold reset
    reset <= '1';
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait for CLK_PERIOD;

    report "=== Test 1: valid preamble + header ===";
    send_stream(clk, data_in, data_valid, PREAMBLE_AND_SFD);
    send_stream(clk, data_in, data_valid, HEADER);

    for i in 0 to 8 loop
      wait until rising_edge(clk);
      if mac_valid = '1' then
        assert dst_mac = EXP_DST
          report "ERROR dst_mac Test 1: got " & to_hstring(dst_mac) &
                 " expected " & to_hstring(EXP_DST)
          severity error;

        assert src_mac = EXP_SRC
          report "ERROR src_mac Test 1: got " & to_hstring(src_mac) &
                 " expected " & to_hstring(EXP_SRC)
          severity error;

        assert ethertype = EXP_ETH
          report "ERROR ethertype Test 1"
          severity error;

        assert eof = '1'
          report "ERROR eof not asserted with mac_valid in Test 1"
          severity error;

        assert lof = '1'
          report "ERROR lof not asserted with mac_valid in Test 1"
          severity error;

        report "Test 1 PASSED";
        exit;
      end if;
      if i = 8 then
        report "ERROR: mac_valid never asserted in Test 1" severity error;
      end if;
    end loop;

    -- Clear DONE state through header_done pulse.
    header_done <= '1';
    wait until rising_edge(clk);
    header_done <= '0';

    wait for 3 * CLK_PERIOD;

    report "=== Test 2: invalid SFD must not parse ===";
    for i in 0 to 6 loop
      send_byte(clk, data_in, data_valid, x"55");
      wait for CLK_PERIOD;
    end loop;
    send_byte(clk, data_in, data_valid, x"D4");
    wait for CLK_PERIOD;

    send_stream(clk, data_in, data_valid, HEADER);

    for i in 0 to 12 loop
      wait until rising_edge(clk);
      if mac_valid = '1' then
        report "ERROR: parser accepted invalid SFD in Test 2" severity error;
      end if;
    end loop;
    report "Test 2 PASSED";

    wait for 3 * CLK_PERIOD;

    report "=== Test 3: reset during frame and recovery ===";
    send_stream(clk, data_in, data_valid, PREAMBLE_AND_SFD);

    for i in 0 to 3 loop
      send_byte(clk, data_in, data_valid, HEADER(i));
      wait for CLK_PERIOD;
    end loop;

    reset <= '1';
    wait for 2 * CLK_PERIOD;
    reset <= '0';
    wait for CLK_PERIOD;

    send_stream(clk, data_in, data_valid, PREAMBLE_AND_SFD);
    send_stream(clk, data_in, data_valid, HEADER);

    for i in 0 to 8 loop
      wait until rising_edge(clk);
      if mac_valid = '1' then
        assert dst_mac = EXP_DST
          report "ERROR dst_mac Test 3" severity error;
        assert src_mac = EXP_SRC
          report "ERROR src_mac Test 3" severity error;
        assert ethertype = EXP_ETH
          report "ERROR ethertype Test 3" severity error;
        report "Test 3 PASSED";
        exit;
      end if;
      if i = 8 then
        report "ERROR: mac_valid never asserted in Test 3" severity error;
      end if;
    end loop;

    wait for 5 * CLK_PERIOD;
    report "=== All tests completed ===" severity note;
    std.env.stop;
  end process;

end architecture sim;
