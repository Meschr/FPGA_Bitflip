library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_mac_write is
end tb_mac_write;

architecture rtl of tb_mac_write is
    -- Constants
    constant ADDR_WIDTH : POSITIVE := 13;
    constant DATA_WIDTH : POSITIVE := 8;
    constant FORGET_CNT : POSITIVE := 3;
    constant CLK_PERIOD : TIME := 8 ns; -- 125 MHz

    -- Signals
    signal clk : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';

    -- BRAM signals (Port A: mac_write interface)
    signal bram_addr_a : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal bram_data_a : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
    signal bram_rden_a : STD_LOGIC;
    signal bram_wren_a : STD_LOGIC;
    signal bram_q_a : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);

    -- BRAM signals (Port B: testbench read interface)
    signal bram_addr_b : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal bram_data_b : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal bram_rden_b : STD_LOGIC;
    signal bram_wren_b : STD_LOGIC;
    signal bram_q_b : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);

    -- mac_write input signals (Port 0)
    signal mac_addr0 : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal mac_req0 : STD_LOGIC;
    signal mac_valid0 : STD_LOGIC;

    -- mac_write input signals (Port 1)
    signal mac_addr1 : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal mac_req1 : STD_LOGIC;
    signal mac_valid1 : STD_LOGIC;

    -- mac_write input signals (Port 2)
    signal mac_addr2 : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal mac_req2 : STD_LOGIC;
    signal mac_valid2 : STD_LOGIC;

    -- mac_write input signals (Port 3)
    signal mac_addr3 : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal mac_req3 : STD_LOGIC;
    signal mac_valid3 : STD_LOGIC;

    -- Simulation control
    signal sim_done : STD_LOGIC := '0';
    signal cycle_count : INTEGER := 0;

    -- Snapshots for counter analysis
    type counter_snapshot_t is array (0 to 15) of STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
    signal snapshot_initial : counter_snapshot_t;
    signal snapshot_halfway : counter_snapshot_t;
    signal snapshot_final : counter_snapshot_t;

