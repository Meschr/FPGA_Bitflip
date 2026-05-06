library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_frame_parser is
end entity tb_frame_parser;

architecture sim of tb_frame_parser is
  constant CLK_PERIOD : time := 10 ns;

  signal clk             : std_logic := '0';
  signal reset           : std_logic := '1';
  signal data_in         : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid      : std_logic := '0';

  signal data_out        : std_logic_vector(7 downto 0);
  signal sof             : std_logic;
  signal eof             : std_logic;
  signal lof             : std_logic;
  signal dst_mac         : std_logic_vector(47 downto 0);
  signal src_mac         : std_logic_vector(47 downto 0);
  signal macs_valid      : std_logic;

  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

  constant PREAMBLE_BYTES : byte_array_t(0 to 6) := (
    x"55", x"55", x"55", x"55", x"55", x"55", x"55"
  );

  constant DST_A : byte_array_t(0 to 5) := (
    x"DA", x"DB", x"DC", x"DD", x"DE", x"DF"
  );

  constant SRC_A : byte_array_t(0 to 5) := (
    x"5A", x"5B", x"5C", x"5D", x"5E", x"5F"
  );

  constant LEN_A : byte_array_t(0 to 1) := (
    x"00", x"0A"
  );

  constant PAYLOAD_A : byte_array_t(0 to 9) := (
    x"11", x"22", x"33", x"44", x"55", x"66", x"77", x"88", x"99", x"AA"
  );

  constant FCS_A : byte_array_t(0 to 3) := (
    x"A1", x"A2", x"A3", x"A4"
  );

  constant DST_B : byte_array_t(0 to 5) := (
    x"10", x"11", x"12", x"13", x"14", x"15"
  );

  constant SRC_B : byte_array_t(0 to 5) := (
    x"20", x"21", x"22", x"23", x"24", x"25"
  );

  constant LEN_B : byte_array_t(0 to 1) := (
    x"00", x"04"
  );

  constant PAYLOAD_B : byte_array_t(0 to 3) := (
    x"B1", x"B2", x"B3", x"B4"
  );

  constant FCS_B : byte_array_t(0 to 3) := (
    x"B9", x"BA", x"BB", x"BC"
  );

  constant DST_C : byte_array_t(0 to 5) := (
    x"30", x"31", x"32", x"33", x"34", x"35"
  );

  constant SRC_C : byte_array_t(0 to 5) := (
    x"40", x"41", x"42", x"43", x"44", x"45"
  );

  constant LEN_C : byte_array_t(0 to 1) := (
    x"00", x"10"
  );

  constant PAYLOAD_C : byte_array_t(0 to 15) := (
    x"C0", x"C1", x"C2", x"C3", x"C4", x"C5", x"C6", x"C7",
    x"C8", x"C9", x"CA", x"CB", x"CC", x"CD", x"CE", x"CF"
  );

  constant FCS_C : byte_array_t(0 to 3) := (
    x"D1", x"D2", x"D3", x"D4"
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

  procedure send_preamble_and_sfd(
    signal clk_i   : in std_logic;
    signal din_o   : out std_logic_vector(7 downto 0);
    signal dv_o    : out std_logic;
    signal sof_i   : in std_logic;
    signal mv_i    : in std_logic;
    signal lof_i   : in std_logic
  ) is
  begin
    for i in PREAMBLE_BYTES'range loop
      din_o <= PREAMBLE_BYTES(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
      wait for 0 ns;
      assert sof_i = '0'
        report "SOF asserted during preamble index " & integer'image(i)
        severity error;
      assert mv_i = '0' and lof_i = '0'
        report "macs_valid/lof asserted during preamble"
        severity error;
    end loop;

    din_o <= x"D5";
    dv_o  <= '1';
    wait until rising_edge(clk_i);
    wait for 0 ns;
    assert sof_i = '1'
      report "SOF not asserted on SFD cycle"
      severity error;
  end procedure;

  procedure drive_byte(
    signal clk_i   : in std_logic;
    signal din_o   : out std_logic_vector(7 downto 0);
    signal dv_o    : out std_logic;
    constant b     : in std_logic_vector(7 downto 0)
  ) is
  begin
    din_o <= b;
    dv_o  <= '1';
    wait until rising_edge(clk_i);
  end procedure;

  procedure check_full_frame(
    signal clk_i      : in std_logic;
    signal din_o      : out std_logic_vector(7 downto 0);
    signal dv_o       : out std_logic;
    signal data_out_i : in std_logic_vector(7 downto 0);
    signal sof_i      : in std_logic;
    signal eof_i      : in std_logic;
    signal lof_i      : in std_logic;
    signal mv_i       : in std_logic;
    signal dst_i      : in std_logic_vector(47 downto 0);
    signal src_i      : in std_logic_vector(47 downto 0);
    constant dst      : in byte_array_t(0 to 5);
    constant src      : in byte_array_t(0 to 5);
    constant len_f    : in byte_array_t(0 to 1);
    constant payload  : in byte_array_t;
    constant fcs      : in byte_array_t(0 to 3);
    constant name     : in string
  ) is
    variable exp_dst : std_logic_vector(47 downto 0);
    variable exp_src : std_logic_vector(47 downto 0);
  begin
    exp_dst := bytes_to_mac(dst);
    exp_src := bytes_to_mac(src);

    report "--- " & name & " ---";

    send_preamble_and_sfd(clk_i, din_o, dv_o, sof_i, mv_i, lof_i);

    for i in dst'range loop
      drive_byte(clk_i, din_o, dv_o, dst(i));
      wait for 0 ns;
      assert data_out_i = dst(i)
        report "data_out mismatch in DST index " & integer'image(i)
        severity error;
      assert mv_i = '0' and lof_i = '0'
        report "macs_valid/lof asserted too early in DST"
        severity error;
    end loop;

    for i in src'range loop
      drive_byte(clk_i, din_o, dv_o, src(i));
      wait for 0 ns;
      assert data_out_i = src(i)
        report "data_out mismatch in SRC index " & integer'image(i)
        severity error;
      assert mv_i = '0' and lof_i = '0'
        report "macs_valid/lof asserted too early in SRC"
        severity error;
    end loop;

    drive_byte(clk_i, din_o, dv_o, len_f(0));
    wait for 0 ns;
    assert data_out_i = len_f(0)
      report "data_out mismatch in LEN byte 0"
      severity error;
    assert mv_i = '0' and lof_i = '0'
      report "macs_valid/lof asserted too early in LEN byte 0"
      severity error;

    drive_byte(clk_i, din_o, dv_o, len_f(1));
    wait for 0 ns;
    assert data_out_i = len_f(1)
      report "data_out mismatch in LEN byte 1"
      severity error;
    assert mv_i = '1' and lof_i = '1'
      report "macs_valid/lof missing on LEN byte 1"
      severity error;
    assert dst_i = exp_dst
      report "dst_mac mismatch"
      severity error;
    assert src_i = exp_src
      report "src_mac mismatch"
      severity error;

    for i in payload'range loop
      drive_byte(clk_i, din_o, dv_o, payload(i));
      wait for 0 ns;
      assert data_out_i = payload(i)
        report "data_out mismatch in payload index " & integer'image(i)
        severity error;
      if i = payload'right then
        assert eof_i = '1'
          report "EOF missing on last payload byte"
          severity error;
      else
        assert eof_i = '0'
          report "EOF asserted before last payload byte"
          severity error;
      end if;
    end loop;

    for i in fcs'range loop
      drive_byte(clk_i, din_o, dv_o, fcs(i));
      wait for 0 ns;
      assert data_out_i = fcs(i)
        report "data_out mismatch in FCS index " & integer'image(i)
        severity error;
      assert eof_i = '0'
        report "EOF must be pulse-only"
        severity error;
    end loop;

    dv_o  <= '0';
    din_o <= (others => '0');
    wait until rising_edge(clk_i);
    wait for 0 ns;
  end procedure;

begin
  dut : entity work.frame_parser
    port map (
      clk             => clk,
      reset           => reset,
      data_in         => data_in,
      data_valid      => data_valid,
      data_out        => data_out,
      sof             => sof,
      eof             => eof,
      lof             => lof,
      dst_mac         => dst_mac,
      src_mac         => src_mac,
      macs_valid      => macs_valid
    );

  p_clk : process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  p_stim : process
  begin
    reset <= '1';
    data_valid <= '0';
    data_in <= (others => '0');
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';

    report "=== Comprehensive parser test: multiple lengths and MACs ===";

    check_full_frame(
      clk, data_in, data_valid, data_out, sof, eof, lof, macs_valid, dst_mac, src_mac,
      DST_A, SRC_A, LEN_A, PAYLOAD_A, FCS_A, "Frame A (len=10)"
    );

    check_full_frame(
      clk, data_in, data_valid, data_out, sof, eof, lof, macs_valid, dst_mac, src_mac,
      DST_B, SRC_B, LEN_B, PAYLOAD_B, FCS_B, "Frame B (len=4)"
    );

    check_full_frame(
      clk, data_in, data_valid, data_out, sof, eof, lof, macs_valid, dst_mac, src_mac,
      DST_C, SRC_C, LEN_C, PAYLOAD_C, FCS_C, "Frame C (len=16)"
    );

    report "All comprehensive parser checks passed." severity note;
    std.env.stop;
  end process;

end architecture sim;
