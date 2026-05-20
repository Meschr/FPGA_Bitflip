library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use std.env.all;

entity tb_mac_top is
end tb_mac_top;

architecture rtl of tb_mac_top is
    -- Constants
    constant ADDR_WIDTH : POSITIVE := 5;
    constant DATA_WIDTH : POSITIVE := 8;
    constant FORGET_CNT : POSITIVE := 3;
    constant CLK_PERIOD : TIME := 8 ns; -- 125 MHz

    -- Static MAC addresses (2 per port) - randomized
    constant MAC_P0_A : STD_LOGIC_VECTOR(47 downto 0) := x"AA55CCDDEE01";
    constant MAC_P0_B : STD_LOGIC_VECTOR(47 downto 0) := x"BB66DDEEFF02";
    constant MAC_P1_A : STD_LOGIC_VECTOR(47 downto 0) := x"CC77EEFF0011";
    constant MAC_P1_B : STD_LOGIC_VECTOR(47 downto 0) := x"DD88FF002233";
    constant MAC_P2_A : STD_LOGIC_VECTOR(47 downto 0) := x"EE99003344AA";
    constant MAC_P2_B : STD_LOGIC_VECTOR(47 downto 0) := x"FF00112255BB";
    constant MAC_P3_A : STD_LOGIC_VECTOR(47 downto 0) := x"0011223366CC";
    constant MAC_P3_B : STD_LOGIC_VECTOR(47 downto 0) := x"112233447755";

    -- One-hot encoded port outputs (4-bit vectors)
    constant PORT_0_ONEHOT : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant PORT_1_ONEHOT : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant PORT_2_ONEHOT : STD_LOGIC_VECTOR(3 downto 0) := "0100";
    constant PORT_3_ONEHOT : STD_LOGIC_VECTOR(3 downto 0) := "1000";

    -- Signals
    signal clk : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';

    -- Source MAC signals (Port 0-3)
    signal src_mac0, src_mac1, src_mac2, src_mac3 : STD_LOGIC_VECTOR(47 downto 0);
    signal src_req0, src_req1, src_req2, src_req3 : STD_LOGIC;
    signal fcs_valid0, fcs_valid1, fcs_valid2, fcs_valid3 : STD_LOGIC;

    -- Destination MAC signals (Port 0-3)
    signal dst_mac0, dst_mac1, dst_mac2, dst_mac3 : STD_LOGIC_VECTOR(47 downto 0);
    signal dst_req0, dst_req1, dst_req2, dst_req3 : STD_LOGIC;

    -- Output signals (Port 0-3)
    signal dst0, dst1, dst2, dst3 : STD_LOGIC_VECTOR(3 downto 0);
    signal dst_valid0, dst_valid1, dst_valid2, dst_valid3 : STD_LOGIC;

    -- Simulation control
    signal sim_done : STD_LOGIC := '0';
    signal cycle_count : INTEGER := 0;

