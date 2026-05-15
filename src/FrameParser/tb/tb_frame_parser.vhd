LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_frame_parser IS
END ENTITY tb_frame_parser;

ARCHITECTURE sim OF tb_frame_parser IS
  CONSTANT CLK_PERIOD : TIME := 10 ns;

  SIGNAL clk : STD_LOGIC := '0';
  SIGNAL reset : STD_LOGIC := '1';
  SIGNAL data_in : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL data_valid : STD_LOGIC := '0';

  SIGNAL data_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL sof : STD_LOGIC;
  SIGNAL eof : STD_LOGIC;
  SIGNAL dst_mac : STD_LOGIC_VECTOR(47 DOWNTO 0);
  SIGNAL src_mac : STD_LOGIC_VECTOR(47 DOWNTO 0);
  SIGNAL dst_valid : STD_LOGIC;
  SIGNAL src_valid : STD_LOGIC;

  TYPE byte_array_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

  CONSTANT PREAMBLE_BYTES : byte_array_t(0 to 6) := (
    x"55", x"55", x"55", x"55", x"55", x"55", x"55"
  );

  CONSTANT DST_A : byte_array_t(0 to 5) := (
    x"DA", x"DB", x"DC", x"DD", x"DE", x"DF"
  );

  CONSTANT SRC_A : byte_array_t(0 to 5) := (
    x"5A", x"5B", x"5C", x"5D", x"5E", x"5F"
  );

  CONSTANT LEN_A : byte_array_t(0 to 1) := (
    x"00", x"0A"
  );

  CONSTANT PAYLOAD_A : byte_array_t(0 to 9) := (
    x"11", x"22", x"33", x"44", x"55", x"66", x"77", x"88", x"99", x"AA"
  );

  CONSTANT FCS_A : byte_array_t(0 to 3) := (
    x"A1", x"A2", x"A3", x"A4"
  );

  CONSTANT DST_B : byte_array_t(0 to 5) := (
    x"10", x"11", x"12", x"13", x"14", x"15"
  );

  CONSTANT SRC_B : byte_array_t(0 to 5) := (
    x"20", x"21", x"22", x"23", x"24", x"25"
  );

  CONSTANT LEN_B : byte_array_t(0 to 1) := (
    x"00", x"04"
  );

  CONSTANT PAYLOAD_B : byte_array_t(0 to 3) := (
    x"B1", x"B2", x"B3", x"B4"
  );

  CONSTANT FCS_B : byte_array_t(0 to 3) := (
    x"B9", x"BA", x"BB", x"BC"
  );

  CONSTANT DST_C : byte_array_t(0 to 5) := (
    x"30", x"31", x"32", x"33", x"34", x"35"
  );

  CONSTANT SRC_C : byte_array_t(0 to 5) := (
    x"40", x"41", x"42", x"43", x"44", x"45"
  );

  CONSTANT LEN_C : byte_array_t(0 to 1) := (
    x"00", x"10"
  );

  CONSTANT PAYLOAD_C : byte_array_t(0 to 15) := (
    x"C0", x"C1", x"C2", x"C3", x"C4", x"C5", x"C6", x"C7",
    x"C8", x"C9", x"CA", x"CB", x"CC", x"CD", x"CE", x"CF"
  );

  CONSTANT FCS_C : byte_array_t(0 to 3) := (
    x"D1", x"D2", x"D3", x"D4"
  );

  FUNCTION bytes_to_mac(arr : byte_array_t(0 TO 5)) RETURN STD_LOGIC_VECTOR IS
    VARIABLE tmp : STD_LOGIC_VECTOR(47 DOWNTO 0);
  BEGIN
    tmp(47 DOWNTO 40) := arr(0);
    tmp(39 DOWNTO 32) := arr(1);
    tmp(31 DOWNTO 24) := arr(2);
    tmp(23 DOWNTO 16) := arr(3);
    tmp(15 DOWNTO 8) := arr(4);
    tmp(7 DOWNTO 0) := arr(5);
    RETURN tmp;
  END FUNCTION;

  PROCEDURE send_preamble_and_sfd(
    SIGNAL clk_i : IN STD_LOGIC;
    SIGNAL din_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL dv_o : OUT STD_LOGIC;
    SIGNAL sof_i : IN STD_LOGIC;
    SIGNAL dst_valid_i : IN STD_LOGIC;
    SIGNAL src_valid_i : IN STD_LOGIC;
    CONSTANT sfd_byte : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
  ) IS
  BEGIN
    FOR i IN PREAMBLE_BYTES'RANGE LOOP
      din_o <= PREAMBLE_BYTES(i);
      dv_o <= '1';
      WAIT UNTIL rising_edge(clk_i);
      WAIT FOR 0 ns;
      ASSERT sof_i = '0'
      REPORT "SOF asserted during preamble index " & INTEGER'image(i)
        SEVERITY error;
      ASSERT dst_valid_i = '0' AND src_valid_i = '0'
      REPORT "dst_valid/src_valid asserted during preamble"
        SEVERITY error;
    END LOOP;

    din_o <= sfd_byte;
    dv_o <= '1';
    WAIT UNTIL rising_edge(clk_i);
    WAIT FOR 0 ns;
    ASSERT sof_i = '0'
    REPORT "SOF must stay low on the SFD cycle"
      SEVERITY error;
  END PROCEDURE;

  PROCEDURE drive_byte(
    SIGNAL clk_i : IN STD_LOGIC;
    SIGNAL din_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL dv_o : OUT STD_LOGIC;
    CONSTANT b : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
  ) IS
  BEGIN
    din_o <= b;
    dv_o <= '1';
    WAIT UNTIL rising_edge(clk_i);
  END PROCEDURE;

  PROCEDURE check_full_frame(
    SIGNAL clk_i : IN STD_LOGIC;
    SIGNAL din_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL dv_o : OUT STD_LOGIC;
    SIGNAL data_out_i : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL sof_i : IN STD_LOGIC;
    SIGNAL eof_i : IN STD_LOGIC;
    SIGNAL dst_valid_i : IN STD_LOGIC;
    SIGNAL src_valid_i : IN STD_LOGIC;
    SIGNAL dst_i : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    SIGNAL src_i : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    CONSTANT dst : IN byte_array_t(0 TO 5);
    CONSTANT src : IN byte_array_t(0 TO 5);
    CONSTANT len_f : IN byte_array_t(0 TO 1);
    CONSTANT payload : IN byte_array_t;
    CONSTANT fcs : IN byte_array_t(0 TO 3);
    CONSTANT name : IN STRING
  ) IS
    VARIABLE exp_dst : STD_LOGIC_VECTOR(47 DOWNTO 0);
    VARIABLE exp_src : STD_LOGIC_VECTOR(47 DOWNTO 0);
  BEGIN
    exp_dst := bytes_to_mac(dst);
    exp_src := bytes_to_mac(src);

    REPORT "--- " & name & " ---";

    send_preamble_and_sfd(clk_i, din_o, dv_o, sof_i, dst_valid_i, src_valid_i, x"D5");

    FOR i IN dst'RANGE LOOP
      drive_byte(clk_i, din_o, dv_o, dst(i));
      WAIT FOR 0 ns;
      ASSERT data_out_i = dst(i)
      REPORT "data_out mismatch in DST index " & INTEGER'image(i)
        SEVERITY error;
      IF i = dst'left THEN
        ASSERT sof_i = '1'
        REPORT "SOF missing on first DST byte"
          SEVERITY error;
      ELSE
        ASSERT sof_i = '0'
        REPORT "SOF asserted outside first DST byte"
          SEVERITY error;
      END IF;
      IF i = dst'right THEN
        ASSERT dst_valid_i = '1' AND src_valid_i = '0'
        REPORT "dst_valid/src_valid missing on last DST byte"
          SEVERITY error;
        ASSERT dst_i = exp_dst
        REPORT "dst_mac mismatch"
          SEVERITY error;
      ELSE
        ASSERT dst_valid_i = '0' AND src_valid_i = '0'
        REPORT "dst_valid/src_valid asserted too early in DST"
          SEVERITY error;
      END IF;
    END LOOP;

    FOR i IN src'RANGE LOOP
      drive_byte(clk_i, din_o, dv_o, src(i));
      WAIT FOR 0 ns;
      ASSERT data_out_i = src(i)
      REPORT "data_out mismatch in SRC index " & INTEGER'image(i)
        SEVERITY error;
      IF i = src'right THEN
        ASSERT dst_valid_i = '0' AND src_valid_i = '1'
        REPORT "dst_valid/src_valid missing on last SRC byte"
          SEVERITY error;
        ASSERT src_i = exp_src
        REPORT "src_mac mismatch"
          SEVERITY error;
      ELSE
        ASSERT dst_valid_i = '0' AND src_valid_i = '0'
        REPORT "dst_valid/src_valid asserted too early in SRC"
          SEVERITY error;
      END IF;
    END LOOP;

    drive_byte(clk_i, din_o, dv_o, len_f(0));
    WAIT FOR 0 ns;
    ASSERT data_out_i = len_f(0)
    REPORT "data_out mismatch in LEN byte 0"
      SEVERITY error;

    drive_byte(clk_i, din_o, dv_o, len_f(1));
    WAIT FOR 0 ns;
    ASSERT data_out_i = len_f(1)
    REPORT "data_out mismatch in LEN byte 1"
      SEVERITY error;
    ASSERT dst_valid_i = '0' AND src_valid_i = '0'
    REPORT "dst_valid/src_valid asserted too early in LEN byte 1"
      SEVERITY error;
    ASSERT sof_i = '0'
    REPORT "SOF must stay low after DST"
      SEVERITY error;

    FOR i IN payload'RANGE LOOP
      drive_byte(clk_i, din_o, dv_o, payload(i));
      WAIT FOR 0 ns;
      ASSERT data_out_i = payload(i)
      REPORT "data_out mismatch in payload index " & INTEGER'image(i)
        SEVERITY error;
      ASSERT dst_valid_i = '0' AND src_valid_i = '0'
      REPORT "dst_valid/src_valid asserted during payload"
        SEVERITY error;
      ASSERT eof_i = '0'
      REPORT "EOF asserted before frame end"
        SEVERITY error;
    END LOOP;

    FOR i IN fcs'RANGE LOOP
      drive_byte(clk_i, din_o, dv_o, fcs(i));
      WAIT FOR 0 ns;
      ASSERT data_out_i = fcs(i)
      REPORT "data_out mismatch in FCS index " & INTEGER'image(i)
        SEVERITY error;
      ASSERT dst_valid_i = '0' AND src_valid_i = '0'
      REPORT "dst_valid/src_valid asserted during FCS"
        SEVERITY error;
      ASSERT eof_i = '0'
      REPORT "EOF must be pulse-only"
        SEVERITY error;
    END LOOP;

    dv_o <= '0';
    din_o <= (OTHERS => '0');
    WAIT UNTIL rising_edge(clk_i);
    WAIT FOR 0 ns;
    ASSERT eof_i = '1'
    REPORT "EOF missing after data_valid falls"
      SEVERITY error;
  END PROCEDURE;

