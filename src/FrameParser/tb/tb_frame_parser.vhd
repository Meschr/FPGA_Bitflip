library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_frame_parser is
end entity tb_frame_parser;

architecture sim of tb_frame_parser is
  constant CLK_PERIOD : TIME := 10 ns;

  signal clk        : STD_LOGIC                    := '0';
  signal reset      : STD_LOGIC                    := '1';
  signal data_in    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
  signal data_valid : STD_LOGIC                    := '0';

  signal data_out  : STD_LOGIC_VECTOR(7 downto 0);
  signal sof       : STD_LOGIC;
  signal eof       : STD_LOGIC;
  signal dst_mac   : STD_LOGIC_VECTOR(47 downto 0);
  signal src_mac   : STD_LOGIC_VECTOR(47 downto 0);
  signal dst_valid : STD_LOGIC;
  signal src_valid : STD_LOGIC;

  type byte_array_t is array (NATURAL range <>) of STD_LOGIC_VECTOR(7 downto 0);

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

  function bytes_to_mac(arr : byte_array_t(0 to 5)) return STD_LOGIC_VECTOR is
    variable tmp              : STD_LOGIC_VECTOR(47 downto 0);
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
    signal clk_i       : in STD_LOGIC;
    signal din_o       : out STD_LOGIC_VECTOR(7 downto 0);
    signal dv_o        : out STD_LOGIC;
    signal sof_i       : in STD_LOGIC;
    signal dst_valid_i : in STD_LOGIC;
    signal src_valid_i : in STD_LOGIC;
    constant sfd_byte  : in STD_LOGIC_VECTOR(7 downto 0)
  ) is
  begin
    for i in PREAMBLE_BYTES'range loop
      din_o <= PREAMBLE_BYTES(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
      wait for 0 ns;
      assert sof_i = '0'
      report "SOF asserted during preamble index " & INTEGER'image(i)
        severity error;
      assert dst_valid_i = '0' and src_valid_i = '0'
      report "dst_valid/src_valid asserted during preamble"
        severity error;
    end loop;

    din_o <= sfd_byte;
    dv_o  <= '1';
    wait until rising_edge(clk_i);
    wait for 0 ns;
    assert sof_i = '0'
    report "SOF must stay low on the SFD cycle"
      severity error;
  end procedure;

  procedure drive_byte(
    signal clk_i : in STD_LOGIC;
    signal din_o : out STD_LOGIC_VECTOR(7 downto 0);
    signal dv_o  : out STD_LOGIC;
    constant b   : in STD_LOGIC_VECTOR(7 downto 0)
  ) is
  begin
    din_o <= b;
    dv_o  <= '1';
    wait until rising_edge(clk_i);
  end procedure;

  procedure check_full_frame(
    signal clk_i       : in STD_LOGIC;
    signal din_o       : out STD_LOGIC_VECTOR(7 downto 0);
    signal dv_o        : out STD_LOGIC;
    signal data_out_i  : in STD_LOGIC_VECTOR(7 downto 0);
    signal sof_i       : in STD_LOGIC;
    signal eof_i       : in STD_LOGIC;
    signal dst_valid_i : in STD_LOGIC;
    signal src_valid_i : in STD_LOGIC;
    signal dst_i       : in STD_LOGIC_VECTOR(47 downto 0);
    signal src_i       : in STD_LOGIC_VECTOR(47 downto 0);
    constant dst       : in byte_array_t(0 to 5);
    constant src       : in byte_array_t(0 to 5);
    constant len_f     : in byte_array_t(0 to 1);
    constant payload   : in byte_array_t;
    constant fcs       : in byte_array_t(0 to 3);
    constant name      : in STRING
  ) is
    variable exp_dst : STD_LOGIC_VECTOR(47 downto 0);
    variable exp_src : STD_LOGIC_VECTOR(47 downto 0);
  begin
    exp_dst := bytes_to_mac(dst);
    exp_src := bytes_to_mac(src);

    report "--- " & name & " ---";

      send_preamble_and_sfd(clk_i, din_o, dv_o, sof_i, dst_valid_i, src_valid_i, x"D5");

    for i in dst'range loop
      drive_byte(clk_i, din_o, dv_o, dst(i));
      wait for 0 ns;
      assert data_out_i = dst(i)
      report "data_out mismatch in DST index " & INTEGER'image(i)
        severity error;
      if i = dst'left then
        assert sof_i = '1'
        report "SOF missing on first DST byte"
          severity error;
      else
        assert sof_i = '0'
        report "SOF asserted outside first DST byte"
          severity error;
      end if;
      if i = dst'right then
        assert dst_valid_i = '1' and src_valid_i = '0'
        report "dst_valid/src_valid missing on last DST byte"
          severity error;
        assert dst_i = exp_dst
        report "dst_mac mismatch"
          severity error;
      else
        assert dst_valid_i = '0' and src_valid_i = '0'
        report "dst_valid/src_valid asserted too early in DST"
          severity error;
      end if;
    end loop;

    for i in src'range loop
      drive_byte(clk_i, din_o, dv_o, src(i));
      wait for 0 ns;
      assert data_out_i = src(i)
      report "data_out mismatch in SRC index " & INTEGER'image(i)
        severity error;
      if i = src'right then
        assert dst_valid_i = '0' and src_valid_i = '1'
        report "dst_valid/src_valid missing on last SRC byte"
          severity error;
        assert src_i = exp_src
        report "src_mac mismatch"
          severity error;
      else
        assert dst_valid_i = '0' and src_valid_i = '0'
        report "dst_valid/src_valid asserted too early in SRC"
          severity error;
      end if;
    end loop;

    drive_byte(clk_i, din_o, dv_o, len_f(0));
    wait for 0 ns;
    assert data_out_i = len_f(0)
    report "data_out mismatch in LEN byte 0"
      severity error;

    drive_byte(clk_i, din_o, dv_o, len_f(1));
    wait for 0 ns;
    assert data_out_i = len_f(1)
    report "data_out mismatch in LEN byte 1"
      severity error;
    assert dst_valid_i = '0' and src_valid_i = '0'
    report "dst_valid/src_valid asserted too early in LEN byte 1"
      severity error;
    assert sof_i = '0'
    report "SOF must stay low after DST"
      severity error;

    for i in payload'range loop
      drive_byte(clk_i, din_o, dv_o, payload(i));
      wait for 0 ns;
      assert data_out_i = payload(i)
      report "data_out mismatch in payload index " & INTEGER'image(i)
        severity error;
      assert dst_valid_i = '0' and src_valid_i = '0'
      report "dst_valid/src_valid asserted during payload"
        severity error;
      assert eof_i = '0'
      report "EOF asserted before frame end"
        severity error;
    end loop;

    for i in fcs'range loop
      drive_byte(clk_i, din_o, dv_o, fcs(i));
      wait for 0 ns;
      assert data_out_i = fcs(i)
      report "data_out mismatch in FCS index " & INTEGER'image(i)
        severity error;
      assert dst_valid_i = '0' and src_valid_i = '0'
      report "dst_valid/src_valid asserted during FCS"
        severity error;
      assert eof_i = '0'
      report "EOF must be pulse-only"
        severity error;
    end loop;

    dv_o  <= '0';
    din_o <= (others => '0');
    wait until rising_edge(clk_i);
    wait for 0 ns;
    assert eof_i = '1'
    report "EOF missing after data_valid falls"
      severity error;
  end procedure;

begin
  dut : entity work.frame_parser
    port map(
      clk        => clk,
      reset      => reset,
      data_in    => data_in,
      data_valid => data_valid,
      data_out   => data_out,
      sof        => sof,
      eof        => eof,
      dst_valid  => dst_valid,
      dst_mac    => dst_mac,
      src_valid  => src_valid,
      src_mac    => src_mac
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
    reset      <= '0';
    data_valid <= '0';
    data_in    <= (others => '0');
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '1';

    report "=== Comprehensive parser test: multiple lengths and MACs ===";

    check_full_frame(
    clk, data_in, data_valid, data_out, sof, eof, dst_valid, src_valid, dst_mac, src_mac,
    DST_A, SRC_A, LEN_A, PAYLOAD_A, FCS_A, "Frame A (len=10)"
    );

    for i in 1 to 5 loop
      data_valid <= '0';
      data_in    <= (others => '0');
      wait until rising_edge(clk);
      wait for 0 ns;
    end loop;

    check_full_frame(
    clk, data_in, data_valid, data_out, sof, eof, dst_valid, src_valid, dst_mac, src_mac,
    DST_B, SRC_B, LEN_B, PAYLOAD_B, FCS_B, "Frame B (len=4)"
    );

    for i in 1 to 5 loop
      data_valid <= '0';
      data_in    <= (others => '0');
      wait until rising_edge(clk);
      wait for 0 ns;
    end loop;

    check_full_frame(
    clk, data_in, data_valid, data_out, sof, eof, dst_valid, src_valid, dst_mac, src_mac,
    DST_C, SRC_C, LEN_C, PAYLOAD_C, FCS_C, "Frame C (len=16)"
    );

    for i in 1 to 5 loop
      data_valid <= '0';
      data_in    <= (others => '0');
      wait until rising_edge(clk);
      wait for 0 ns;
    end loop;

    report "--- Corrupt frame (ERR state) ---";
      send_preamble_and_sfd(clk, data_in, data_valid, sof, dst_valid, src_valid, x"00");
    data_valid <= '0';
    data_in    <= (others => '0');
    wait until rising_edge(clk);
    wait for 0 ns;
    assert eof = '1'
    report "EOF missing after bad SFD"
      severity error;
    assert dst_valid = '0' and src_valid = '0'
    report "Valid pulses must stay low in ERR state"
      severity error;

    report "All comprehensive parser checks passed." severity note;
    std.env.stop;
  end process;

end architecture sim;