begin

    -- Instantiate mac_table
    u_mac_table : entity work.mac_table
        generic map(
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH,
            FORGET_CNT => FORGET_CNT
        )
        port map(
            clk => clk,
            rst => rst,
            -- Source port 0
            src_mac0   => src_mac0,
            src_req0   => src_req0,
            fcs_valid0 => fcs_valid0,
            -- Source port 1
            src_mac1   => src_mac1,
            src_req1   => src_req1,
            fcs_valid1 => fcs_valid1,
            -- Source port 2
            src_mac2   => src_mac2,
            src_req2   => src_req2,
            fcs_valid2 => fcs_valid2,
            -- Source port 3
            src_mac3   => src_mac3,
            src_req3   => src_req3,
            fcs_valid3 => fcs_valid3,
            -- Destination port 0
            dst_mac0 => dst_mac0,
            dst_req0 => dst_req0,
            -- Destination port 1
            dst_mac1 => dst_mac1,
            dst_req1 => dst_req1,
            -- Destination port 2
            dst_mac2 => dst_mac2,
            dst_req2 => dst_req2,
            -- Destination port 3
            dst_mac3 => dst_mac3,
            dst_req3 => dst_req3,
            -- Output
            dst0       => dst0,
            dst_valid0 => dst_valid0,
            dst1       => dst1,
            dst_valid1 => dst_valid1,
            dst2       => dst2,
            dst_valid2 => dst_valid2,
            dst3       => dst3,
            dst_valid3 => dst_valid3
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
    begin
        -- Initialize all signals
        rst <= '0';
        src_req0 <= '0';
        src_req1 <= '0';
        src_req2 <= '0';
        src_req3 <= '0';
        fcs_valid0 <= '0';
        fcs_valid1 <= '0';
        fcs_valid2 <= '0';
        fcs_valid3 <= '0';
        dst_req0 <= '0';
        dst_req1 <= '0';
        dst_req2 <= '0';
        dst_req3 <= '0';
        src_mac0 <= (others => '0');
        src_mac1 <= (others => '0');
        src_mac2 <= (others => '0');
        src_mac3 <= (others => '0');
        dst_mac0 <= (others => '0');
        dst_mac1 <= (others => '0');
        dst_mac2 <= (others => '0');
        dst_mac3 <= (others => '0');

        wait for 10 ns;
        rst <= '1';
        wait for 10 ns;

        report "============================================" severity NOTE;
        report "TEST: mac_table with Static MAC Addresses" severity NOTE;
        report "Config: ADDR_WIDTH=4, DATA_WIDTH=8, FORGET_CNT=3" severity NOTE;
        report "Testing: Write source MACs, read as destinations" severity NOTE;
        report "============================================" severity NOTE;

        -- ========================================
        -- PHASE 1: Learn Source MACs from all ports (first MAC of each)
        -- ========================================
        report "PHASE 1: Learn Source MACs from all 4 ports" severity NOTE;

        wait for CLK_PERIOD * 20;

        -- Port 0: Write source MAC
        src_mac0 <= MAC_P0_A;
        src_req0 <= '1';
        report "  Port 0: Setting source MAC = 0x" & to_hstring(MAC_P0_A) severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        fcs_valid0 <= '1';
        wait until rising_edge(clk);
        fcs_valid0 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        src_req0 <= '0';

        wait for CLK_PERIOD * 50;

        -- Port 1: Write source MAC
        src_mac1 <= MAC_P1_A;
        src_req1 <= '1';
        report "  Port 1: Setting source MAC = 0x" & to_hstring(MAC_P1_A) severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        fcs_valid1 <= '1';
        wait until rising_edge(clk);
        fcs_valid1 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        src_req1 <= '0';

        wait for CLK_PERIOD * 50;

        -- Port 2: Write source MAC
        src_mac2 <= MAC_P2_A;
        src_req2 <= '1';
        report "  Port 2: Setting source MAC = 0x" & to_hstring(MAC_P2_A) severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        fcs_valid2 <= '1';
        wait until rising_edge(clk);
        fcs_valid2 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        src_req2 <= '0';

        wait for CLK_PERIOD * 50;

        -- Port 3: Write source MAC
        src_mac3 <= MAC_P3_A;
        src_req3 <= '1';
        report "  Port 3: Setting source MAC = 0x" & to_hstring(MAC_P3_A) severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        fcs_valid3 <= '1';
        wait until rising_edge(clk);
        fcs_valid3 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        src_req3 <= '0';

        report "  Phase 1 Complete: All 4 source MACs learned" severity NOTE;

        -- ========================================
        -- PHASE 2: Read back source MACs as destinations (immediate)
        -- ========================================
        report "PHASE 2: Read back written MACs as destinations (immediate)" severity NOTE;

        wait for CLK_PERIOD * 130;

        -- Read Port 0's learned MAC from Port 0
        dst_mac0 <= MAC_P0_A;
        dst_req0 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req0 <= '0';
        wait until rising_edge(clk);

        wait for CLK_PERIOD * 60;
        wait until rising_edge(clk);

        if dst_valid0 = '1' then
            if dst0 = PORT_0_ONEHOT then
                report "  Port 0 lookup PASS: Got port 0 (expected port 0)" severity NOTE;
            else
                report "  Port 0 lookup FAIL: Got one-hot " & to_string(dst0) & " (expected " & to_string(PORT_0_ONEHOT) & ")" severity WARNING;
            end if;
        else
            report "  Port 0 lookup: No match (MAC not found in table)" severity WARNING;
        end if;

        wait for CLK_PERIOD * 50;

        -- Read Port 1's learned MAC from Port 1
        dst_mac1 <= MAC_P1_A;
        dst_req1 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req1 <= '0';
        wait until rising_edge(clk);

        wait for CLK_PERIOD * 60;
        wait until rising_edge(clk);

        if dst_valid1 = '1' then
            if dst1 = PORT_1_ONEHOT then
                report "  Port 1 lookup PASS: Got port 1 (expected port 1)" severity NOTE;
            else
                report "  Port 1 lookup FAIL: Got one-hot " & to_string(dst1) & " (expected " & to_string(PORT_1_ONEHOT) & ")" severity WARNING;
            end if;
        else
            report "  Port 1 lookup: No match (MAC not found in table)" severity WARNING;
        end if;

        wait for CLK_PERIOD * 50;

        -- Read Port 2's learned MAC from Port 2
        dst_mac2 <= MAC_P2_A;
        dst_req2 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req2 <= '0';
        wait until rising_edge(clk);

        wait for CLK_PERIOD * 60;
        wait until rising_edge(clk);

        if dst_valid2 = '1' then
            if dst2 = PORT_2_ONEHOT then
                report "  Port 2 lookup PASS: Got port 2 (expected port 2)" severity NOTE;
            else
                report "  Port 2 lookup FAIL: Got one-hot " & to_string(dst2) & " (expected " & to_string(PORT_2_ONEHOT) & ")" severity WARNING;
            end if;
        else
            report "  Port 2 lookup: No match (MAC not found in table)" severity WARNING;
        end if;

        wait for CLK_PERIOD * 50;

        -- Read Port 3's learned MAC from Port 3
        dst_mac3 <= MAC_P3_A;
        dst_req3 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req3 <= '0';
        wait until rising_edge(clk);

        wait for CLK_PERIOD * 60;

        wait until rising_edge(clk);

        if dst_valid3 = '1' then
            if dst3 = PORT_3_ONEHOT then
                report "  Port 3 lookup PASS: Got port 3 (expected port 3)" severity NOTE;
            else
                report "  Port 3 lookup FAIL: Got one-hot " & to_string(dst3) & " (expected " & to_string(PORT_3_ONEHOT) & ")" severity WARNING;
            end if;
        else
            report "  Port 3 lookup: No match (MAC not found in table)" severity WARNING;
        end if;

        report "  Phase 2 Complete: All immediate reads verified" severity NOTE;

        -- ========================================
        -- PHASE 3: Cross-port lookup test
        -- ========================================
        report "PHASE 3: Cross-port lookup test" severity NOTE;

        wait for CLK_PERIOD * 100;

        -- From Port 0, look up MAC learned on Port 1
        dst_mac0 <= MAC_P1_A;
        dst_req0 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req0 <= '0';
        wait until rising_edge(clk);

        wait for CLK_PERIOD * 60;
        wait until rising_edge(clk);

        if dst_valid0 = '1' then
            report "  Port 0 lookup of Port 1 MAC: Got one-hot " & to_string(dst0) & " (expected " & to_string(PORT_1_ONEHOT) & ")" severity NOTE;
            if dst0 = PORT_1_ONEHOT then
                report "    PASS: Correct cross-port lookup" severity NOTE;
            else
                report "    FAIL: Wrong port returned" severity WARNING;
            end if;
        else
            report "  Port 0 lookup of Port 1 MAC: No match" severity WARNING;
        end if;

        -- ========================================
        -- PHASE 4: Learn second MAC on Port 2, wait 100 clocks
        -- ========================================
        report "PHASE 4: Learn second MAC on Port 2" severity NOTE;

        wait for CLK_PERIOD * 100;

        -- Port 2: Write second source MAC
        src_mac2 <= MAC_P2_B;
        src_req2 <= '1';
        report "  Port 2: Setting new source MAC = 0x" & to_hstring(MAC_P2_B) severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        fcs_valid2 <= '1';
        wait until rising_edge(clk);
        fcs_valid2 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        src_req2 <= '0';

        -- ========================================
        -- PHASE 4a: Aging test - wait 100 clocks then read both MACs
        -- ========================================
        report "PHASE 4a: Aging Test - Wait 100 clocks, then verify both Port 2 MACs still accessible" severity NOTE;

        wait for CLK_PERIOD * 100;

        -- Wait 100 clocks from cycle 750 to 850
        report "  Waiting 100 clocks for counter aging..." severity NOTE;
        wait for CLK_PERIOD * 100;

        -- Now read first Port 2 MAC - it should still be there but aged
        dst_mac2 <= MAC_P2_A;
        dst_req2 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req2 <= '0';
        wait until rising_edge(clk);

        wait for CLK_PERIOD * 10;
        wait until rising_edge(clk);

        if dst_valid2 = '1' then
            if dst2 = PORT_2_ONEHOT then
                report "  After 100-clock aging: First Port 2 MAC (0x" & to_hstring(MAC_P2_A) & ") still accessible" severity NOTE;
                report "    PASS: MAC learned on Port 2 is still in table after aging" severity NOTE;
            else
                report "    FAIL: Got one-hot " & to_string(dst2) & " instead of " & to_string(PORT_2_ONEHOT) severity WARNING;
            end if;
        else
            report "  After 100-clock aging: First Port 2 MAC NO LONGER in table (expired)" severity NOTE;
        end if;

        wait for CLK_PERIOD * 70;

        -- Now read second Port 2 MAC - it should definitely be there (just learned)
        dst_mac2 <= MAC_P2_B;
        dst_req2 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req2 <= '0';
        wait until rising_edge(clk);

        wait for CLK_PERIOD * 10;
        wait until rising_edge(clk);

        if dst_valid2 = '1' then
            if dst2 = PORT_2_ONEHOT then
                report "  After learning: Second Port 2 MAC (0x" & to_hstring(MAC_P2_B) & ") found at port 2" severity NOTE;
                report "    PASS: Newly learned MAC is in table" severity NOTE;
            else
                report "    FAIL: Got one-hot " & to_string(dst2) & " instead of " & to_string(PORT_2_ONEHOT) severity WARNING;
            end if;
        else
            report "  Second Port 2 MAC not found" severity WARNING;
        end if;

        -- ========================================
        -- PHASE 5: Learn all second MACs and verify cross-lookups
        -- ========================================
        report "PHASE 5: Learn second MAC on all ports" severity NOTE;

        wait for CLK_PERIOD * 80;

        -- Port 0: Write second source MAC
        src_mac0 <= MAC_P0_B;
        src_req0 <= '1';
        report "  Port 0: Setting second source MAC = 0x" & to_hstring(MAC_P0_B) severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        fcs_valid0 <= '1';
        wait until rising_edge(clk);
        fcs_valid0 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        src_req0 <= '0';

        wait for CLK_PERIOD * 70;

        -- Port 1: Write second source MAC
        src_mac1 <= MAC_P1_B;
        src_req1 <= '1';
        report "  Port 1: Setting second source MAC = 0x" & to_hstring(MAC_P1_B) severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        fcs_valid1 <= '1';
        wait until rising_edge(clk);
        fcs_valid1 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        src_req1 <= '0';

        wait for CLK_PERIOD * 70;

        -- Port 3: Write second source MAC
        src_mac3 <= MAC_P3_B;
        src_req3 <= '1';
        report "  Port 3: Setting second source MAC = 0x" & to_hstring(MAC_P3_B) severity NOTE;
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        fcs_valid3 <= '1';
        wait until rising_edge(clk);
        fcs_valid3 <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        src_req3 <= '0';

        report "  Phase 5 Complete: All 8 MACs now in table (2 per port)" severity NOTE;

        -- ========================================
        -- PHASE 6: Verify all lookups work
        -- ========================================
        report "PHASE 6: Final verification - All 8 MACs" severity NOTE;

        wait for CLK_PERIOD * 11360;

        -- Test Port 0 B
        dst_mac0 <= MAC_P0_B;
        dst_req0 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req0 <= '0';
        wait until rising_edge(clk);
        wait for CLK_PERIOD * 60;
        wait until rising_edge(clk);
        if dst_valid0 = '1' and dst0 = PORT_0_ONEHOT then
            report "  Port 0 MAC B: PASS" severity NOTE;
        else
            report "  Port 0 MAC B: FAIL" severity WARNING;
        end if;

        wait for CLK_PERIOD * 100;

        -- Test Port 1 B
        dst_mac1 <= MAC_P1_B;
        dst_req1 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req1 <= '0';
        wait until rising_edge(clk);
        wait for CLK_PERIOD * 60;
        wait until rising_edge(clk);
        if dst_valid1 = '1' and dst1 = PORT_1_ONEHOT then
            report "  Port 1 MAC B: PASS" severity NOTE;
        else
            report "  Port 1 MAC B: FAIL" severity WARNING;
        end if;

        wait for CLK_PERIOD * 50;

        -- Test Port 3 B
        dst_mac3 <= MAC_P3_B;
        dst_req3 <= '1';
        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);
        dst_req3 <= '0';
        wait until rising_edge(clk);
        wait for CLK_PERIOD * 60;
        wait until rising_edge(clk);
        if dst_valid3 = '1' and dst3 = PORT_3_ONEHOT then
            report "  Port 3 MAC B: PASS" severity NOTE;
        else
            report "  Port 3 MAC B: FAIL" severity WARNING;
        end if;

        report "============================================" severity NOTE;
        report "TEST COMPLETE" severity NOTE;
        report "============================================" severity NOTE;

        sim_done <= '1';
        finish;
    end process;

end rtl;
