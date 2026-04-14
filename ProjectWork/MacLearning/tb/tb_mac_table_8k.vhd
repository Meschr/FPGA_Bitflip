library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.mac_table_pkg.ALL;

entity tb_mac_table_8k is
end tb_mac_table_8k;

architecture sim of tb_mac_table_8k is
    constant CLK_PERIOD : time := 8 ns;
    constant ZERO_PORT  : std_logic_vector(PORT_WIDTH-1 downto 0) := (others => '0');

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal lookup_mac  : std_logic_vector(MAC_WIDTH-1 downto 0) := (others => '0');
    signal lookup_req  : std_logic := '0';
    signal lookup_hit  : std_logic;
    signal lookup_port : std_logic_vector(PORT_WIDTH-1 downto 0);
    signal lookup_done : std_logic;
    signal learn_mac   : std_logic_vector(MAC_WIDTH-1 downto 0) := (others => '0');
    signal learn_port  : std_logic_vector(PORT_WIDTH-1 downto 0) := (others => '0');
    signal learn_req   : std_logic := '0';
    signal learn_done  : std_logic;
    signal age_tick    : std_logic := '0';

    procedure pulse(signal sig : out std_logic) is
    begin
        sig <= '1';
        wait for CLK_PERIOD;
        sig <= '0';
        wait for CLK_PERIOD;
    end procedure;

    procedure write_entry(
        signal learn_mac_s  : out std_logic_vector(MAC_WIDTH-1 downto 0);
        signal learn_port_s : out std_logic_vector(PORT_WIDTH-1 downto 0);
        signal learn_req_s  : out std_logic;
        constant mac  : in std_logic_vector(MAC_WIDTH-1 downto 0);
        constant dst_port : in std_logic_vector(PORT_WIDTH-1 downto 0)
    ) is
    begin
        learn_mac_s  <= mac;
        learn_port_s <= dst_port;
        learn_req_s  <= '1';
        wait until rising_edge(clk);
        learn_req_s  <= '0';
        wait until learn_done = '1';
        wait until rising_edge(clk);
    end procedure;

    procedure read_entry(
        signal lookup_mac_s  : out std_logic_vector(MAC_WIDTH-1 downto 0);
        signal lookup_req_s  : out std_logic;
        constant mac        : in std_logic_vector(MAC_WIDTH-1 downto 0);
        constant expect_hit : in std_logic;
        constant expect_port : in std_logic_vector(PORT_WIDTH-1 downto 0)
    ) is
    begin
        lookup_mac_s <= mac;
        lookup_req_s <= '1';
        wait until rising_edge(clk);
        lookup_req_s <= '0';
        wait until lookup_done = '1';
        wait until rising_edge(clk);

        assert lookup_hit = expect_hit
            report "lookup_hit mismatch for MAC " & integer'image(to_integer(unsigned(mac(7 downto 0))))
            severity error;

        if expect_hit = '1' then
            assert lookup_port = expect_port
                report "lookup_port mismatch"
                severity error;
        end if;
    end procedure;

begin
    clk <= not clk after CLK_PERIOD/2;

    dut: entity work.mac_table_8k
        port map (
            clk         => clk,
            rst         => rst,
            lookup_mac  => lookup_mac,
            lookup_req  => lookup_req,
            lookup_hit  => lookup_hit,
            lookup_port => lookup_port,
            lookup_done => lookup_done,
            learn_mac   => learn_mac,
            learn_port  => learn_port,
            learn_req   => learn_req,
            learn_done  => learn_done,
            age_tick    => age_tick
        );

    stim: process
    begin
        wait for 4 * CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;

        report "tb_mac_table_8k: basic write/read test start" severity note;

        -- Read miss before any write.
        read_entry(lookup_mac, lookup_req, x"001122334455", '0', ZERO_PORT);

        -- Write one MAC and read it back.
        write_entry(learn_mac, learn_port, learn_req, x"001122334455", "01");
        read_entry(lookup_mac, lookup_req, x"001122334455", '1', "01");

        -- Write a second MAC and verify both entries.
        write_entry(learn_mac, learn_port, learn_req, x"AABBCCDDEEFF", "10");
        read_entry(lookup_mac, lookup_req, x"AABBCCDDEEFF", '1', "10");
        read_entry(lookup_mac, lookup_req, x"001122334455", '1', "01");

        -- Update same MAC on different port.
        write_entry(learn_mac, learn_port, learn_req, x"001122334455", "11");
        read_entry(lookup_mac, lookup_req, x"001122334455", '1', "11");

        report "tb_mac_table_8k: all basic tests passed" severity note;
        wait;
    end process;
end sim;