begin

    -- Instantiate BRAM (generic RTL version)
    u_bram : entity work.bram
        generic map(
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clock => clk,
            -- Port A (connected to mac_write)
            address_a => bram_addr_a,
            data_a    => bram_data_a,
            rden_a    => bram_rden_a,
            wren_a    => bram_wren_a,
            q_a       => bram_q_a,
            -- Port B (connected to testbench for reads)
            address_b => bram_addr_b,
            data_b    => bram_data_b,
            rden_b    => bram_rden_b,
            wren_b    => bram_wren_b,
            q_b       => bram_q_b
        );

    -- Instantiate mac_write
    u_mac_write : entity work.mac_write
        generic map(
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH,
            FORGET_CNT => FORGET_CNT
        )
        port map(
            clk => clk,
            rst => rst,
            -- Port 0
            addr0  => mac_addr0,
            req0   => mac_req0,
            fcs_ok0 => mac_valid0,
            -- Port 1
            addr1  => mac_addr1,
            req1   => mac_req1,
            fcs_ok1 => mac_valid1,
            -- Port 2
            addr2  => mac_addr2,
            req2   => mac_req2,
            fcs_ok2 => mac_valid2,
            -- Port 3
            addr3  => mac_addr3,
            req3   => mac_req3,
            valid3 => mac_valid3,
            -- BRAM interface (Port A)
            addr  => bram_addr_a,
            wen   => bram_wren_a,
            wdata => bram_data_a,
            ren   => bram_rden_a,
            rdata => bram_q_a
        );

    -- Clock generation (125 MHz, 8ns period)
    clk_gen : process
    begin
        while sim_done = '0' loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Cycle counter
    cycle_counter : process (clk)
    begin
        if rising_edge(clk) then
            cycle_count <= cycle_count + 1;
        end if;
    end process;

    -- Main stimulus and verification process
    stimulus : process
        variable counter_val : INTEGER;
        variable init_cnt, half_cnt, final_cnt : INTEGER;
    begin
        -- Initialize all signals
        rst <= '0';
        mac_req0 <= '0';
        mac_req1 <= '0';
        mac_req2 <= '0';
        mac_req3 <= '0';
        mac_valid0 <= '0';
        mac_valid1 <= '0';
        mac_valid2 <= '0';
        mac_valid3 <= '0';
        bram_rden_b <= '0';
        bram_wren_b <= '0';

        wait for 10 ns;
        rst <= '1';
        wait for 10 ns;

        report "============================================" severity NOTE;
        report "TEST: mac_write with BRAM Testbench" severity NOTE;
        report "Config: ADDR_WIDTH=13, DATA_WIDTH=8, FORGET_CNT=3" severity NOTE;
        report "REQ/ADDR held for 10 clocks, VALID for 1 clock" severity NOTE;
        report "============================================" severity NOTE;

        -- ========================================
        -- PHASE 1a: Test req without valid (no write expected)
        -- ========================================
        report "PHASE 1a: Test REQ-only (no VALID) - Write should NOT occur" severity NOTE;

        wait until cycle_count = 10;
        mac_addr0 <= STD_LOGIC_VECTOR(to_unsigned(100, ADDR_WIDTH));
        mac_req0 <= '1';
        report "  Port 0: REQ and ADDR set to 0x0064, holding for 10 clocks (no VALID)" severity NOTE;
        wait for CLK_PERIOD * 10;
        wait until rising_edge(clk);
        mac_req0 <= '0';

        wait until cycle_count = 40;

        -- Try to read - should get 0x00 (no write occurred)
        bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(100, ADDR_WIDTH));
        bram_rden_b <= '1';
        wait until rising_edge(clk);
        bram_rden_b <= '0';
        wait until rising_edge(clk);

        if bram_q_b = "00000000" then
            report "    PASS: Address 0x0064 is still 0x00 (no write without valid)" severity NOTE;
        else
            report "    FAIL: Address 0x0064 contains 0x" & to_hstring(bram_q_b) & " (unexpected write occurred!)" severity WARNING;
        end if;

        -- ========================================
        -- PHASE 1b: Assert VALID to complete the write
        -- ========================================
        report "PHASE 1b: Assert VALID to commit the request" severity NOTE;

        wait until cycle_count = 50;
        mac_addr0 <= STD_LOGIC_VECTOR(to_unsigned(100, ADDR_WIDTH));
        mac_req0 <= '1';
        report "  Port 0: REQ and ADDR set to 0x0064, holding for 10 clocks" severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);

        -- Assert VALID while REQ/ADDR are still held
        mac_valid0 <= '1';
        wait until rising_edge(clk);
        mac_valid0 <= '0';

        -- Continue holding REQ/ADDR for remaining cycles
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_req0 <= '0';

        report "    REQ+ADDR held 10 clocks total, VALID asserted in middle for 1 clock" severity NOTE;

        wait until cycle_count = 100;

        -- Read and verify write occurred
        bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(100, ADDR_WIDTH));
        bram_rden_b <= '1';
        wait until rising_edge(clk);
        bram_rden_b <= '0';
        wait until rising_edge(clk);

        counter_val := to_integer(unsigned(bram_q_b(7 downto 2)));
        if bram_q_b = "11111100" then
            report "    PASS: Address 0x0064 now contains 0xFC (write occurred with both REQ and VALID)" severity NOTE;
        else
            report "    FAIL: Address 0x0064 contains 0x" & to_hstring(bram_q_b) & " (expected 0xFC)" severity WARNING;
        end if;

        -- ========================================
        -- PHASE 2: Write Stimulus with VALID (all ports)
        -- ========================================
        report "PHASE 2: Write Stimulus - REQ + VALID from all ports" severity NOTE;

        wait until cycle_count = 120;

        -- Port 0: hold req/addr for 10 clocks, assert valid in middle
        mac_addr0 <= STD_LOGIC_VECTOR(to_unsigned(0, ADDR_WIDTH));
        mac_req0 <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_valid0 <= '1';
        wait until rising_edge(clk);
        mac_valid0 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_req0 <= '0';

        wait until cycle_count = 150;

        -- Port 1: hold req/addr for 10 clocks, assert valid in middle
        mac_addr1 <= STD_LOGIC_VECTOR(to_unsigned(1, ADDR_WIDTH));
        mac_req1 <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_valid1 <= '1';
        wait until rising_edge(clk);
        mac_valid1 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_req1 <= '0';

        wait until cycle_count = 180;

        -- Port 2: hold req/addr for 10 clocks, assert valid in middle
        mac_addr2 <= STD_LOGIC_VECTOR(to_unsigned(2, ADDR_WIDTH));
        mac_req2 <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_valid2 <= '1';
        wait until rising_edge(clk);
        mac_valid2 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_req2 <= '0';

        wait until cycle_count = 210;

        -- Port 3: hold req/addr for 10 clocks, assert valid in middle
        mac_addr3 <= STD_LOGIC_VECTOR(to_unsigned(3, ADDR_WIDTH));
        mac_req3 <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_valid3 <= '1';
        wait until rising_edge(clk);
        mac_valid3 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        mac_req3 <= '0';

        report "  All 4 ports: REQ/ADDR held 10 clocks, VALID asserted for 1 clock in middle" severity NOTE;

        -- ========================================
        -- PHASE 3: Verification (cycles 240-320)
        -- ========================================
        report "PHASE 3: Verification - Reading back written data via Port B" severity NOTE;

        wait until cycle_count = 240;

        -- Read address 0
        bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(0, ADDR_WIDTH));
        bram_rden_b <= '1';
        wait until rising_edge(clk);
        bram_rden_b <= '0';
        wait until rising_edge(clk);
        counter_val := to_integer(unsigned(bram_q_b(7 downto 2)));
        report "  Addr 0x0000: Data=0x" & to_hstring(bram_q_b) & " Counter=" & INTEGER'image(counter_val) & " PortID=" & to_string(bram_q_b(1 downto 0)) severity NOTE;
        if bram_q_b = "11111100" then
            report "    Success: Port 0 data correct" severity NOTE;
        else
            report "    Error: Port 0 data MISMATCH (expected 0xFC)" severity WARNING;
        end if;

        -- Read address 1
        bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(1, ADDR_WIDTH));
        bram_rden_b <= '1';
        wait until rising_edge(clk);
        bram_rden_b <= '0';
        wait until rising_edge(clk);
        counter_val := to_integer(unsigned(bram_q_b(7 downto 2)));
        report "  Addr 0x0001: Data=0x" & to_hstring(bram_q_b) & " Counter=" & INTEGER'image(counter_val) & " PortID=" & to_string(bram_q_b(1 downto 0)) severity NOTE;
        if bram_q_b = "11111101" then
            report "    Success: Port 1 data correct" severity NOTE;
        else
            report "    Error: Port 1 data MISMATCH (expected 0xFD)" severity WARNING;
        end if;

        -- Read address 2
        bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(2, ADDR_WIDTH));
        bram_rden_b <= '1';
        wait until rising_edge(clk);
        bram_rden_b <= '0';
        wait until rising_edge(clk);
        counter_val := to_integer(unsigned(bram_q_b(7 downto 2)));
        report "  Addr 0x0002: Data=0x" & to_hstring(bram_q_b) & " Counter=" & INTEGER'image(counter_val) & " PortID=" & to_string(bram_q_b(1 downto 0)) severity NOTE;
        if bram_q_b = "11111110" then
            report "    Success: Port 2 data correct" severity NOTE;
        else
            report "    Error: Port 2 data MISMATCH (expected 0xFE)" severity WARNING;
        end if;

        -- Read address 3
        bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(3, ADDR_WIDTH));
        bram_rden_b <= '1';
        wait until rising_edge(clk);
        bram_rden_b <= '0';
        wait until rising_edge(clk);
        counter_val := to_integer(unsigned(bram_q_b(7 downto 2)));
        report "  Addr 0x0003: Data=0x" & to_hstring(bram_q_b) & " Counter=" & INTEGER'image(counter_val) & " PortID=" & to_string(bram_q_b(1 downto 0)) severity NOTE;
        if bram_q_b = "11111111" then
            report "    Success: Port 3 data correct" severity NOTE;
        else
            report "    Error: Port 3 data MISMATCH (expected 0xFF)" severity WARNING;
        end if;

        -- ========================================
        -- PHASE 4: Aging/Counter Test
        -- ========================================
        report "PHASE 4: Aging/Counter Test - Writing 16 fresh entries for aging analysis" severity NOTE;

        wait until cycle_count = 350;

        -- Write fresh entries to addresses 0x0010-0x1F with valid
        for i in 0 to 15 loop
            mac_addr0 <= STD_LOGIC_VECTOR(to_unsigned(16 + i, ADDR_WIDTH));
            mac_req0 <= '1';
            wait for CLK_PERIOD * 5;
            wait until rising_edge(clk);
            mac_valid0 <= '1';
            wait until rising_edge(clk);
            mac_valid0 <= '0';
            wait for CLK_PERIOD * 5;
            wait until rising_edge(clk);
            mac_req0 <= '0';
            wait for CLK_PERIOD * 5;
            wait until rising_edge(clk);
        end loop;

        report "  Written 16 entries to addresses 0x0010-0x001F with max counter (63)" severity NOTE;

        -- Wait a bit before taking first snapshot
        wait until cycle_count = 450;

        -- ========================================
        -- PHASE 4a: Initial Snapshot
        -- ========================================
        report "PHASE 4a: Initial Counter Snapshot at cycle " & INTEGER'image(cycle_count) severity NOTE;
        for i in 0 to 15 loop
            bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(16 + i, ADDR_WIDTH));
            bram_rden_b <= '1';
            wait until rising_edge(clk);
            bram_rden_b <= '0';
            wait until rising_edge(clk);
            snapshot_initial(i) <= bram_q_b;
            counter_val := to_integer(unsigned(bram_q_b(7 downto 2)));
            if i = 0 then
                report "  Snapshot at cycle " & INTEGER'image(cycle_count) & ":" severity NOTE;
            end if;
            report "    [0x" & to_hstring(to_unsigned(16 + i, ADDR_WIDTH)) & "] Counter=" & INTEGER'image(counter_val) severity NOTE;
        end loop;

        -- ========================================
        -- PHASE 4b: Wait for decrement cycles and take halfway snapshot
        -- ========================================
        wait until cycle_count = 750;

        report "PHASE 4b: Halfway Counter Snapshot at cycle " & INTEGER'image(cycle_count) severity NOTE;
        report "  (Expected: multiple decrements have occurred)" severity NOTE;
        for i in 0 to 15 loop
            bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(16 + i, ADDR_WIDTH));
            bram_rden_b <= '1';
            wait until rising_edge(clk);
            bram_rden_b <= '0';
            wait until rising_edge(clk);
            snapshot_halfway(i) <= bram_q_b;
            counter_val := to_integer(unsigned(bram_q_b(7 downto 2)));
            if i = 0 then
                report "  Snapshot at cycle " & INTEGER'image(cycle_count) & ":" severity NOTE;
            end if;
            report "    [0x" & to_hstring(to_unsigned(16 + i, ADDR_WIDTH)) & "] Counter=" & INTEGER'image(counter_val) severity NOTE;
        end loop;

        -- ========================================
        -- PHASE 4c: Wait longer for more aging and take final snapshot
        -- ========================================
        wait until cycle_count = 1250;

        report "PHASE 4c: Final Counter Snapshot at cycle " & INTEGER'image(cycle_count) severity NOTE;
        report "  (Expected: entries aged significantly)" severity NOTE;
        for i in 0 to 15 loop
            bram_addr_b <= STD_LOGIC_VECTOR(to_unsigned(16 + i, ADDR_WIDTH));
            bram_rden_b <= '1';
            wait until rising_edge(clk);
            bram_rden_b <= '0';
            wait until rising_edge(clk);
            snapshot_final(i) <= bram_q_b;
            counter_val := to_integer(unsigned(bram_q_b(7 downto 2)));
            if i = 0 then
                report "  Snapshot at cycle " & INTEGER'image(cycle_count) & ":" severity NOTE;
            end if;
            report "    [0x" & to_hstring(to_unsigned(16 + i, ADDR_WIDTH)) & "] Counter=" & INTEGER'image(counter_val) severity NOTE;
        end loop;

        -- ========================================
        -- PHASE 5: Counter Aging Analysis Report
        -- ========================================
        report "============================================" severity NOTE;
        report "COUNTER AGING ANALYSIS" severity NOTE;
        report "============================================" severity NOTE;

        for i in 0 to 15 loop
            init_cnt := to_integer(unsigned(snapshot_initial(i)(7 downto 2)));
            half_cnt := to_integer(unsigned(snapshot_halfway(i)(7 downto 2)));
            final_cnt := to_integer(unsigned(snapshot_final(i)(7 downto 2)));

            report "Address 0x" & to_hstring(to_unsigned(16 + i, ADDR_WIDTH)) & ":" severity NOTE;
            report "  At cycle  450: Counter=" & INTEGER'image(init_cnt) severity NOTE;
            report "  At cycle  750: Counter=" & INTEGER'image(half_cnt) & "  (delta=" & INTEGER'image(init_cnt - half_cnt) & " decrements)" severity NOTE;
            report "  At cycle 1250: Counter=" & INTEGER'image(final_cnt) & "  (delta=" & INTEGER'image(half_cnt - final_cnt) & " decrements)" severity NOTE;
        end loop;

        report "============================================" severity NOTE;
        report "TEST COMPLETE" severity NOTE;
        report "============================================" severity NOTE;

        sim_done <= '1';
        wait;
    end process;

end rtl;
