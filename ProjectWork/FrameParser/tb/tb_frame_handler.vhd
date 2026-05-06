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

  signal data_out  : std_logic_vector(7 downto 0);
  signal mac_ready : std_logic;
  signal dst_mac   : std_logic_vector(47 downto 0);
  signal src_mac   : std_logic_vector(47 downto 0);
  signal crc_valid : std_logic;

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

  procedure sample_frame_outputs(
    signal mac_ready_i : in std_logic;
    signal crc_valid_i : in std_logic;
    variable saw_mac_ready : inout boolean;
    variable saw_crc_error : inout boolean
  ) is
  begin
    if mac_ready_i = '1' then
      saw_mac_ready := true;
    end if;

    if crc_valid_i = '1' then
      saw_crc_error := true;
    end if;
  end procedure;

  procedure send_frame(
    signal clk_i        : in std_logic;
    signal din_o        : out std_logic_vector(7 downto 0);
    signal dv_o         : out std_logic;
    signal mac_ready_i  : in std_logic;
    signal crc_valid_i  : in std_logic;
    constant bytes      : in byte_array_t;
    constant byte_count : in natural;
    constant expected_dst : in std_logic_vector(47 downto 0);
    constant expected_src : in std_logic_vector(47 downto 0);
    constant expect_crc_error : in boolean;
    constant frame_name  : in string
  ) is
    variable saw_mac_ready : boolean := false;
    variable saw_crc_error : boolean := false;
  begin
    for i in 0 to byte_count - 1 loop
      din_o <= bytes(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
      sample_frame_outputs(mac_ready_i, crc_valid_i, saw_mac_ready, saw_crc_error);
    end loop;

    dv_o  <= '0';
    din_o <= (others => '0');
    for gap_index in 1 to INTERFRAME_GAP_CYCLES loop
      wait until rising_edge(clk_i);
      sample_frame_outputs(mac_ready_i, crc_valid_i, saw_mac_ready, saw_crc_error);
    end loop;

    assert dst_mac = expected_dst
      report frame_name & ": dst_mac mismatch. Got " & to_hstring(dst_mac) &
             " expected " & to_hstring(expected_dst)
      severity error;

    assert src_mac = expected_src
      report frame_name & ": src_mac mismatch. Got " & to_hstring(src_mac) &
             " expected " & to_hstring(expected_src)
      severity error;

    assert saw_mac_ready
      report frame_name & ": mac_ready pulse not observed"
      severity error;

    if expect_crc_error then
      assert saw_crc_error
        report frame_name & ": expected CRC error not observed"
        severity error;
    else
      assert not saw_crc_error
        report frame_name & ": valid frame raised CRC error"
        severity error;
    end if;
  end procedure;

begin
  dut : entity work.frame_handler
    port map (
      clk        => clk,
      reset      => reset,
      data_in    => data_in,
      data_valid => data_valid,
      data_out   => data_out,
      mac_ready  => mac_ready,
      dst_mac    => dst_mac,
      src_mac    => src_mac,
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
    file stim_file : text;
    variable status : file_open_status;
    variable comment_line : line;
    variable frame_line : line;
    variable raw_line : string(1 to 1024);
    variable frame_bytes : byte_array_t(0 to MAX_FRAME_BYTES - 1);
    variable frame_count : natural;
    variable byte_value : std_logic_vector(7 downto 0);
    variable expected_dst : std_logic_vector(47 downto 0);
    variable expected_src : std_logic_vector(47 downto 0);
    variable expect_crc_error : boolean;
    variable frame_name : string(1 to 128);
    variable frame_name_len : natural;
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

    while not endfile(stim_file) loop
      readline(stim_file, comment_line);
      if comment_line.all'length = 0 then
        next;
      end if;

      if comment_line.all(1) /= '#' then
        next;
      end if;

      frame_name_len := comment_line.all'length;
      if frame_name_len > frame_name'length then
        frame_name_len := frame_name'length;
      end if;
      frame_name := (others => ' ');
      frame_name(1 to frame_name_len) := comment_line.all(1 to frame_name_len);
      expect_crc_error := is_corrupt_comment(comment_line.all);

      if endfile(stim_file) then
        exit;
      end if;

      readline(stim_file, frame_line);
      raw_line := (others => ' ');

      frame_count := 0;
      while frame_line.all'length > 0 loop
        hread(frame_line, byte_value);
        if frame_count >= MAX_FRAME_BYTES then
          assert false
            report frame_name & ": frame exceeds MAX_FRAME_BYTES"
            severity failure;
        end if;
        frame_bytes(frame_count) := byte_value;
        frame_count := frame_count + 1;
      end loop;

      assert frame_count >= 22
        report frame_name & ": stimulus frame is too short to contain preamble, SFD, and MAC addresses"
        severity failure;

      expected_dst := bytes_to_mac(frame_bytes, 8);
      expected_src := bytes_to_mac(frame_bytes, 14);

      send_frame(
        clk,
        data_in,
        data_valid,
        mac_ready,
        crc_valid,
        frame_bytes,
        frame_count,
        expected_dst,
        expected_src,
        expect_crc_error,
        frame_name(1 to frame_name_len)
      );

      if not endfile(stim_file) then
        readline(stim_file, frame_line);
      end if;
    end loop;

    report "All frame_handler stimulus frames processed" severity note;
    stop;
  end process;

end architecture sim;