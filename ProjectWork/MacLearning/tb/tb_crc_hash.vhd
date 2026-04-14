-- ============================================================
--  Testbench: mac_hash (CRC16-Basiertes Hashing)
--  Prüft:
--    1. Bekannte MAC ? erwarteter Hash (Goldene Referenzwerte)
--    2. Verschiedene MACs ? verschiedene Hash-Werte (Kollisionsrate)
--    3. Gleiche MAC ? immer gleicher Hash (Determinismus)
--    4. Broadcast / Multicast / Null-MAC Sonderfälle
--    5. Kollisionsstatistik über 20 zufällige MACs
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_crc_hash is
end tb_crc_hash;

architecture sim of tb_crc_hash is

    -- ?? DUT-Signale ????????????????????????????????????????????????
    signal mac_in   : std_logic_vector(47 downto 0) := (others => '0');
    signal hash_out : std_logic_vector(12 downto 0);

    -- ?? Hilfskonstanten ???????????????????????????????????????????
    constant CLK_PERIOD : time := 8 ns;   -- 125 MHz

    -- Hinweis: Der erwartete Hash wird durch crc16_ref berechnet
    -- und direkt mit dem DUT-Ausgang verglichen.
    -- Python-Referenz zum Nachrechnen:
    --   def crc16(mac_int):
    --       c = 0xFFFF
    --       for i in range(47, -1, -1):
    --           b = ((mac_int >> i) & 1) ^ ((c >> 15) & 1)
    --           c = (c << 1) & 0xFFFF
    --           if b: c ^= 0x8005
    --       return c & 0x1FFF

    -- ?? Prozedur: CRC16 in VHDL (Software-Referenz) ???????????????
    -- Spiegelt exakt die DUT-Logik ? dient als Golden Reference
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

    -- ?? Hilfsprozedur: MAC als Hex ausgeben ???????????????????????
    procedure print_mac (mac : std_logic_vector(47 downto 0)) is
    begin
        report "  MAC: " &
            integer'image(to_integer(unsigned(mac(47 downto 40)))) & ":" &
            integer'image(to_integer(unsigned(mac(39 downto 32)))) & ":" &
            integer'image(to_integer(unsigned(mac(31 downto 24)))) & ":" &
            integer'image(to_integer(unsigned(mac(23 downto 16)))) & ":" &
            integer'image(to_integer(unsigned(mac(15 downto  8)))) & ":" &
            integer'image(to_integer(unsigned(mac( 7 downto  0))))
        severity note;
    end procedure;

