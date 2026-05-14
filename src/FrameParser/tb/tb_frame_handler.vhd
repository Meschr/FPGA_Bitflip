LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY std;
USE std.env.ALL;

ENTITY tb_frame_handler IS
END ENTITY tb_frame_handler;

ARCHITECTURE sim OF tb_frame_handler IS
  CONSTANT CLK_PERIOD : TIME := 10 ns;
  CONSTANT MAX_WAIT_CYCLES : NATURAL := 40;

  SIGNAL clk : STD_LOGIC := '0';
  SIGNAL reset : STD_LOGIC := '1';
  SIGNAL data_in : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL data_valid : STD_LOGIC := '0';
  SIGNAL buffer_dest_port : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL buffer_dest_port_flag : STD_LOGIC := '1';

  SIGNAL data_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL dst_port : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL crc_valid : STD_LOGIC;
  SIGNAL eof_handler : STD_LOGIC;
  SIGNAL frame_rdy_handler : STD_LOGIC;
  SIGNAL full_buffer : STD_LOGIC_VECTOR(3 DOWNTO 0);

  TYPE byte_array_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

  CONSTANT PREAMBLE_BYTES : byte_array_t(0 to 6) := (
    x"55", x"55", x"55", x"55", x"55", x"55", x"55"
  );

  CONSTANT SFD_BYTE : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"D5";

  CONSTANT FRAME_OK : byte_array_t(0 to 63) := (
    x"00", x"10", x"A4", x"7B", x"EA", x"80", x"00", x"12",
    x"34", x"56", x"78", x"90", x"08", x"00", x"45", x"00",
    x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", x"11",
    x"05", x"40", x"C0", x"A8", x"00", x"2C", x"C0", x"A8",
    x"00", x"04", x"04", x"00", x"04", x"00", x"00", x"1A",
    x"2D", x"E8", x"00", x"01", x"02", x"03", x"04", x"05",
    x"06", x"07", x"08", x"09", x"0A", x"0B", x"0C", x"0D",
    x"0E", x"0F", x"10", x"11",
    x"E6", x"C5", x"3D", x"B2"
  );

  CONSTANT FRAME_BAD : byte_array_t(0 to 63) := (
    x"00", x"10", x"A4", x"7B", x"EA", x"80", x"00", x"12",
    x"34", x"56", x"79", x"90", x"08", x"00", x"45", x"00",
    x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", x"11",
    x"05", x"40", x"C0", x"A8", x"00", x"2C", x"C0", x"A8",
    x"00", x"04", x"04", x"00", x"04", x"00", x"00", x"1A",
    x"2D", x"E8", x"00", x"01", x"02", x"03", x"04", x"05",
    x"06", x"07", x"08", x"09", x"0A", x"0B", x"0C", x"0D",
    x"0E", x"0F", x"10", x"11",
    x"E6", x"C5", x"3D", x"B2"
  );

  PROCEDURE transmit_wire_frame(
    SIGNAL clk_i : IN STD_LOGIC;
    SIGNAL din_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL dv_o : OUT STD_LOGIC;
    CONSTANT payload : IN byte_array_t;
    CONSTANT label_text : IN STRING
  ) IS
  BEGIN
    REPORT "--- " & label_text & " ---";

    FOR i IN PREAMBLE_BYTES'RANGE LOOP
      din_o <= PREAMBLE_BYTES(i);
      dv_o <= '1';
      WAIT UNTIL rising_edge(clk_i);
    END LOOP;

    din_o <= PREAMBLE_BYTES(PREAMBLE_BYTES'high);
    dv_o <= '1';
    WAIT UNTIL rising_edge(clk_i);

    din_o <= SFD_BYTE;
    dv_o <= '1';
    WAIT UNTIL rising_edge(clk_i);

    FOR i IN payload'RANGE LOOP
      din_o <= payload(i);
      dv_o <= '1';
      WAIT UNTIL rising_edge(clk_i);
    END LOOP;

    dv_o <= '0';
    din_o <= (OTHERS => '1');
    WAIT UNTIL rising_edge(clk_i);
  END PROCEDURE;

  PROCEDURE expect_buffer_output(
    SIGNAL clk_i : IN STD_LOGIC;
    SIGNAL dout_i : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL port_i : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL crc_ok_i : IN STD_LOGIC;
    SIGNAL eof_i : IN STD_LOGIC;
    SIGNAL ready_i : IN STD_LOGIC;
    SIGNAL full_i : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    CONSTANT expected_port : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

    CONSTANT payload : IN byte_array_t;
    CONSTANT label_text : IN STRING
  ) IS
  BEGIN
    WAIT FOR 0 ns;
    ASSERT crc_ok_i = '1'
      REPORT label_text & ": crc_valid pulse missing"
      SEVERITY error;

    FOR cycle IN 0 TO MAX_WAIT_CYCLES LOOP
      WAIT UNTIL rising_edge(clk_i);
      WAIT FOR 0 ns;
      EXIT WHEN port_i = expected_port;
    END LOOP;

    ASSERT port_i = expected_port
      REPORT label_text & ": expected port " & INTEGER'image(to_integer(unsigned(expected_port))) & " but got " & INTEGER'image(to_integer(unsigned(port_i)))
      SEVERITY error;
    ASSERT ready_i = '0'
      REPORT label_text & ": frame_rdy_handler not asserted"
      SEVERITY error;

    ASSERT dout_i = payload(payload'low)
      REPORT label_text & ": output byte 0 mismatch"
      SEVERITY error;
    ASSERT eof_i = '1'
      REPORT label_text & ": EOF asserted too early"
      SEVERITY error;
    ASSERT full_i = "0000"
      REPORT label_text & ": buffer unexpectedly full"
      SEVERITY error;

    FOR i IN payload'low + 1 TO payload'high LOOP
      WAIT UNTIL rising_edge(clk_i);
      WAIT FOR 0 ns;
      ASSERT port_i = expected_port
        REPORT label_text & ": port changed during read"
        SEVERITY error;
      ASSERT dout_i = payload(i)
        REPORT label_text & ": output byte mismatch at index " & INTEGER'image(i)
        SEVERITY error;
      IF i = payload'high THEN
        ASSERT eof_i = '0'
          REPORT label_text & ": EOF missing on last output byte"
          SEVERITY error;
      ELSE
        ASSERT eof_i = '0'
          REPORT label_text & ": EOF asserted too early"
          SEVERITY error;
      END IF;
      ASSERT full_i = "0000"
        REPORT label_text & ": buffer unexpectedly full"
        SEVERITY error;
    END LOOP;

    WAIT UNTIL rising_edge(clk_i);
    WAIT FOR 0 ns;
    ASSERT port_i = "0000"
      REPORT label_text & ": port not released"
      SEVERITY error;
    ASSERT ready_i = '0'
      REPORT label_text & ": frame_rdy_handler not released"
      SEVERITY error;
  END PROCEDURE;

  PROCEDURE expect_no_buffer_output(
    SIGNAL clk_i : IN STD_LOGIC;
    SIGNAL port_i : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL crc_ok_i : IN STD_LOGIC;
    SIGNAL eof_i : IN STD_LOGIC;
    SIGNAL ready_i : IN STD_LOGIC;
    CONSTANT label_text : IN STRING
  ) IS
  BEGIN
    FOR cycle IN 0 TO MAX_WAIT_CYCLES LOOP
      WAIT UNTIL rising_edge(clk_i);
      WAIT FOR 0 ns;
      ASSERT crc_ok_i = '0'
        REPORT label_text & ": unexpected crc_valid pulse"
        SEVERITY error;
      ASSERT port_i = "0000"
        REPORT label_text & ": unexpected VOQ activity"
        SEVERITY error;
      ASSERT eof_i = '0'
        REPORT label_text & ": unexpected EOF pulse"
        SEVERITY error;
      ASSERT ready_i = '0'
        REPORT label_text & ": unexpected frame_rdy_handler pulse"
        SEVERITY error;
    END LOOP;
  END PROCEDURE;

BEGIN
  dut : ENTITY work.frame_handler
    PORT MAP(
      clk => clk,
      reset => reset,
      data_in => data_in,
      data_valid => data_valid,
      buffer_dest_port => buffer_dest_port,
      buffer_dest_port_flag => buffer_dest_port_flag,
      data_out => data_out,
      dst_port => dst_port,
      crc_valid => crc_valid,
      eof_handler => eof_handler,
      frame_rdy => frame_rdy_handler,
      full_buffer => full_buffer
    );

  clk_gen : PROCESS
  BEGIN
    WHILE true LOOP
      clk <= '0';
      WAIT FOR CLK_PERIOD / 2;
      clk <= '1';
      WAIT FOR CLK_PERIOD / 2;
    END LOOP;
  END PROCESS;

  stim : PROCESS
  BEGIN
    reset <= '0';
    data_in <= (OTHERS => '0');
    data_valid <= '0';
    buffer_dest_port_flag <= '0';
    WAIT FOR 4 * CLK_PERIOD;
    WAIT UNTIL rising_edge(clk);
    reset <= '1';
    WAIT UNTIL rising_edge(clk);

    buffer_dest_port <= "0001";
    buffer_dest_port_flag <= '0';
    WAIT UNTIL rising_edge(clk);
    buffer_dest_port_flag <= '1';
    -- Test Frame 1: Port 1
    transmit_wire_frame(clk, data_in, data_valid, FRAME_OK, "Frame to Port 1");
    expect_buffer_output(clk, data_out, dst_port, crc_valid, eof_handler, frame_rdy_handler, full_buffer,
      "0001", FRAME_OK, "Port 1 output");

    buffer_dest_port <= "0010";
    buffer_dest_port_flag <= '0';
    WAIT UNTIL rising_edge(clk);
    buffer_dest_port_flag <= '1';
    -- Test Frame 2: Port 2
    transmit_wire_frame(clk, data_in, data_valid, FRAME_OK, "Frame to Port 2");
    expect_buffer_output(clk, data_out, dst_port, crc_valid, eof_handler, frame_rdy_handler, full_buffer,
      "0010", FRAME_OK, "Port 2 output");

    buffer_dest_port <= "0100";
    buffer_dest_port_flag <= '0';
    WAIT UNTIL rising_edge(clk);
    buffer_dest_port_flag <= '1';
    -- Test Frame 3: Port 3
    transmit_wire_frame(clk, data_in, data_valid, FRAME_OK, "Frame to Port 3");
    expect_buffer_output(clk, data_out, dst_port, crc_valid, eof_handler, frame_rdy_handler, full_buffer,
      "0100", FRAME_OK, "Port 3 output");

    -- Test corrupt frame (should not activate any port)
    transmit_wire_frame(clk, data_in, data_valid, FRAME_BAD, "corrupt frame");
    expect_no_buffer_output(clk, dst_port, crc_valid, eof_handler, frame_rdy_handler, "corrupt frame");

    -- Reset and test again (Port 1)
    reset <= '1';
    WAIT FOR 3 * CLK_PERIOD;
    buffer_dest_port_flag <= '0';
    WAIT UNTIL rising_edge(clk);
    buffer_dest_port_flag <= '0';
    WAIT UNTIL rising_edge(clk);
    reset <= '0';
    WAIT UNTIL rising_edge(clk);

    buffer_dest_port <= "0001";
    transmit_wire_frame(clk, data_in, data_valid, FRAME_OK, "Frame to Port 1 after reset");
    expect_buffer_output(clk, data_out, dst_port, crc_valid, eof_handler, frame_rdy_handler, full_buffer,
      "0001", FRAME_OK, "Port 1 output after reset");

    REPORT "All 3-port frame_handler checks passed." SEVERITY note;
    std.env.stop;
  END PROCESS;

END ARCHITECTURE sim;