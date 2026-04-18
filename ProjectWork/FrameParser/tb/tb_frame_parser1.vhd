library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac_pkg.all;

entity tb_frame_parser1 is
end entity tb_frame_parser1;

architecture sim of tb_frame_parser1 is

  signal clk            : std_logic := '0';
  signal reset          : std_logic := '1';
  signal data_in        : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid     : std_logic := '0';
  signal fcs_valid      : std_logic := '0';

  signal data_out       : std_logic_vector(7 downto 0);
  signal data_out_valid : std_logic;
  signal sof            : std_logic;
  signal eof            : std_logic;
  signal frame_len      : unsigned(13 downto 0);
  signal dst_mac        : mac_addr_t;
  signal src_mac        : mac_addr_t;
  signal dst_mac_valid  : std_logic;
  signal src_mac_valid  : std_logic;
  signal ethertype      : std_logic_vector(15 downto 0);

  constant CLK_PERIOD : time := 10 ns;

  type byte_array_t is array(natural range <>) of std_logic_vector(7 downto 0);

  constant PREAMBLE_AND_SFD : byte_array_t(0 to 7) := (
    x"55", x"55", x"55", x"55", x"55", x"55", x"55", x"D5"
  );

  constant ETH_FRAME_WITH_FCS : byte_array_t(0 to 63) := (
    -- Destination MAC + Source MAC + EtherType
    x"00", x"10", x"A4", x"7B", x"EA", x"80",
    x"00", x"12", x"34", x"56", x"78", x"90",
    x"08", x"00",
    -- Payload + FCS (FCS = E6 C5 3D B2)
    x"45", x"00", x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", x"11", x"05", x"40",
    x"C0", x"A8", x"00", x"2C", x"C0", x"A8", x"00", x"04", x"04", x"00", x"04", x"00",
    x"00", x"1A", x"2D", x"E8", x"00", x"01", x"02", x"03", x"04", x"05", x"06", x"07",
    x"08", x"09", x"0A", x"0B", x"0C", x"0D", x"0E", x"0F", x"10", x"11", x"E6", x"C5",
    x"3D", x"B2"
  );

  constant EXP_DST : mac_addr_t := x"0010A47BEA80";
  constant EXP_SRC : mac_addr_t := x"001234567890";
  constant EXP_ETH : std_logic_vector(15 downto 0) := x"0800";
  constant EXP_LEN : unsigned(13 downto 0) := to_unsigned(64, 14);

begin

  DUT : entity work.frame_parser1
    port map (
      clk            => clk,
      reset          => reset,
      data_in        => data_in,
      data_valid     => data_valid,
      fcs_valid      => fcs_valid,
      data_out       => data_out,
      data_out_valid => data_out_valid,
      sof            => sof,
      eof            => eof,
      frame_len      => frame_len,
      dst_mac        => dst_mac,
      src_mac        => src_mac,
      dst_mac_valid  => dst_mac_valid,
      src_mac_valid  => src_mac_valid,
      ethertype      => ethertype
    );

  p_clk : process
  begin
    clk <= '0'; wait for CLK_PERIOD / 2;
    clk <= '1'; wait for CLK_PERIOD / 2;
  end process;

  p_stim : process
    variable exp_idx  : integer := 0;
    variable eof_seen : boolean := false;
  begin
    reset <= '1';
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    reset <= '0';
    wait for CLK_PERIOD;

    report "=== Test 1: preamble skipped, frame parsed, fcs_valid gates header ===";

    data_valid <= '1';

    -- preamble + SFD (must NOT appear on data_out)
    for i in PREAMBLE_AND_SFD'range loop
      data_in <= PREAMBLE_AND_SFD(i);
      wait until rising_edge(clk);
      assert data_out_valid = '0'
        report "ERROR: data_out_valid asserted during preamble/SFD" severity error;
    end loop;

    -- frame bytes (must appear on data_out)
    for i in ETH_FRAME_WITH_FCS'range loop
      data_in <= ETH_FRAME_WITH_FCS(i);
      wait until rising_edge(clk);
      if data_out_valid = '1' then
        assert data_out = ETH_FRAME_WITH_FCS(exp_idx)
          report "ERROR: data_out byte mismatch" severity error;
        if exp_idx = 0 then
          assert sof = '1'
            report "ERROR: sof not asserted with first DST byte" severity error;
        else
          assert sof = '0'
            report "ERROR: sof asserted outside first DST byte" severity error;
        end if;
        exp_idx := exp_idx + 1;
      end if;
    end loop;

    data_valid <= '0';
    data_in    <= (others => '0');

    for j in 0 to 2 loop
      wait until rising_edge(clk);
      if eof = '1' then
        eof_seen := true;
      end if;
      if data_out_valid = '1' and exp_idx < ETH_FRAME_WITH_FCS'length then
        assert data_out = ETH_FRAME_WITH_FCS(exp_idx)
          report "ERROR: data_out byte mismatch (tail)" severity error;
        if exp_idx = 0 then
          assert sof = '1'
            report "ERROR: sof not asserted with first DST byte (tail)" severity error;
        else
          assert sof = '0'
            report "ERROR: sof asserted outside first DST byte (tail)" severity error;
        end if;
        exp_idx := exp_idx + 1;
      end if;
    end loop;

    report "Observed bytes: " & integer'image(exp_idx) severity note;

    assert exp_idx = ETH_FRAME_WITH_FCS'length
      report "ERROR: not all frame bytes observed on data_out" severity error;
    assert eof_seen
      report "ERROR: eof not asserted after frame" severity error;
    assert frame_len = EXP_LEN
      report "ERROR: frame_len mismatch" severity error;

    -- pulse fcs_valid to release MACs
    fcs_valid <= '1';
    wait until rising_edge(clk);
    fcs_valid <= '0';

    wait until rising_edge(clk);
    assert dst_mac_valid = '1' and src_mac_valid = '1'
      report "ERROR: MAC valid not asserted after fcs_valid" severity error;
    assert dst_mac = EXP_DST
      report "ERROR: dst_mac mismatch" severity error;
    assert src_mac = EXP_SRC
      report "ERROR: src_mac mismatch" severity error;
    assert ethertype = EXP_ETH
      report "ERROR: ethertype mismatch" severity error;

    report "Test 1 PASSED";

    wait for 5 * CLK_PERIOD;
    report "=== All tests completed ===" severity note;
    std.env.stop;
  end process;

end architecture sim;
