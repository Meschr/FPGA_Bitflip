library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;
use std.env.all;

entity tb_frame_handler is
end entity tb_frame_handler;

architecture sim of tb_frame_handler is
  constant CLK_PERIOD : time := 10 ns;
  constant INTERFRAME_GAP_CYCLES  : natural := 12;
  constant STIMULUS_FILE_PRIMARY  : string := "src/stimulus.txt";
  constant STIMULUS_FILE_FALLBACK : string := "../src/stimulus.txt";
  constant MAX_FRAME_BYTES        : natural := 256;

  signal clk        : std_logic := '0';
  signal reset      : std_logic := '1';
  signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid : std_logic := '0';

  signal data_out    : std_logic_vector(7 downto 0);
  signal dst_mac     : std_logic_vector(47 downto 0);
  signal dst_valid   : std_logic;
  signal src_mac     : std_logic_vector(47 downto 0);
  signal src_valid   : std_logic;
  signal crc_valid   : std_logic;

  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

  function bytes_to_mac(
    constant bytes : byte_array_t;
    constant first  : natural
  ) return std_logic_vector is
    variable mac : std_logic_vector(47 downto 0);
  begin
    mac(47 downto 40) := bytes(first + 0);
    mac(39 downto 32) := bytes(first + 1);
    mac(31 downto 24) := bytes(first + 2);
    mac(23 downto 16) := bytes(first + 3);
    mac(15 downto 8)  := bytes(first + 4);
    mac(7 downto 0)   := bytes(first + 5);
    return mac;
  end function;

  function is_corrupt_comment(constant comment_line : string) return boolean is
  begin
    if comment_line'length >= 9 and comment_line(3 to 9) = "Corrupt" then
      return true;
    end if;
    return false;
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

    if crc_valid_i = '1' then
      saw_crc_error := true;
    end if;
  end procedure;

  procedure send_frame(
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
    for i in 0 to byte_count - 1 loop
      din_o <= bytes(i);
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
    file_open(status, stim_file, STIMULUS_FILE_PRIMARY, read_mode);
    if status /= open_ok then
      file_open(status, stim_file, STIMULUS_FILE_FALLBACK, read_mode);
    end if;
    assert status = open_ok
      report "Unable to open stimulus file from src: " & STIMULUS_FILE_PRIMARY
      severity failure;

    reset <= '1';
    data_in <= (others => '0');
    data_valid <= '0';
    wait for 5 * CLK_PERIOD;
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

    report "All frame_handler stimulus frames processed" severity note;
    stop;
  end process;

end architecture sim;