BEGIN
  dut : ENTITY work.frame_parser
    PORT MAP(
      clk => clk,
      reset => reset,
      data_in => data_in,
      data_valid => data_valid,
      data_out => data_out,
      sof => sof,
      eof => eof,
      dst_valid => dst_valid,
      dst_mac => dst_mac,
      src_valid => src_valid,
      src_mac => src_mac
    );

  p_clk : PROCESS
  BEGIN
    clk <= '0';
    WAIT FOR CLK_PERIOD / 2;
    clk <= '1';
    WAIT FOR CLK_PERIOD / 2;
  END PROCESS;

  p_stim : PROCESS
  BEGIN
    reset <= '0';
    data_valid <= '0';
    data_in <= (OTHERS => '0');
    WAIT FOR 3 * CLK_PERIOD;
    WAIT UNTIL rising_edge(clk);
    reset <= '1';

    REPORT "=== Comprehensive parser test: multiple lengths and MACs ===";

    check_full_frame(
    clk, data_in, data_valid, data_out, sof, eof, dst_valid, src_valid, dst_mac, src_mac,
    DST_A, SRC_A, LEN_A, PAYLOAD_A, FCS_A, "Frame A (len=10)"
    );

    FOR i IN 1 TO 5 LOOP
      data_valid <= '0';
      data_in <= (OTHERS => '0');
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 0 ns;
    END LOOP;

    check_full_frame(
    clk, data_in, data_valid, data_out, sof, eof, dst_valid, src_valid, dst_mac, src_mac,
    DST_B, SRC_B, LEN_B, PAYLOAD_B, FCS_B, "Frame B (len=4)"
    );

    FOR i IN 1 TO 5 LOOP
      data_valid <= '0';
      data_in <= (OTHERS => '0');
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 0 ns;
    END LOOP;

    check_full_frame(
    clk, data_in, data_valid, data_out, sof, eof, dst_valid, src_valid, dst_mac, src_mac,
    DST_C, SRC_C, LEN_C, PAYLOAD_C, FCS_C, "Frame C (len=16)"
    );

    FOR i IN 1 TO 5 LOOP
      data_valid <= '0';
      data_in <= (OTHERS => '0');
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 0 ns;
    END LOOP;

    REPORT "--- Corrupt frame (ERR state) ---";
    send_preamble_and_sfd(clk, data_in, data_valid, sof, dst_valid, src_valid, x"00");
    data_valid <= '0';
    data_in <= (OTHERS => '0');
    WAIT UNTIL rising_edge(clk);
    WAIT FOR 0 ns;
    ASSERT eof = '1'
      REPORT "EOF missing after bad SFD"
      SEVERITY error;
    ASSERT dst_valid = '0' AND src_valid = '0'
      REPORT "Valid pulses must stay low in ERR state"
      SEVERITY error;

    REPORT "All comprehensive parser checks passed." SEVERITY note;
    std.env.stop;
  END PROCESS;

END ARCHITECTURE sim;