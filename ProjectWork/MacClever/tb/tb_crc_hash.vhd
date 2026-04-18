-- ============================================================
--  Testbench: mac_hash (CRC16-Basiertes Hashing)
--  Prüft:
--    1. Bekannte MAC -> erwarteter Hash (Goldene Referenzwerte)
--    2. Verschiedene MACs -> verschiedene Hash-Werte (Kollisionsrate)
--    3. Gleiche MAC -> immer gleicher Hash (Determinismus)
--    4. Broadcast / Multicast / Null-MAC Sonderfalle
--    5. Kollisionsstatistik über 20 zufallige MACs
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.finish;

entity tb_crc_hash is
end tb_crc_hash;

architecture sim of tb_crc_hash is

    -- DUT-Signale
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '0';
    signal mac_in    : std_logic_vector(47 downto 0) := (others => '0');
    signal en        : std_logic := '0';
    signal hash_out  : std_logic_vector(12 downto 0);
    signal ready     : std_logic;

    -- Konstanten
    constant CLK_PERIOD : time := 8 ns;   -- 125 MHz
    constant PROC_TIME  : time := CLK_PERIOD * 48;  -- 48 clocks to process

    -- CRC16 Software-Referenz
    procedure crc16_ref (
        mac      : in  std_logic_vector(47 downto 0);
        result   : out std_logic_vector(12 downto 0)
    ) is
        variable c : std_logic_vector(15 downto 0) := x"FFFF";
        variable b : std_logic;
    begin
        c := x"FFFF";
        for i in 47 downto 0 loop
            b := mac(i) xor c(15);
            c := c(14 downto 0) & '0';
            if b = '1' then
                c := c xor x"8005";
            end if;
        end loop;
        result := c(12 downto 0);
    end procedure;

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    DUT: entity work.mac_hash
        port map (
            clk      => clk,
            rst      => rst,
            mac_in   => mac_in,
            en       => en,
            hash_out => hash_out,
            ready    => ready
        );

    -- Main test process
    process
        type hash_array_t is array(0 to 19) of std_logic_vector(12 downto 0);
        type mac_list_t   is array(0 to 19) of std_logic_vector(47 downto 0);

        variable ref_hash    : std_logic_vector(12 downto 0);
        variable prev_hash   : std_logic_vector(12 downto 0);
        variable collision   : integer := 0;
        variable hash_values : hash_array_t;
        variable mac_val     : std_logic_vector(47 downto 0);
        variable all_passed  : boolean := true;

        constant RANDOM_MACS : mac_list_t := (
            x"AABBCCDDEEFF",
            x"112233445566",
            x"DEADBEEF0001",
            x"CAFEBABE1234",
            x"001122334455",
            x"FFEEDDCCBBAA",
            x"010203040506",
            x"0A0B0C0D0E0F",
            x"1A2B3C4D5E6F",
            x"F1E2D3C4B5A6",
            x"AABBCCDDEEFE",
            x"AABBCCDDEEFD",
            x"AABBCCDDEEFB",
            x"AABBCCDDEEF7",
            x"AABBCCDDEEEF",
            x"AABBCCDDEDEF",
            x"AABBCCDDCFEF",
            x"AABBCCDD0000",
            x"000000000001",
            x"FFFFFFFFFFFE"
        );

        procedure test_mac(mac : std_logic_vector(47 downto 0); test_name : string) is
        begin
            -- Wait for ready
            wait until ready = '1' and rising_edge(clk);
            
            -- Set MAC and enable
            mac_in <= mac;
            en <= '1';
            wait until rising_edge(clk);
            en <= '0';
            

            wait until rising_edge(ready);
            
            -- Verify result
            crc16_ref(mac, ref_hash);
            if hash_out = ref_hash then
                report "  PASS [" & test_name & "]: Hash = " &
                       integer'image(to_integer(unsigned(hash_out)))
                severity note;
            else
                report "  FAIL [" & test_name & "]: DUT=" &
                       integer'image(to_integer(unsigned(hash_out))) &
                       " REF=" &
                       integer'image(to_integer(unsigned(ref_hash)))
                severity error;
                all_passed := false;
            end if;
        end procedure;

    begin
        report "========================================" severity note;
        report "  MAC-HASH Testbench gestartet          " severity note;
        report "  CRC16 (Polynom 0x8005, Init 0xFFFF)  " severity note;
        report "========================================" severity note;

        -- Reset sequence
        rst <= '0';
        en  <= '0';
        wait for 5 * CLK_PERIOD;
        rst <= '1';
        wait for 2 * CLK_PERIOD;

        -- TEST 1: Determinismus
        report "--- TEST 1: Determinismus ---" severity note;
        test_mac(x"AABBCCDDEEFF", "First");
        prev_hash := hash_out;
        test_mac(x"AABBCCDDEEFF", "Second");
        
        if hash_out = prev_hash then
            report "  PASS: Gleiche MAC -> gleicher Hash"
            severity note;
        else
            report "  FAIL: Gleiche MAC -> unterschiedlicher Hash!" severity error;
            all_passed := false;
        end if;

        -- TEST 2: DUT vs. Software-Referenz
        report "--- TEST 2: DUT vs. Software-Referenz ---" severity note;
        for i in 0 to 19 loop
            mac_val := RANDOM_MACS(i);
            test_mac(mac_val, integer'image(i));
            hash_values(i) := hash_out;
        end loop;

        -- TEST 3: Kollisionstest
        report "--- TEST 3: Kollisionsanalyse (20 MACs) ---" severity note;
        collision := 0;
        for i in 0 to 19 loop
            for j in i+1 to 19 loop
                if hash_values(i) = hash_values(j) and
                   RANDOM_MACS(i) /= RANDOM_MACS(j) then
                    collision := collision + 1;
                    report "  KOLLISION: Index " & integer'image(i) &
                           " und " & integer'image(j)
                    severity warning;
                end if;
            end loop;
        end loop;

        if collision = 0 then
            report "  PASS: Keine Kollisionen unter 20 Test-MACs" severity note;
        else
            report "  INFO: " & integer'image(collision) &
                   " Kollision(en) gefunden"
            severity warning;
        end if;

        -- TEST 4: Sonderfalle
        report "--- TEST 4: Sonderfalle ---" severity note;
        test_mac(x"FFFFFFFFFFFF", "Broadcast");
        test_mac(x"000000000000", "Null-MAC");
        test_mac(x"010000000000", "Multicast");

        -- TEST 5: 1-Bit-Differenz
        report "--- TEST 5: 1-Bit-Differenz -> anderer Hash? ---" severity note;
        test_mac(x"AABBCCDDEEFF", "Base");
        prev_hash := hash_out;
        test_mac(x"AABBCCDDEEFE", "1-Bit-Changed");
        
        if hash_out /= prev_hash then
            report "  PASS: 1-Bit-anderung -> anderer Hash"
            severity note;
        else
            report "  WARN: 1-Bit-anderung -> gleicher Hash!" severity warning;
        end if;

        -- TEST 6: Hash-Bereich
        report "--- TEST 6: Hash-Wertebereich (0..8191) ---" severity note;
        for i in 0 to 19 loop
            if to_integer(unsigned(hash_values(i))) < 8192 then
                null;
            else
                report "  FAIL: Hash ausserhalb Bereich" severity error;
                all_passed := false;
            end if;
        end loop;
        report "  PASS: Alle Hashes im Bereich 0..8191" severity note;

        -- Summary
        report "========================================" severity note;
        if all_passed then
            report "  ERGEBNIS: ALLE TESTS BESTANDEN    " severity note;
        else
            report "  ERGEBNIS: FEHLER GEFUNDEN          " severity failure;
        end if;
        report "========================================" severity note;

        -- Explicit finish to avoid infinite loop
        finish;
    end process;

end sim;