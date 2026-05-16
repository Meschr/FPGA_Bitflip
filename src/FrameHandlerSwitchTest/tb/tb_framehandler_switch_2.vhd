library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_framehandler_switch_2 is
end entity tb_framehandler_switch_2;

architecture sim of tb_framehandler_switch_2 is
  constant CLK_PERIOD : time := 10 ns;
  constant DEST_PORT_INSERT_INDEX : natural := 30;

  signal clk                : std_logic := '0';
  signal reset              : std_logic := '1';
  signal dest_port_in       : std_logic_vector(3 downto 0) := (others => '0');
  signal dest_port_in_flag  : std_logic := '0';

  signal tx_data : std_logic_vector(31 downto 0);
  signal tx_ctrl : std_logic_vector(3 downto 0);
  signal rx_data : std_logic_vector(31 downto 0) := (others => '0');
  signal rx_ctrl : std_logic_vector(3 downto 0) := (others => '0');

  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
  type count_array_t is array (natural range <>) of natural;

  signal tx_byte_count : count_array_t(0 to 3) := (others => 0);

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

  procedure transmit_frame_with_port_change(
    signal clk_i : in std_logic;
    signal din_o : out std_logic_vector(7 downto 0);
    signal dv_o  : out std_logic;
    signal port_o : out std_logic_vector(3 downto 0);
    signal port_flag_o : out std_logic;
    constant payload : in byte_array_t;
    constant port_value : in std_logic_vector(3 downto 0);
    constant label_text : in string
  ) is
  begin
    report "--- " & label_text & " ---";

    port_o <= (others => '0');
    port_flag_o <= '0';
    for i in PREAMBLE_BYTES'range loop
      din_o <= PREAMBLE_BYTES(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    din_o <= SFD_BYTE;
    dv_o  <= '1';
    wait until rising_edge(clk_i);

    for i in payload'range loop
      if i = DEST_PORT_INSERT_INDEX then
        port_o <= port_value;
        port_flag_o <= '1';
      else
        port_flag_o <= '0';
      end if;

      din_o <= payload(i);
      dv_o  <= '1';
      wait until rising_edge(clk_i);
    end loop;

    dv_o  <= '0';
    din_o <= (others => '0');
    wait until rising_edge(clk_i);

    port_o <= (others => '0');
    port_flag_o <= '0';
  end procedure;

begin
  dut : entity work.framehandler_switch
    port map (
      clk          => clk,
      reset        => reset,
      dest_port_in => dest_port_in,
      dest_port_in_flag => dest_port_in_flag,
      tx_data      => tx_data,
      tx_ctrl      => tx_ctrl,
      rx_data      => rx_data,
      rx_ctrl      => rx_ctrl
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

  monitor : process(clk)
  begin
    if rising_edge(clk) then
      for p in tx_ctrl'range loop
        if tx_ctrl(p) = '1' then
          tx_byte_count(p) <= tx_byte_count(p) + 1;
        end if;
      end loop;
    end if;
  end process;

  stim : process
    variable port_sel : std_logic_vector(3 downto 0);
  begin
    reset <= '0';
    rx_data <= (others => '0');
    rx_ctrl <= (others => '0');
    dest_port_in <= (others => '0');
    dest_port_in_flag <= '0';
    wait for 4 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '1';
    wait until rising_edge(clk);

    -- Alternating OK/BAD frames with rotating output ports
    for i in 0 to 7 loop
      case (i mod 4) is
        when 0 => port_sel := "0001";
        when 1 => port_sel := "0010";
        when 2 => port_sel := "0100";
        when others => port_sel := "1000";
      end case;

      if (i mod 2) = 0 then
        transmit_frame_with_port_change(
          clk,
          rx_data(7 downto 0),
          rx_ctrl(0),
          dest_port_in,
          dest_port_in_flag,
          FRAME_OK,
          port_sel,
          "FRAME_OK alternating"
        );
      else
        transmit_frame_with_port_change(
          clk,
          rx_data(7 downto 0),
          rx_ctrl(0),
          dest_port_in,
          dest_port_in_flag,
          FRAME_BAD,
          port_sel,
          "FRAME_BAD alternating"
        );
      end if;

      wait for 6 * CLK_PERIOD;
    end loop;

    wait for 140 * CLK_PERIOD;
    assert tx_byte_count(0) > 0
      report "Expected accepted FRAME_OK traffic on TX port 0"
      severity error;
    assert tx_byte_count(1) = 0
      report "Expected FRAME_BAD traffic for TX port 1 to be dropped"
      severity error;
    assert tx_byte_count(2) > 0
      report "Expected accepted FRAME_OK traffic on TX port 2"
      severity error;
    assert tx_byte_count(3) = 0
      report "Expected FRAME_BAD traffic for TX port 3 to be dropped"
      severity error;

    report "framehandler_switch testbench finished." severity note;
    stop;
  end process;

end architecture sim;


