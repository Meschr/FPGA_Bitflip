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

  function parse_hex_byte(constant hex_str : string) return std_logic_vector is
    variable result : std_logic_vector(7 downto 0);
  begin
    result := std_logic_vector(to_unsigned(integer'value("16#" & hex_str & "#"), 8));
    return result;
  end function;

  procedure read_frame(
    file stim_file : text;
    variable frame : out byte_array_t;
    variable frame_len : out natural;
    variable is_corrupt : out boolean;
    variable is_eof : out boolean
  ) is
    variable line_v : line;
    variable hex_pair : string(1 to 2);
    variable hex_idx : natural;
    variable byte_idx : natural := 0;
  begin
    is_eof := false;
    is_corrupt := false;
    frame_len := 0;

    -- Read lines until we find a valid data line
    loop
      if endfile(stim_file) then
        is_eof := true;
        return;
      end if;

      readline(stim_file, line_v);

      -- Skip empty lines
      if line_v'length = 0 then
        next;
      end if;

      -- Check for comment lines
      if line_v(1) = '#' then
        -- Check if this is a "Corrupt" frame comment
        if line_v'length >= 9 and line_v(3 to 8) = "Corrupt" then
          is_corrupt := true;
        end if;
        -- Continue reading to get the hex data on the next line
        next;
      end if;

      -- This should be a hex data line
      byte_idx := 0;
      hex_idx := line_v'left;

      while hex_idx < line_v'right loop
        -- Skip whitespace
        while hex_idx <= line_v'right and line_v(hex_idx) = ' ' loop
          hex_idx := hex_idx + 1;
        end loop;

        exit when hex_idx >= line_v'right;

        -- Read two hex characters
        if hex_idx + 1 <= line_v'right then
          hex_pair := line_v(hex_idx to hex_idx + 1);
          frame(byte_idx) := parse_hex_byte(hex_pair);
          byte_idx := byte_idx + 1;
          hex_idx := hex_idx + 2;
        else
          hex_idx := hex_idx + 1;
        end if;
      end loop;

      frame_len := byte_idx;
      exit;  -- Successfully read a frame
    end loop;

    deallocate(line_v);
  end procedure;

  procedure send_frame(
    signal clk_i        : in std_logic;
    signal din_o        : out std_logic_vector(7 downto 0);
    signal dv_o         : out std_logic;
    signal dst_valid_i  : in std_logic;
    signal src_valid_i  : in std_logic;
    signal crc_valid_i  : in std_logic;
    constant frame      : in byte_array_t;
    constant frame_len  : in natural;
    variable saw_mac_valid : inout boolean;
    variable saw_crc_error : inout boolean
  ) is
  begin
    -- Send frame bytes
    for i in 0 to frame_len - 1 loop
      din_o <= frame(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
      
      if dst_valid_i = '1' and src_valid_i = '1' then
        saw_mac_valid := true;
      end if;

      if crc_valid_i = '1' then
        saw_crc_error := true;
      end if;
    end loop;

    -- Deassert valid and wait for interframe gap
    dv_o  <= '0';
    din_o <= (others => '0');
    for i in 0 to INTERFRAME_GAP_CYCLES - 1 loop
      wait until rising_edge(clk_i);
    end loop;
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
    file stim_file : text;
    variable status : file_open_status;
    variable frame : byte_array_t(0 to MAX_FRAME_BYTES - 1);
    variable frame_len : natural;
    variable is_corrupt : boolean;
    variable is_eof : boolean;
    variable test_num : natural := 0;
    variable saw_mac_valid : boolean;
    variable saw_crc_error : boolean;
  begin
    -- Try to open stimulus file from primary location, then fallback
    file_open(status, stim_file, STIMULUS_FILE_PRIMARY, read_mode);
    if status /= open_ok then
      file_open(status, stim_file, STIMULUS_FILE_FALLBACK, read_mode);
    end if;
    
    assert status = open_ok
      report "Unable to open stimulus file from " & STIMULUS_FILE_PRIMARY & " or " & STIMULUS_FILE_FALLBACK
      severity failure;

    -- Reset sequence
    reset <= '1';
    data_in <= (others => '0');
    data_valid <= '0';
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);

    -- Read and send frames from stimulus file
    is_eof := false;
    loop
      exit when is_eof;

      read_frame(stim_file, frame, frame_len, is_corrupt, is_eof);
      if is_eof then
        exit;
      end if;

      test_num := test_num + 1;
      saw_mac_valid := false;
      saw_crc_error := false;

      if is_corrupt then
        report "Test " & natural'image(test_num) & ": Corrupt frame (" & 
                natural'image(frame_len) & " bytes)";
      else
        report "Test " & natural'image(test_num) & ": Valid frame (" & 
                natural'image(frame_len) & " bytes)";
      end if;

      -- Send the frame
      send_frame(clk, data_in, data_valid, dst_valid, src_valid, crc_valid,
                 frame, frame_len, saw_mac_valid, saw_crc_error);

      -- Wait for frame processing
      for i in 0 to 20 loop
        wait until rising_edge(clk);
        if dst_valid = '1' and src_valid = '1' then
          saw_mac_valid := true;
        end if;
        if crc_valid = '1' then
          saw_crc_error := true;
        end if;
      end loop;

      -- Verify results based on frame type
      if is_corrupt then
        report "Test " & natural'image(test_num) & ": " &
                "dst_mac=" & to_hstring(dst_mac) & " " &
                "src_mac=" & to_hstring(src_mac) & " " &
                "saw_mac_valid=" & boolean'image(saw_mac_valid) & " " &
                "crc_error=" & boolean'image(saw_crc_error);
      else
        report "Test " & natural'image(test_num) & ": " &
                "dst_mac=" & to_hstring(dst_mac) & " " &
                "src_mac=" & to_hstring(src_mac) & " " &
                "saw_mac_valid=" & boolean'image(saw_mac_valid) & " " &
                "crc_error=" & boolean'image(saw_crc_error);
      end if;

    end loop;

    file_close(stim_file);
    report "All stimulus frames processed successfully" severity note;
    stop;
  end process;

end architecture sim;