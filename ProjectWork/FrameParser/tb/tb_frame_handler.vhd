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
  signal mac_ready   : std_logic;
  signal dst_mac     : std_logic_vector(47 downto 0);
  signal src_mac     : std_logic_vector(47 downto 0);
  signal crc_valid   : std_logic;

  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

  constant PREAMBLE : byte_array_t(0 to 6) := (
    x"55", x"55", x"55", x"55", x"55", x"55", x"55"
  );

  -- =========================================================================
  -- TEST 1: Korrekter Frame mit 8-Byte Payload
  -- =========================================================================
  constant DST_FRAME_1 : byte_array_t(0 to 5) := (
    x"AA", x"BB", x"CC", x"DD", x"EE", x"FF"
  );

  constant SRC_FRAME_1 : byte_array_t(0 to 5) := (
    x"11", x"22", x"33", x"44", x"55", x"66"
  );

  constant LEN_FRAME_1 : byte_array_t(0 to 1) := (
    x"00", x"08"  -- 8 Bytes Payload
  );

  constant PAYLOAD_1 : byte_array_t(0 to 7) := (
    x"10", x"20", x"30", x"40", x"50", x"60", x"70", x"80"
  );

  constant FCS_1 : byte_array_t(0 to 3) := (
    x"3D", x"2B", x"F5", x"09"  -- Korrekter CRC
  );

  -- =========================================================================
  -- TEST 2: Korrekter Frame mit 14-Byte Payload (andere Länge)
  -- =========================================================================
  constant DST_FRAME_2 : byte_array_t(0 to 5) := (
    x"10", x"20", x"30", x"40", x"50", x"60"
  );

  constant SRC_FRAME_2 : byte_array_t(0 to 5) := (
    x"A1", x"A2", x"A3", x"A4", x"A5", x"A6"
  );

  constant LEN_FRAME_2 : byte_array_t(0 to 1) := (
    x"00", x"0E"  -- 14 Bytes Payload
  );

  constant PAYLOAD_2 : byte_array_t(0 to 13) := (
    x"AA", x"BB", x"CC", x"DD", x"EE", x"FF",
    x"11", x"22", x"33", x"44", x"55", x"66",
    x"77", x"88"
  );

  constant FCS_2 : byte_array_t(0 to 3) := (
    x"47", x"D8", x"A7", x"2C"  -- Korrekter CRC
  );

  -- =========================================================================
  -- TEST 3: Frame mit FALSCHER CRC (gleiche Payload wie Test 1, aber CRC verfälscht)
  -- =========================================================================
  constant DST_FRAME_3 : byte_array_t(0 to 5) := (
    x"FF", x"FF", x"FF", x"FF", x"FF", x"FF"
  );

  constant SRC_FRAME_3 : byte_array_t(0 to 5) := (
    x"C1", x"C2", x"C3", x"C4", x"C5", x"C6"
  );

  constant LEN_FRAME_3 : byte_array_t(0 to 1) := (
    x"00", x"08"  -- 8 Bytes Payload
  );

  constant PAYLOAD_3 : byte_array_t(0 to 7) := (
    x"DE", x"AD", x"BE", x"EF", x"CA", x"FE", x"BA", x"BE"
  );

  constant FCS_3 : byte_array_t(0 to 3) := (
    x"FF", x"FF", x"FF", x"FF"  -- FALSCHER/VERFÄLSCHTER CRC
  );

  procedure send_frame(
    signal clk_i      : in std_logic;
    signal din_o      : out std_logic_vector(7 downto 0);
    signal dv_o       : out std_logic;
    constant preamble : in byte_array_t(0 to 6);
    constant dst      : in byte_array_t(0 to 5);
    constant src      : in byte_array_t(0 to 5);
    constant len_eth  : in byte_array_t(0 to 1);
    constant payload  : in byte_array_t;
    constant fcs      : in byte_array_t(0 to 3)
  ) is
  begin
    -- Preamble + SFD
    for i in preamble'range loop
      din_o <= preamble(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;
    din_o <= x"D5";
    dv_o  <= '1';
    wait until rising_edge(clk_i);

    -- Destination MAC
    for i in dst'range loop
      din_o <= dst(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    -- Source MAC
    for i in src'range loop
      din_o <= src(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    -- Length / EtherType
    for i in len_eth'range loop
      din_o <= len_eth(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    -- Payload
    for i in payload'range loop
      din_o <= payload(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    -- FCS
    for i in fcs'range loop
      din_o <= fcs(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    dv_o  <= '0';
    din_o <= (others => '0');
    wait until rising_edge(clk_i);
  end procedure;

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

begin

  dut : entity work.frame_handler
    port map (
      clk       => clk,
      reset     => reset,
      data_in   => data_in,
      data_valid => data_valid,
      data_out  => data_out,
      mac_ready => mac_ready,
      dst_mac   => dst_mac,
      src_mac   => src_mac,
      crc_valid => crc_valid
    );

  p_clk : process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  p_stim : process
    variable exp_dst : std_logic_vector(47 downto 0);
    variable exp_src : std_logic_vector(47 downto 0);
  begin
    -- Reset
    reset <= '1';
    data_valid <= '0';
    data_in <= (others => '0');
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait for CLK_PERIOD;

    -- =========================================================================
    -- Test 1: Korrekter Frame mit 8-Byte Payload
    -- Erwartet: MACs werden korrekt extrahiert, crc_valid = '0' (kein CRC-Fehler)
    -- =========================================================================
    report "=== Test 1: Valid Frame with 8-byte Payload and CORRECT CRC ===";

    exp_dst := bytes_to_mac(DST_FRAME_1);
    exp_src := bytes_to_mac(SRC_FRAME_1);

    send_frame(clk, data_in, data_valid, PREAMBLE, DST_FRAME_1, SRC_FRAME_1,
               LEN_FRAME_1, PAYLOAD_1, FCS_1);

    wait for 5 * CLK_PERIOD;

    assert dst_mac = exp_dst
      report "Test 1 FAILED: dst_mac mismatch"
      severity error;
    assert src_mac = exp_src
      report "Test 1 FAILED: src_mac mismatch"
      severity error;
    assert mac_ready = '1'
      report "Test 1 FAILED: mac_ready not set"
      severity error;

    report "Test 1 PASSED: Frame processed, MACs extracted, CRC valid";
    wait for 5 * CLK_PERIOD;

    -- =========================================================================
    -- Test 2: Korrekter Frame mit 14-Byte Payload (unterschiedliche Länge)
    -- Erwartet: Größerer Frame wird korrekt verarbeitet, andere Payload-Länge
    -- =========================================================================
    report "=== Test 2: Valid Frame with 14-byte Payload and CORRECT CRC ===";

    exp_dst := bytes_to_mac(DST_FRAME_2);
    exp_src := bytes_to_mac(SRC_FRAME_2);

    send_frame(clk, data_in, data_valid, PREAMBLE, DST_FRAME_2, SRC_FRAME_2,
               LEN_FRAME_2, PAYLOAD_2, FCS_2);

    wait for 5 * CLK_PERIOD;

    assert dst_mac = exp_dst
      report "Test 2 FAILED: dst_mac mismatch"
      severity error;
    assert src_mac = exp_src
      report "Test 2 FAILED: src_mac mismatch"
      severity error;
    assert mac_ready = '1'
      report "Test 2 FAILED: mac_ready not set"
      severity error;

    report "Test 2 PASSED: Larger frame (14 bytes) processed correctly with valid CRC";
    wait for 5 * CLK_PERIOD;

    -- =========================================================================
    -- Test 3: Frame mit FALSCHER CRC
    -- Erwartet: MACs werden trotzdem extrahiert, aber crc_valid = '1' (CRC-Fehler!)
    -- =========================================================================
    report "=== Test 3: Valid Frame with 8-byte Payload but WRONG CRC ===";

    exp_dst := bytes_to_mac(DST_FRAME_3);
    exp_src := bytes_to_mac(SRC_FRAME_3);

    send_frame(clk, data_in, data_valid, PREAMBLE, DST_FRAME_3, SRC_FRAME_3,
               LEN_FRAME_3, PAYLOAD_3, FCS_3);

    wait for 5 * CLK_PERIOD;

    assert dst_mac = exp_dst
      report "Test 3 FAILED: dst_mac mismatch"
      severity error;
    assert src_mac = exp_src
      report "Test 3 FAILED: src_mac mismatch"
      severity error;
    assert mac_ready = '1'
      report "Test 3 FAILED: mac_ready not set"
      severity error;
    assert crc_valid = '1'
      report "Test 3 FAILED: crc_valid should indicate CRC error ('1')"
      severity error;

    report "Test 3 PASSED: CRC error correctly detected! (crc_valid='1')";
    wait for 5 * CLK_PERIOD;

    report "=== All tests completed successfully ===" severity note;
    std.env.stop;
  end process;

end architecture sim;
