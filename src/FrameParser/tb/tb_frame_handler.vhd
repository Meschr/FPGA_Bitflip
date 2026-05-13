library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_frame_handler is
end entity tb_frame_handler;

architecture sim of tb_frame_handler is
  constant CLK_PERIOD : time := 10 ns;
  constant MAX_WAIT_CYCLES : natural := 40;

  signal clk        : std_logic := '0';
  signal reset      : std_logic := '1';
  signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid : std_logic := '0';
  signal buffer_dest_port : std_logic_vector(3 downto 0) := (others => '0');
  signal buffer_dest_port_flag : std_logic := '1';

  signal data_out           : std_logic_vector(7 downto 0);
  signal dst_port           : std_logic_vector(3 downto 0);
  signal crc_valid          : std_logic;
  signal eof_handler        : std_logic;
  signal frame_rdy_handler  : std_logic;
  signal full_buffer        : std_logic_vector(3 downto 0);

  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

  constant PREAMBLE_BYTES : byte_array_t(0 to 6) := (
    x"55", x"55", x"55", x"55", x"55", x"55", x"55"
  );

  constant SFD_BYTE : std_logic_vector(7 downto 0) := x"D5";

  constant FRAME_OK : byte_array_t(0 to 63) := (
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

  constant FRAME_BAD : byte_array_t(0 to 63) := (
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

  procedure transmit_wire_frame(
    signal clk_i : in std_logic;
    signal din_o : out std_logic_vector(7 downto 0);
    signal dv_o  : out std_logic;
    constant payload : in byte_array_t;
    constant label_text : in string
  ) is
  begin
    report "--- " & label_text & " ---";

    for i in PREAMBLE_BYTES'range loop
      din_o <= PREAMBLE_BYTES(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    din_o <= SFD_BYTE;
    dv_o  <= '1';
    wait until rising_edge(clk_i);

    for i in payload'range loop
      din_o <= payload(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    dv_o  <= '0';
    din_o <= (others => '0');
    wait until rising_edge(clk_i);
  end procedure;

  procedure expect_buffer_output(
    signal clk_i : in std_logic;
    signal dout_i : in std_logic_vector(7 downto 0);
    signal port_i : in std_logic_vector(3 downto 0);
    signal crc_ok_i : in std_logic;
    signal eof_i : in std_logic;
    signal ready_i : in std_logic;
    signal full_i : in std_logic_vector(3 downto 0);
    constant expected_port : in std_logic_vector(3 downto 0);

    constant payload : in byte_array_t;
    constant label_text : in string
  ) is
  begin
    wait for 0 ns;
    assert crc_ok_i = '1'
      report label_text & ": crc_valid pulse missing"
      severity error;

    for cycle in 0 to MAX_WAIT_CYCLES loop
      wait until rising_edge(clk_i);
      wait for 0 ns;
      exit when port_i = expected_port;
    end loop;

    assert port_i = expected_port
      report label_text & ": expected port " & integer'image(to_integer(unsigned(expected_port))) & " but got " & integer'image(to_integer(unsigned(port_i)))
      severity error;
    assert ready_i = '1'
      report label_text & ": frame_rdy_handler not asserted"
      severity error;

    assert dout_i = payload(payload'low)
      report label_text & ": output byte 0 mismatch"
      severity error;
    assert eof_i = '0'
      report label_text & ": EOF asserted too early"
      severity error;
    assert full_i = "0000"
      report label_text & ": buffer unexpectedly full"
      severity error;

    for i in payload'low + 1 to payload'high loop
      wait until rising_edge(clk_i);
      wait for 0 ns;
      assert port_i = expected_port
        report label_text & ": port changed during read"
        severity error;
      assert dout_i = payload(i)
        report label_text & ": output byte mismatch at index " & integer'image(i)
        severity error;
      if i = payload'high then
        assert eof_i = '1'
          report label_text & ": EOF missing on last output byte"
          severity error;
      else
        assert eof_i = '0'
          report label_text & ": EOF asserted too early"
          severity error;
      end if;
      assert full_i = "0000"
        report label_text & ": buffer unexpectedly full"
        severity error;
    end loop;

    wait until rising_edge(clk_i);
    wait for 0 ns;
    assert port_i = "0000"
      report label_text & ": port not released"
      severity error;
    assert ready_i = '0'
      report label_text & ": frame_rdy_handler not released"
      severity error;
  end procedure;

  procedure expect_no_buffer_output(
    signal clk_i : in std_logic;
    signal port_i : in std_logic_vector(3 downto 0);
    signal crc_ok_i : in std_logic;
    signal eof_i : in std_logic;
    signal ready_i : in std_logic;
    constant label_text : in string
  ) is
  begin
    for cycle in 0 to MAX_WAIT_CYCLES loop
      wait until rising_edge(clk_i);
      wait for 0 ns;
      assert crc_ok_i = '0'
        report label_text & ": unexpected crc_valid pulse"
        severity error;
      assert port_i = "0000"
        report label_text & ": unexpected VOQ activity"
        severity error;
      assert eof_i = '0'
        report label_text & ": unexpected EOF pulse"
        severity error;
      assert ready_i = '0'
        report label_text & ": unexpected frame_rdy_handler pulse"
        severity error;
    end loop;
  end procedure;

begin
  dut : entity work.frame_handler
    port map (
      clk                    => clk,
      reset                  => reset,
      data_in                => data_in,
      data_valid             => data_valid,
      buffer_dest_port       => buffer_dest_port,
      buffer_dest_port_flag  => buffer_dest_port_flag,
      data_out               => data_out,
      dst_port               => dst_port,
      crc_valid              => crc_valid,
      eof_handler            => eof_handler,
      frame_rdy_handler      => frame_rdy_handler,
      full_buffer            => full_buffer
    );

  clk_gen : process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process;

  stim : process
  begin
    reset <= '1';
    data_in <= (others => '0');
    data_valid <= '0';
      buffer_dest_port_flag <= '0';
    wait for 4 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);

    buffer_dest_port <= "0001";
      buffer_dest_port_flag <= '1';
      wait until rising_edge(clk);
      buffer_dest_port_flag <= '0';
    -- Test Frame 1: Port 1
    transmit_wire_frame(clk, data_in, data_valid, FRAME_OK, "Frame to Port 1");
    expect_buffer_output(clk, data_out, dst_port, crc_valid, eof_handler, frame_rdy_handler, full_buffer,
              "0001", FRAME_OK, "Port 1 output");

    buffer_dest_port <= "0010";
      buffer_dest_port_flag <= '1';
      wait until rising_edge(clk);
      buffer_dest_port_flag <= '0';
    -- Test Frame 2: Port 2
    transmit_wire_frame(clk, data_in, data_valid, FRAME_OK, "Frame to Port 2");
    expect_buffer_output(clk, data_out, dst_port, crc_valid, eof_handler, frame_rdy_handler, full_buffer,
              "0010", FRAME_OK, "Port 2 output");

    buffer_dest_port <= "0100";
      buffer_dest_port_flag <= '1';
      wait until rising_edge(clk);
      buffer_dest_port_flag <= '0';
    -- Test Frame 3: Port 3
    transmit_wire_frame(clk, data_in, data_valid, FRAME_OK, "Frame to Port 3");
    expect_buffer_output(clk, data_out, dst_port, crc_valid, eof_handler, frame_rdy_handler, full_buffer,
              "0100", FRAME_OK, "Port 3 output");

    -- Test corrupt frame (should not activate any port)
    transmit_wire_frame(clk, data_in, data_valid, FRAME_BAD, "corrupt frame");
    expect_no_buffer_output(clk, dst_port, crc_valid, eof_handler, frame_rdy_handler, "corrupt frame");

    -- Reset and test again (Port 1)
    reset <= '1';
    wait for 3 * CLK_PERIOD;
      buffer_dest_port_flag <= '1';
      wait until rising_edge(clk);
      buffer_dest_port_flag <= '0';
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);

    buffer_dest_port <= "0001";
    transmit_wire_frame(clk, data_in, data_valid, FRAME_OK, "Frame to Port 1 after reset");
    expect_buffer_output(clk, data_out, dst_port, crc_valid, eof_handler, frame_rdy_handler, full_buffer,
              "0001", FRAME_OK, "Port 1 output after reset");

    report "All 3-port frame_handler checks passed." severity note;
    stop;
  end process;

end architecture sim;