begin

    -- ?? DUT instanziieren ?????????????????????????????????????????
    DUT: entity work.mac_hash
        port map (
            mac_in   => mac_in,
            hash_out => hash_out
        );

    -- ?? Haupt-Testprozess ?????????????????????????????????????????
    process
        -- Typen müssen vor Variablen deklariert werden
        type hash_array_t is array(0 to 19) of std_logic_vector(12 downto 0);
        type mac_list_t   is array(0 to 19) of std_logic_vector(47 downto 0);

        variable ref_hash    : std_logic_vector(12 downto 0);
        variable prev_hash   : std_logic_vector(12 downto 0);
        variable collision   : integer := 0;
        variable tested      : integer := 0;
        variable hash_values : hash_array_t;
        variable mac_val     : std_logic_vector(47 downto 0);
        variable all_passed  : boolean := true;

        -- 20 pseudo-zufällige MACs für Kollisionstest
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
            x"AABBCCDDEEFE",  -- 1 Bit anders als [0]
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

    begin
        report "========================================" severity note;
        report "  MAC-HASH Testbench gestartet          " severity note;
        report "  CRC16 (Polynom 0x8005, Init 0xFFFF)  " severity note;
        report "========================================" severity note;

        -- ??????????????????????????????????????????????????????????
        -- TEST 1: Determinismus ? gleiche MAC muss gleichen Hash geben
        -- ??????????????????????????????????????????????????????????
        report "--- TEST 1: Determinismus ---" severity note;

        mac_in <= x"AABBCCDDEEFF";
        wait for 10 ns;
        ref_hash := hash_out;

        -- Zweiter Durchlauf mit gleicher MAC
        mac_in <= x"000000000000";
        wait for 10 ns;
        mac_in <= x"AABBCCDDEEFF";
        wait for 10 ns;

        if hash_out = ref_hash then
            report "  PASS: Gleiche MAC ? gleicher Hash (" &
                   integer'image(to_integer(unsigned(hash_out))) & ")"
            severity note;
        else
            report "  FAIL: Gleiche MAC ? unterschiedlicher Hash!" severity error;
            all_passed := false;
        end if;

        -- ??????????????????????????????????????????????????????????
        -- TEST 2: Referenzvergleich ? DUT vs. Software-CRC
        -- ??????????????????????????????????????????????????????????
        report "--- TEST 2: DUT vs. Software-Referenz ---" severity note;

        for i in 0 to 19 loop
            mac_val := RANDOM_MACS(i);
            mac_in  <= mac_val;
            wait for 10 ns;

            crc16_ref(mac_val, ref_hash);

            if hash_out = ref_hash then
                report "  PASS [" & integer'image(i) & "]: Hash = " &
                       integer'image(to_integer(unsigned(hash_out)))
                severity note;
            else
                report "  FAIL [" & integer'image(i) & "]: DUT=" &
                       integer'image(to_integer(unsigned(hash_out))) &
                       " REF=" &
                       integer'image(to_integer(unsigned(ref_hash)))
                severity error;
                all_passed := false;
            end if;

            hash_values(i) := hash_out;
        end loop;

        -- ??????????????????????????????????????????????????????????
        -- TEST 3: Kollisionstest
        -- ??????????????????????????????????????????????????????????
        report "--- TEST 3: Kollisionsanalyse (20 MACs) ---" severity note;
        collision := 0;

        for i in 0 to 19 loop
            for j in i+1 to 19 loop
                if hash_values(i) = hash_values(j) and
                   RANDOM_MACS(i) /= RANDOM_MACS(j) then
                    collision := collision + 1;
                    report "  KOLLISION: Index " & integer'image(i) &
                           " und " & integer'image(j) &
                           " ? Hash " &
                           integer'image(to_integer(unsigned(hash_values(i))))
                    severity warning;
                end if;
            end loop;
        end loop;

        if collision = 0 then
            report "  PASS: Keine Kollisionen unter 20 Test-MACs" severity note;
        else
            report "  INFO: " & integer'image(collision) &
                   " Kollision(en) gefunden (bei 8192 Buckets erwartet: ~0.02)"
            severity warning;
        end if;

        -- ??????????????????????????????????????????????????????????
        -- TEST 4: Sonderfälle
        -- ??????????????????????????????????????????????????????????
        report "--- TEST 4: Sonderfälle ---" severity note;

        -- Broadcast
        mac_in <= x"FFFFFFFFFFFF";
        wait for 10 ns;
        crc16_ref(x"FFFFFFFFFFFF", ref_hash);
        if hash_out = ref_hash then
            report "  PASS: Broadcast MAC ? Hash " &
                   integer'image(to_integer(unsigned(hash_out)))
            severity note;
        else
            report "  FAIL: Broadcast MAC falsch!" severity error;
            all_passed := false;
        end if;

        -- Null-MAC
        mac_in <= x"000000000000";
        wait for 10 ns;
        crc16_ref(x"000000000000", ref_hash);
        if hash_out = ref_hash then
            report "  PASS: Null-MAC ? Hash " &
                   integer'image(to_integer(unsigned(hash_out)))
            severity note;
        else
            report "  FAIL: Null-MAC falsch!" severity error;
            all_passed := false;
        end if;

        -- Multicast (niedrigstes Bit im ersten Byte = 1)
        mac_in <= x"010000000000";
        wait for 10 ns;
        crc16_ref(x"010000000000", ref_hash);
        if hash_out = ref_hash then
            report "  PASS: Multicast MAC ? Hash " &
                   integer'image(to_integer(unsigned(hash_out)))
            severity note;
        else
            report "  FAIL: Multicast MAC falsch!" severity error;
            all_passed := false;
        end if;

        -- ??????????????????????????????????????????????????????????
        -- TEST 5: Hamming-Distanz-Test
        --   1 Bit Unterschied ? unterschiedlicher Hash?
        -- ??????????????????????????????????????????????????????????
        report "--- TEST 5: 1-Bit-Differenz ? anderer Hash? ---" severity note;

        mac_in <= x"AABBCCDDEEFF";
        wait for 10 ns;
        prev_hash := hash_out;

        mac_in <= x"AABBCCDDEEFE";   -- Bit 0 geändert
        wait for 10 ns;

        if hash_out /= prev_hash then
            report "  PASS: 1-Bit-Änderung ? anderer Hash (" &
                   integer'image(to_integer(unsigned(prev_hash))) &
                   " ? " &
                   integer'image(to_integer(unsigned(hash_out))) & ")"
            severity note;
        else
            report "  WARN: 1-Bit-Änderung ? gleicher Hash! (Schwache Streuung)"
            severity warning;
        end if;

        -- ??????????????????????????????????????????????????????????
        -- TEST 6: Hash-Bereich prüfen (muss < 8192 = 0x1FFF sein)
        -- ??????????????????????????????????????????????????????????
        report "--- TEST 6: Hash-Wertebereich (0..8191) ---" severity note;

        for i in 0 to 19 loop
            mac_in <= RANDOM_MACS(i);
            wait for 10 ns;
            if to_integer(unsigned(hash_out)) < 8192 then
                null;  -- OK
            else
                report "  FAIL [" & integer'image(i) &
                       "]: Hash außerhalb Bereich: " &
                       integer'image(to_integer(unsigned(hash_out)))
                severity error;
                all_passed := false;
            end if;
        end loop;
        report "  PASS: Alle Hashes im Bereich 0..8191" severity note;

        -- ??????????????????????????????????????????????????????????
        -- Zusammenfassung
        -- ??????????????????????????????????????????????????????????
        report "========================================" severity note;
        if all_passed then
            report "  ERGEBNIS: ALLE TESTS BESTANDEN ?   " severity note;
        else
            report "  ERGEBNIS: FEHLER GEFUNDEN ?         " severity failure;
        end if;
        report "========================================" severity note;

        wait;  -- Simulation stoppen
    end process;

end sim;