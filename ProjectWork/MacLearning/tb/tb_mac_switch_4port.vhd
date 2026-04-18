library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_mac_switch_4port is
end tb_mac_switch_4port;

architecture sim of tb_mac_switch_4port is
    constant NUM_PORTS  : integer := 4;
    constant MAC_W      : integer := 48;
    constant PORT_W     : integer := 2;
    constant CLK_PERIOD : time := 8 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal lookup_req_valid : std_logic_vector(NUM_PORTS-1 downto 0) := (others => '0');
    signal lookup_req_mac   : std_logic_vector(NUM_PORTS*MAC_W-1 downto 0) := (others => '0');
    signal lookup_req_port  : std_logic_vector(NUM_PORTS*PORT_W-1 downto 0) := (others => '0');

    signal learn_req_valid  : std_logic_vector(NUM_PORTS-1 downto 0) := (others => '0');
    signal learn_req_mac    : std_logic_vector(NUM_PORTS*MAC_W-1 downto 0) := (others => '0');
    signal learn_req_port   : std_logic_vector(NUM_PORTS*PORT_W-1 downto 0) := (others => '0');

    signal lookup_hit       : std_logic_vector(NUM_PORTS-1 downto 0);
    signal lookup_dst_port  : std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);
    signal lookup_done      : std_logic_vector(NUM_PORTS-1 downto 0);
    signal learn_done       : std_logic_vector(NUM_PORTS-1 downto 0);
    signal age_tick         : std_logic := '0';

    function lane_slice(
        vec        : std_logic_vector;
        lane       : natural;
        lane_width : natural
    ) return std_logic_vector is
        variable result : std_logic_vector(lane_width-1 downto 0);
        variable hi     : integer;
        variable lo     : integer;
    begin
        hi := integer(lane + 1) * integer(lane_width) - 1;
        lo := integer(lane) * integer(lane_width);
        result := vec(hi downto lo);
        return result;
    end function;

    procedure set_lookup(
        signal lookup_req_valid_s : out std_logic_vector(NUM_PORTS-1 downto 0);
        signal lookup_req_mac_s   : out std_logic_vector(NUM_PORTS*MAC_W-1 downto 0);
        signal lookup_req_port_s  : out std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);
        constant port_idx : in natural;
        constant mac      : in std_logic_vector(MAC_W-1 downto 0);
        constant src_port : in std_logic_vector(PORT_W-1 downto 0)
    ) is
    begin
        lookup_req_mac_s((port_idx + 1) * MAC_W - 1 downto port_idx * MAC_W) <= mac;
        lookup_req_port_s((port_idx + 1) * PORT_W - 1 downto port_idx * PORT_W) <= src_port;
        lookup_req_valid_s(port_idx) <= '1';
    end procedure;

    procedure set_learn(
        signal learn_req_valid_s : out std_logic_vector(NUM_PORTS-1 downto 0);
        signal learn_req_mac_s   : out std_logic_vector(NUM_PORTS*MAC_W-1 downto 0);
        signal learn_req_port_s  : out std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);
        constant port_idx : in natural;
        constant mac      : in std_logic_vector(MAC_W-1 downto 0);
        constant dst_port : in std_logic_vector(PORT_W-1 downto 0)
    ) is
    begin
        learn_req_mac_s((port_idx + 1) * MAC_W - 1 downto port_idx * MAC_W) <= mac;
        learn_req_port_s((port_idx + 1) * PORT_W - 1 downto port_idx * PORT_W) <= dst_port;
        learn_req_valid_s(port_idx) <= '1';
    end procedure;

begin
    clk <= not clk after CLK_PERIOD/2;

    dut: entity work.mac_switch_4port
        generic map (
            NUM_PORTS => NUM_PORTS,
            MAC_W     => MAC_W,
            PORT_W    => PORT_W
        )
        port map (
            clk             => clk,
            rst             => rst,
            lookup_req_valid => lookup_req_valid,
            lookup_req_mac   => lookup_req_mac,
            lookup_req_port  => lookup_req_port,
            learn_req_valid  => learn_req_valid,
            learn_req_mac    => learn_req_mac,
            learn_req_port   => learn_req_port,
            lookup_hit       => lookup_hit,
            lookup_dst_port  => lookup_dst_port,
            lookup_done      => lookup_done,
            learn_done       => learn_done,
            age_tick         => age_tick
        );

    stim: process
    begin
        wait for 4 * CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;

        report "tb_mac_switch_4port: start" severity note;

        -- Learn on port 0, verify that a later lookup from port 1 hits.
        set_learn(learn_req_valid, learn_req_mac, learn_req_port, 0, x"001122334455", "01");
        wait until rising_edge(clk);
        learn_req_valid <= (others => '0');
        wait until learn_done(0) = '1';
        wait until rising_edge(clk);

        set_lookup(lookup_req_valid, lookup_req_mac, lookup_req_port, 1, x"001122334455", "01");
        wait until rising_edge(clk);
        lookup_req_valid <= (others => '0');
        wait until lookup_done(1) = '1';
        wait until rising_edge(clk);

        assert lookup_hit(1) = '1'
            report "4-port test failed: expected lookup hit on port 1"
            severity error;
        assert lane_slice(lookup_dst_port, 1, PORT_W) = "01"
            report "4-port test failed: destination port mismatch"
            severity error;

        -- Burst of requests from different ports to exercise the FIFO path.
        set_learn(learn_req_valid, learn_req_mac, learn_req_port, 2, x"AABBCCDDEEFF", "10");
        set_learn(learn_req_valid, learn_req_mac, learn_req_port, 3, x"010203040506", "11");
        wait until rising_edge(clk);
        learn_req_valid <= (others => '0');
        wait for 20 * CLK_PERIOD;

        report "tb_mac_switch_4port: basic checks passed" severity note;
        wait;
    end process;
end sim;
