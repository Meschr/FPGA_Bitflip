library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_bram_tdp is
end tb_bram_tdp;

architecture sim of tb_bram_tdp is
    constant DATA_WIDTH : integer := 64;
    constant ADDR_WIDTH : integer := 15;
    constant CLK_PERIOD : time := 8 ns;  -- 125 MHz
    constant ZERO_WORD  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    signal clk_a  : std_logic := '0';
    signal en_a   : std_logic := '0';
    signal addr_a : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal dout_a : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal clk_b  : std_logic := '0';
    signal en_b   : std_logic := '0';
    signal we_b   : std_logic := '0';
    signal addr_b : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal din_b  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

begin
    -- Clock generation for both ports
    clk_a <= not clk_a after CLK_PERIOD/2;
    clk_b <= not clk_b after CLK_PERIOD/2;

    DUT: entity work.bram_tdp
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk_a  => clk_a,
            en_a   => en_a,
            addr_a => addr_a,
            dout_a => dout_a,
            clk_b  => clk_b,
            en_b   => en_b,
            we_b   => we_b,
            addr_b => addr_b,
            din_b  => din_b
        );

    stim: process
        variable hold_value : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        report "========================================" severity note;
        report "tb_bram_tdp started" severity note;
        report "========================================" severity note;

        -- TEST 1: Power-up content should be zero due to RAM initialization
        en_a   <= '1';
        addr_a <= std_logic_vector(to_unsigned(123, ADDR_WIDTH));
        wait until rising_edge(clk_a);
        wait for 1 ns;
        assert dout_a = ZERO_WORD
            report "TEST 1 FAIL: initial read is not zero"
            severity error;
        report "TEST 1 PASS: initial content is zero" severity note;

        -- TEST 2: Write one address on port B and read back on port A
        en_b   <= '1';
        we_b   <= '1';
        addr_b <= std_logic_vector(to_unsigned(123, ADDR_WIDTH));
        din_b  <= x"1122334455667788";
        wait until rising_edge(clk_b);

        we_b <= '0';
        en_b <= '0';

        en_a   <= '1';
        addr_a <= std_logic_vector(to_unsigned(123, ADDR_WIDTH));
        wait until rising_edge(clk_a);
        wait for 1 ns;
        assert dout_a = x"1122334455667788"
            report "TEST 2 FAIL: readback mismatch for address 123"
            severity error;
        report "TEST 2 PASS: write/readback works" severity note;

        -- TEST 3: Read enable low should hold previous output value
        hold_value := dout_a;
        en_a   <= '0';
        addr_a <= std_logic_vector(to_unsigned(500, ADDR_WIDTH));
        wait until rising_edge(clk_a);
        wait for 1 ns;
        assert dout_a = hold_value
            report "TEST 3 FAIL: dout_a changed while en_a = 0"
            severity error;
        report "TEST 3 PASS: output hold behavior with en_a=0" severity note;

        -- TEST 4: Multi-address writes and reads
        en_b   <= '1';
        we_b   <= '1';
        addr_b <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        din_b  <= x"AAAAAAAAAAAAAAAA";
        wait until rising_edge(clk_b);

        addr_b <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
        din_b  <= x"5555555555555555";
        wait until rising_edge(clk_b);

        we_b <= '0';
        en_b <= '0';

        en_a   <= '1';
        addr_a <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
        wait until rising_edge(clk_a);
        wait for 1 ns;
        assert dout_a = x"AAAAAAAAAAAAAAAA"
            report "TEST 4 FAIL: address 1 mismatch"
            severity error;

        addr_a <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
        wait until rising_edge(clk_a);
        wait for 1 ns;
        assert dout_a = x"5555555555555555"
            report "TEST 4 FAIL: address 2 mismatch"
            severity error;
        report "TEST 4 PASS: multi-address accesses work" severity note;

        -- TEST 5: Simultaneous read/write same address
        -- For this RAM style we only check that the next read returns the new value.
        en_a   <= '1';
        en_b   <= '1';
        we_b   <= '1';
        addr_a <= std_logic_vector(to_unsigned(42, ADDR_WIDTH));
        addr_b <= std_logic_vector(to_unsigned(42, ADDR_WIDTH));
        din_b  <= x"DEADBEEFCAFEBABE";
        wait until rising_edge(clk_a);

        we_b <= '0';
        en_b <= '0';
        wait until rising_edge(clk_a);
        wait for 1 ns;
        assert dout_a = x"DEADBEEFCAFEBABE"
            report "TEST 5 FAIL: new data not visible after same-address write"
            severity error;
        report "TEST 5 PASS: same-address write is visible on next read" severity note;

        report "========================================" severity note;
        report "ALL tb_bram_tdp tests passed" severity note;
        report "========================================" severity note;

        wait;
    end process;

end sim;
