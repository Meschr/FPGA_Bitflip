library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_frame_handler is
end entity tb_frame_handler;

architecture sim of tb_frame_handler is
  constant CLK_PERIOD : time := 10 ns;

  signal clk         : std_logic := '0';
  signal reset       : std_logic := '1';
  signal data_in     : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid  : std_logic := '0';

  signal data_out    : std_logic_vector(7 downto 0);
  signal dst_mac     : std_logic_vector(47 downto 0);
  signal dst_valid   : std_logic;
  signal src_mac     : std_logic_vector(47 downto 0);
  signal src_valid   : std_logic;
  signal crc_valid   : std_logic;

  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

  constant PREAMBLE : byte_array_t(0 to 6) := (
    x"55", x"55", x"55", x"55", x"55", x"55", x"55"
  );

  constant SFD : std_logic_vector(7 downto 0) := x"D5";

  -- Valid Ethernet packet from tb_fcs_check_parallel (64 bytes: 60 payload + 4 FCS)
  -- DST=00:10:A4:7B:EA:80, SRC=00:12:34:56:78:90, EtherType=0x0800 (IPv4)
  -- Payload length = 46 bytes (0x002E in EtherType field), plus 4 FCS = 50 bytes total
  constant PKT_OK : byte_array_t(0 to 63) := (
    -- DST (6 bytes)
    x"00", x"10", x"A4", x"7B", x"EA", x"80",
    -- SRC (6 bytes)
    x"00", x"12", x"34", x"56", x"78", x"90",
    -- EtherType (2 bytes) - 0x0800 = IPv4
    x"08", x"00",
    -- Payload (46 bytes)
    x"45", x"00", x"00", x"2E", x"B3", x"FE", x"00", x"00",
    x"80", x"11", x"05", x"40", x"C0", x"A8", x"00", x"2C",
    x"C0", x"A8", x"00", x"04", x"04", x"00", x"04", x"00",
    x"00", x"1A", x"2D", x"E8", x"00", x"01", x"02", x"03",
    x"04", x"05", x"06", x"07", x"08", x"09", x"0A", x"0B",
    x"0C", x"0D", x"0E", x"0F", x"10", x"11",
    -- FCS (4 bytes)
    x"E6", x"C5", x"3D", x"B2"
  );

  -- Corrupted packet: change one byte in payload but keep same FCS (should trigger CRC error)
  constant PKT_BAD : byte_array_t(0 to 63) := (
    -- DST (6 bytes)
    x"00", x"10", x"A4", x"7B", x"EA", x"80",
    -- SRC (6 bytes) - byte 4 changed from 0x78 to 0x79
    x"00", x"12", x"34", x"56", x"79", x"90",
    -- EtherType (2 bytes) - 0x0800 = IPv4
    x"08", x"00",
    -- Payload (46 bytes)
    x"45", x"00", x"00", x"2E", x"B3", x"FE", x"00", x"00",
    x"80", x"11", x"05", x"40", x"C0", x"A8", x"00", x"2C",
    x"C0", x"A8", x"00", x"04", x"04", x"00", x"04", x"00",
    x"00", x"1A", x"2D", x"E8", x"00", x"01", x"02", x"03",
    x"04", x"05", x"06", x"07", x"08", x"09", x"0A", x"0B",
    x"0C", x"0D", x"0E", x"0F", x"10", x"11",
    -- Same FCS as pkt_ok (4 bytes)
    x"E6", x"C5", x"3D", x"B2"
  );

  function bytes_to_mac(arr : byte_array_t(0 to 5)) return std_logic_vector is
    variable tmp : std_logic_vector(47 downto 0);
  begin
    tmp(47 downto 40) := arr(0);
    tmp(39 downto 32) := arr(1);
    tmp(31 downto 24) := arr(2);
    tmp(23 downto 16) := arr(3);
    tmp(15 downto 8)  := arr(4);
    tmp(7 downto 0)   := arr(5);
    return tmp;
  end function;

  procedure sample_flags(
    signal dst_valid_i : in std_logic;
    signal src_valid_i : in std_logic;
    signal crc_valid_i : in std_logic;
    variable saw_mac_valid : inout boolean;
    variable saw_crc_error : inout boolean
  ) is
  begin
    if dst_valid_i = '1' and src_valid_i = '1' then
      saw_mac_valid := true;
    end if;

    -- frame_handler maps crc_valid <= not fcs_error,
    -- so crc_valid='0' means CRC error detected.
    if crc_valid_i = '0' then
      saw_crc_error := true;
    end if;
  end procedure;

  procedure send_packet_with_preamble(
    signal clk_i        : in std_logic;
    signal din_o        : out std_logic_vector(7 downto 0);
    signal dv_o         : out std_logic;
    signal dst_valid_i  : in std_logic;
    signal src_valid_i  : in std_logic;
    signal crc_valid_i  : in std_logic;
    constant preamble_i : in byte_array_t(0 to 6);
    constant sfd_i      : in std_logic_vector(7 downto 0);
    constant pkt        : in byte_array_t;
    variable saw_mac_valid : inout boolean;
    variable saw_crc_error : inout boolean
  ) is
  begin
    -- Send preamble
    for i in preamble_i'range loop
      din_o <= preamble_i(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
      sample_flags(dst_valid_i, src_valid_i, crc_valid_i, saw_mac_valid, saw_crc_error);
    end loop;

    -- Send SFD
    din_o <= sfd_i;
    dv_o  <= '1';
    wait until rising_edge(clk_i);
    sample_flags(dst_valid_i, src_valid_i, crc_valid_i, saw_mac_valid, saw_crc_error);

    -- Send complete packet (DST + SRC + EtherType + Payload + FCS)
    for i in pkt'range loop
      din_o <= pkt(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
      sample_flags(dst_valid_i, src_valid_i, crc_valid_i, saw_mac_valid, saw_crc_error);
    end loop;

    -- End transmission
    dv_o  <= '0';
    din_o <= (others => '0');
    wait until rising_edge(clk_i);
    sample_flags(dst_valid_i, src_valid_i, crc_valid_i, saw_mac_valid, saw_crc_error);
  end procedure;

begin

  dut : entity work.frame_handler
    port map (
      clk        => clk,
      reset      => reset,
      data_in    => data_in,
      data_valid => data_valid,
      data_out   => data_out,
      dst_mac    => dst_mac,
      dst_valid  => dst_valid,
      src_mac    => src_mac,
      src_valid  => src_valid,
      crc_valid  => crc_valid
    );

  p_clk : process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  p_stim : process
    variable exp_dst_ok : std_logic_vector(47 downto 0);
    variable exp_src_ok : std_logic_vector(47 downto 0);
    variable exp_dst_bad : std_logic_vector(47 downto 0);
    variable exp_src_bad : std_logic_vector(47 downto 0);

    variable saw_mac_valid : boolean;
    variable saw_crc_error : boolean;
  begin
    reset <= '1';
    data_valid <= '0';
    data_in <= (others => '0');
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);

    -- Extract expected MAC addresses from packets
    exp_dst_ok := bytes_to_mac(PKT_OK(0 to 5));
    exp_src_ok := bytes_to_mac(PKT_OK(6 to 11));
    exp_dst_bad := bytes_to_mac(PKT_BAD(0 to 5));
    exp_src_bad := bytes_to_mac(PKT_BAD(6 to 11));

    -- Test 1: Valid packet from tb_fcs_check_parallel
    report "=== Test 1: Valid packet (PKT_OK) ===";
    saw_mac_valid := false;
    saw_crc_error := false;
    send_packet_with_preamble(
      clk, data_in, data_valid, dst_valid, src_valid, crc_valid,
      PREAMBLE, SFD, PKT_OK,
      saw_mac_valid, saw_crc_error
    );

    for i in 0 to 12 loop
      wait until rising_edge(clk);
      sample_flags(dst_valid, src_valid, crc_valid, saw_mac_valid, saw_crc_error);
    end loop;

    assert dst_mac = exp_dst_ok
      report "Test 1 FAILED: dst_mac mismatch. Got " & to_hstring(dst_mac) & 
              " expected " & to_hstring(exp_dst_ok)
      severity error;
    assert src_mac = exp_src_ok
      report "Test 1 FAILED: src_mac mismatch. Got " & to_hstring(src_mac) & 
              " expected " & to_hstring(exp_src_ok)
      severity error;
    assert saw_mac_valid
      report "Test 1 FAILED: dst_valid and src_valid not seen"
      severity error;
    assert not saw_crc_error
      report "Test 1 FAILED: valid packet triggered CRC error"
      severity error;
    report "Test 1 PASSED: Valid packet processed correctly";

    -- Test 2: Corrupted packet with same FCS (should trigger CRC error)
    report "=== Test 2: Corrupted packet (PKT_BAD) ===";
    saw_mac_valid := false;
    saw_crc_error := false;
    send_packet_with_preamble(
      clk, data_in, data_valid, dst_valid, src_valid, crc_valid,
      PREAMBLE, SFD, PKT_BAD,
      saw_mac_valid, saw_crc_error
    );

    for i in 0 to 12 loop
      wait until rising_edge(clk);
      sample_flags(dst_valid, src_valid, crc_valid, saw_mac_valid, saw_crc_error);
    end loop;

    assert dst_mac = exp_dst_bad
      report "Test 2 FAILED: dst_mac mismatch"
      severity error;
    assert src_mac = exp_src_bad
      report "Test 2 FAILED: src_mac mismatch"
      severity error;
    assert saw_mac_valid
      report "Test 2 FAILED: dst_valid and src_valid not seen"
      severity error;
    assert saw_crc_error
      report "Test 2 FAILED: expected CRC error not detected"
      severity error;
    report "Test 2 PASSED: Corrupted packet detected";

    -- Test 3: Reset and re-send valid packet
    report "=== Test 3: Reset and re-send valid packet ===";
    reset <= '1';
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait for CLK_PERIOD;

    saw_mac_valid := false;
    saw_crc_error := false;
    send_packet_with_preamble(
      clk, data_in, data_valid, dst_valid, src_valid, crc_valid,
      PREAMBLE, SFD, PKT_OK,
      saw_mac_valid, saw_crc_error
    );

    for i in 0 to 12 loop
      wait until rising_edge(clk);
      sample_flags(dst_valid, src_valid, crc_valid, saw_mac_valid, saw_crc_error);
    end loop;

    assert dst_mac = exp_dst_ok
      report "Test 3 FAILED: dst_mac mismatch"
      severity error;
    assert src_mac = exp_src_ok
      report "Test 3 FAILED: src_mac mismatch"
      severity error;
    assert not saw_crc_error
      report "Test 3 FAILED: valid packet triggered CRC error"
      severity error;
    report "Test 3 PASSED: Reset and re-transmission successful";

    report "=== All Frame Handler tests PASSED ===" severity note;
    std.env.stop;
  end process;

end architecture sim;
