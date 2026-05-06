library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_mac_read is
end tb_mac_read;

architecture rtl of tb_mac_read is
    constant ADDR_WIDTH : positive := 13;
    constant DATA_WIDTH : positive := 8;
    constant CLK_PERIOD : time := 8 ns; -- 125 MHz

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- BRAM port A (connected to mac_read)
    signal bram_addr_a : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal bram_q_a    : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal bram_rden_a : std_logic := '0';

    -- BRAM port B (used by testbench to pre-load memory)
    signal bram_addr_b : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal bram_data_b : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal bram_wren_b : std_logic := '0';

    -- mac_read inputs
    signal mac_addr0 : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal mac_req0  : std_logic := '0';
    signal mac_addr1 : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal mac_req1  : std_logic := '0';
    signal mac_addr2 : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal mac_req2  : std_logic := '0';
    signal mac_addr3 : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal mac_req3  : std_logic := '0';

    -- mac_read outputs
    signal dest0  : unsigned(1 downto 0);
    signal valid0 : std_logic;
    signal dest1  : unsigned(1 downto 0);
    signal valid1 : std_logic;
    signal dest2  : unsigned(1 downto 0);
    signal valid2 : std_logic;
    signal dest3  : unsigned(1 downto 0);
    signal valid3 : std_logic;

    -- cycle counter
    signal cycle_count : integer := 0;

begin

    -- Instantiate BRAM
    u_bram : entity work.bram
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            address_a => bram_addr_a,
            address_b => bram_addr_b,
            clock0    => clk,
            data_a    => (others => '0'), -- not used on port A
            data_b    => bram_data_b,
            enable    => '1',
            rden_a    => bram_rden_a,
            rden_b    => '0',
            wren_a    => '0',
            wren_b    => bram_wren_b,
            q_a       => bram_q_a,
            q_b       => open
        );

    -- Instantiate mac_read
    u_mac_read : entity work.mac_read
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk    => clk,
            rst    => rst,
            addr0  => mac_addr0,
            req0   => mac_req0,
            addr1  => mac_addr1,
            req1   => mac_req1,
            addr2  => mac_addr2,
            req2   => mac_req2,
            addr3  => mac_addr3,
            req3   => mac_req3,
            dest0  => dest0,
            valid0 => valid0,
            dest1  => dest1,
            valid1 => valid1,
            dest2  => dest2,
            valid2 => valid2,
            dest3  => dest3,
            valid3 => valid3,
            rdata  => bram_q_a,
            raddr  => bram_addr_a,
            ren    => bram_rden_a
        );

    -- clock
    clk_gen : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    -- cycle counter
    cycle_counter : process(clk)
    begin
        if rising_edge(clk) then
            cycle_count <= cycle_count + 1;
        end if;
    end process;

    stimulus : process
    begin
        -- reset
        rst <= '0';
        wait for 20 ns;
        rst <= '1';
        wait for 20 ns;

        report "============================================" severity NOTE;
        report "TEST: mac_read" severity NOTE;
        report "============================================" severity NOTE;

        -- Pre-load BRAM using port B
        -- Addr 100: invalid (all zeros)
        bram_addr_b <= std_logic_vector(to_unsigned(100, ADDR_WIDTH));
        bram_data_b <= (others => '0');
        bram_wren_b <= '1';
        wait until rising_edge(clk);
        bram_wren_b <= '0';
        wait until rising_edge(clk);

        -- Addr 200: valid entry dest=0 (0xFC)
        bram_addr_b <= std_logic_vector(to_unsigned(200, ADDR_WIDTH));
        bram_data_b <= "11111100";
        bram_wren_b <= '1';
        wait until rising_edge(clk);
        bram_wren_b <= '0';
        wait until rising_edge(clk);

        -- Addr 201: valid entry dest=1 (0xFD)
        bram_addr_b <= std_logic_vector(to_unsigned(201, ADDR_WIDTH));
        bram_data_b <= "11111101";
        bram_wren_b <= '1';
        wait until rising_edge(clk);
        bram_wren_b <= '0';
        wait until rising_edge(clk);

        -- Small wait for memory to settle
        wait for CLK_PERIOD * 2;

        -- PHASE 1: Request address 100 (invalid)
        mac_addr0 <= std_logic_vector(to_unsigned(100, ADDR_WIDTH));
        mac_req0 <= '1';
        wait for CLK_PERIOD * 3; -- allow round robin + read latency
        mac_req0 <= '0';
        wait for CLK_PERIOD * 2;

        if valid0 = '0' then
            report "PASS: addr 100 produced valid0=0 as expected" severity NOTE;
        else
            report "FAIL: addr 100 produced valid0=1 (unexpected)" severity WARNING;
        end if;

        -- PHASE 2: Request address 200 (valid dest 0)
        mac_addr1 <= std_logic_vector(to_unsigned(200, ADDR_WIDTH));
        mac_req1 <= '1';
        wait for CLK_PERIOD * 3;
        mac_req1 <= '0';
        wait for CLK_PERIOD * 2;

        if valid1 = '1' and dest1 = 0 then
            report "PASS: addr 200 produced valid1=1 dest1=0 as expected" severity NOTE;
        else
            report "FAIL: addr 200 mismatch: valid1=" & std_logic'image(valid1) & " dest1=" & integer'image(to_integer(dest1)) severity WARNING;
        end if;

        -- PHASE 3: Request address 201 (valid dest 1)
        mac_addr2 <= std_logic_vector(to_unsigned(201, ADDR_WIDTH));
        mac_req2 <= '1';
        wait for CLK_PERIOD * 3;
        mac_req2 <= '0';
        wait for CLK_PERIOD * 2;

        if valid2 = '1' and dest2 = 1 then
            report "PASS: addr 201 produced valid2=1 dest2=1 as expected" severity NOTE;
        else
            report "FAIL: addr 201 mismatch: valid2=" & std_logic'image(valid2) & " dest2=" & integer'image(to_integer(dest2)) severity WARNING;
        end if;

        report "============================================" severity NOTE;
        report "tb_mac_read finished" severity NOTE;
        report "============================================" severity NOTE;

        wait;
    end process;

end rtl;
