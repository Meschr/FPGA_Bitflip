library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.mac_table_pkg.ALL;

entity mac_table_8k is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Lookup-Interface (1 Takt Latenz nach BRAM-Lesen = 3 Takte gesamt)
        lookup_mac  : in  std_logic_vector(MAC_WIDTH-1 downto 0);
        lookup_req  : in  std_logic;
        lookup_hit  : out std_logic;
        lookup_port : out std_logic_vector(PORT_WIDTH-1 downto 0);
        lookup_done : out std_logic;

        -- Learn-Interface
        learn_mac   : in  std_logic_vector(MAC_WIDTH-1 downto 0);
        learn_port  : in  std_logic_vector(PORT_WIDTH-1 downto 0);
        learn_req   : in  std_logic;
        learn_done  : out std_logic;

        -- Aging-Tick (z.B. alle 1 Sekunde von externem Timer)
        age_tick    : in  std_logic
    );
end mac_table_8k;

architecture rtl of mac_table_8k is

    -- BRAM-Adressbreite: 13 Bit Bucket + 2 Bit Slot = 15 Bit
    constant BRAM_ADDR_W : integer := 15;

    -- BRAM-Signale
    signal bram_en_a   : std_logic;
    signal bram_addr_a : std_logic_vector(BRAM_ADDR_W-1 downto 0);
    signal bram_dout_a : std_logic_vector(63 downto 0);
    signal bram_en_b   : std_logic;
    signal bram_we_b   : std_logic;
    signal bram_addr_b : std_logic_vector(BRAM_ADDR_W-1 downto 0);
    signal bram_din_b  : std_logic_vector(63 downto 0);

    -- Hash-Ausgänge
    signal lookup_hash : std_logic_vector(HASH_WIDTH-1 downto 0);
    signal learn_hash  : std_logic_vector(HASH_WIDTH-1 downto 0);

    -- State Machines
    type lookup_state_t is (IDLE, READ_SLOTS, READ_WAIT_1, READ_WAIT_2, COMPARE, DONE);
    type learn_state_t  is (IDLE, READ_SLOTS, READ_WAIT_1, READ_WAIT_2, FIND_SLOT, WRITE_HOLD, DONE);

    signal lu_state : lookup_state_t := IDLE;
    signal ln_state : learn_state_t  := IDLE;

    -- Lookup-Register
    signal lu_mac       : std_logic_vector(MAC_WIDTH-1 downto 0);
    signal lu_slot      : unsigned(1 downto 0);
    signal lu_bucket    : std_logic_vector(HASH_WIDTH-1 downto 0);
    signal lu_bram_data : std_logic_vector(63 downto 0);
    signal lu_hit_r     : std_logic;
    signal lu_port_r    : std_logic_vector(PORT_WIDTH-1 downto 0);

    -- Learn-Register
    signal ln_mac       : std_logic_vector(MAC_WIDTH-1 downto 0);
    signal ln_port      : std_logic_vector(PORT_WIDTH-1 downto 0);
    signal ln_bucket    : std_logic_vector(HASH_WIDTH-1 downto 0);
    signal ln_slot      : unsigned(1 downto 0);
    signal ln_bram_data : std_logic_vector(63 downto 0);
    signal ln_free_slot : integer range 0 to BUCKET_SIZE;
    signal ln_oldest    : unsigned(1 downto 0);

    -- Aging
    signal age_bucket   : unsigned(HASH_WIDTH-1 downto 0) := (others => '0');
    signal age_slot     : unsigned(1 downto 0)            := (others => '0');
    signal age_active   : std_logic := '0';

begin

    -- ??? Hash-Instanzen ????????????????????????????????????????????
    hash_lookup: entity work.mac_hash
        port map (mac_in => lookup_mac, hash_out => lookup_hash);

    hash_learn: entity work.mac_hash
        port map (mac_in => learn_mac, hash_out => learn_hash);

    -- ??? BRAM-Instanz ??????????????????????????????????????????????
    bram_inst: entity work.bram_tdp
        generic map (DATA_WIDTH => 64, ADDR_WIDTH => BRAM_ADDR_W)
        port map (
            clk_a  => clk, en_a => bram_en_a,
            addr_a => bram_addr_a, dout_a => bram_dout_a,
            clk_b  => clk, en_b => bram_en_b,
            we_b   => bram_we_b,
            addr_b => bram_addr_b, din_b => bram_din_b
        );

    -- ??? Lookup State Machine ??????????????????????????????????????
    process(clk)
        variable entry : mac_entry_t;
    begin
        if rising_edge(clk) then
            lookup_done <= '0';
            bram_en_a   <= '0';

            if rst = '1' then
                lu_state <= IDLE;
                lu_hit_r  <= '0';
                lu_port_r <= (others => '0');

            else
                case lu_state is

                    when IDLE =>
                        if lookup_req = '1' then
                            lu_mac    <= lookup_mac;
                            lu_bucket <= lookup_hash;
                            lu_slot   <= (others => '0');
                            lu_hit_r  <= '0';
                            lu_port_r <= (others => '0');
                            lu_state  <= READ_SLOTS;
                        end if;

                    when READ_SLOTS =>
                        -- BRAM lesen: Bucket-Adresse + Slot
                        bram_en_a   <= '1';
                        bram_addr_a <= lu_bucket & 
                                       std_logic_vector(lu_slot);
                        lu_state    <= READ_WAIT_1;

                    when READ_WAIT_1 =>
                        -- one full cycle for the synchronous BRAM read to occur
                        lu_state <= READ_WAIT_2;

                    when READ_WAIT_2 =>
                        -- capture the BRAM data after it has settled
                        lu_bram_data <= bram_dout_a;
                        lu_state     <= COMPARE;

                    when COMPARE =>
                        -- BRAM-Daten auswerten (mit registriertem Wert)
                        entry := word_to_entry(lu_bram_data);

                        if entry.valid = '1' and entry.mac = lu_mac then
                            -- Treffer gefunden
                            lu_hit_r  <= '1';
                            lu_port_r <= entry.port_id;
                            lu_state  <= DONE;

                        elsif lu_slot = BUCKET_SIZE-1 then
                            -- Alle Slots geprüft, kein Treffer
                            lu_hit_r <= '0';
                            lu_state <= DONE;

                        else
                            -- Nächsten Slot prüfen
                            lu_slot  <= lu_slot + 1;
                            lu_state <= READ_SLOTS;
                        end if;

                    when DONE =>
                        lookup_hit  <= lu_hit_r;
                        lookup_port <= lu_port_r;
                        lookup_done <= '1';
                        lu_state    <= IDLE;

                end case;
            end if;
        end if;
    end process;

    -- ??? Learn State Machine ???????????????????????????????????????
    process(clk)
        variable entry    : mac_entry_t;
        variable free_idx : integer range 0 to BUCKET_SIZE;
        variable old_age  : unsigned(AGE_WIDTH-1 downto 0);
        variable old_idx  : unsigned(1 downto 0);
    begin
        if rising_edge(clk) then
            learn_done  <= '0';
            bram_en_b   <= '0';
            bram_we_b   <= '0';

            if rst = '1' then
                ln_state <= IDLE;

            else
                case ln_state is

                    when IDLE =>
                        if learn_req = '1' then
                            ln_mac    <= learn_mac;
                            ln_port   <= learn_port;
                            ln_bucket <= learn_hash;
                            ln_slot   <= (others => '0');
                            free_idx  := BUCKET_SIZE;  -- "kein freier Slot"
                            old_age   := (others => '1');
                            old_idx   := (others => '0');
                            ln_state  <= READ_SLOTS;
                        end if;

                    when READ_SLOTS =>
                        bram_en_a   <= '1';
                        bram_addr_a <= ln_bucket & 
                                       std_logic_vector(ln_slot);
                        ln_state    <= READ_WAIT_1;

                    when READ_WAIT_1 =>
                        -- one full cycle for the synchronous BRAM read to occur
                        ln_state <= READ_WAIT_2;

                    when READ_WAIT_2 =>
                        -- capture the BRAM data after it has settled
                        ln_bram_data <= bram_dout_a;
                        ln_state     <= FIND_SLOT;

                    when FIND_SLOT =>
                        entry := word_to_entry(ln_bram_data);

                        -- MAC schon bekannt? ? Age resetten
                        if entry.valid = '1' and entry.mac = ln_mac then
                            ln_free_slot <= to_integer(ln_slot);
                            ln_oldest    <= ln_slot;
                            ln_state     <= WRITE_HOLD;

                        else
                            -- Freien Slot merken
                            if entry.valid = '0' and 
                               free_idx = BUCKET_SIZE then
                                free_idx := to_integer(ln_slot);
                            end if;

                            -- Ältesten Slot merken (für Verdrängung)
                            if entry.valid = '1' and 
                               unsigned(entry.age) < old_age then
                                old_age := unsigned(entry.age);
                                old_idx := ln_slot;
                            end if;

                            if ln_slot = BUCKET_SIZE-1 then
                                -- Entscheidung: freier Slot oder Verdrängung
                                if free_idx < BUCKET_SIZE then
                                    ln_free_slot <= free_idx;
                                else
                                    ln_free_slot <= to_integer(old_idx);
                                end if;
                                ln_state <= WRITE_HOLD;
                            else
                                ln_slot  <= ln_slot + 1;
                                ln_state <= READ_SLOTS;
                            end if;
                        end if;

                    when WRITE_HOLD =>
                        -- Neuen Eintrag schreiben
                        bram_en_b   <= '1';
                        bram_we_b   <= '1';
                        bram_addr_b <= ln_bucket & 
                                       std_logic_vector(
                                         to_unsigned(ln_free_slot, 2));
                        bram_din_b  <= entry_to_word((
                            mac     => ln_mac,
                            port_id => ln_port,
                            age     => (others => '1'),  -- maximales Age
                            valid   => '1'
                        ));
                        ln_state <= DONE;

                    when DONE =>
                        learn_done <= '1';
                        ln_state   <= IDLE;

                end case;
            end if;
        end if;
    end process;

    -- ??? Aging-Prozess (läuft im Hintergrund) ?????????????????????
    -- Bei jedem age_tick: alle Einträge durchgehen und Age dekrementieren
    -- Einträge mit Age=0 werden gelöscht (valid=0)
    process(clk)
        variable entry : mac_entry_t;
        variable word  : bram_word_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                age_bucket <= (others => '0');
                age_slot   <= (others => '0');
                age_active <= '0';
            else
                if age_tick = '1' then
                    age_active <= '1';
                    age_bucket <= (others => '0');
                    age_slot   <= (others => '0');
                end if;

                if age_active = '1' then
                    -- Eintrag lesen
                    bram_en_a   <= '1';
                    bram_addr_a <= std_logic_vector(age_bucket) & 
                                   std_logic_vector(age_slot);

                    -- Eintrag auswerten und ggf. dekrementieren
                    entry := word_to_entry(bram_dout_a);
                    if entry.valid = '1' then
                        if unsigned(entry.age) = 0 then
                            entry.valid := '0';
                        else
                            entry.age := std_logic_vector(
                                unsigned(entry.age) - 1);
                        end if;
                        bram_en_b   <= '1';
                        bram_we_b   <= '1';
                        bram_addr_b <= std_logic_vector(age_bucket) & 
                                       std_logic_vector(age_slot);
                        bram_din_b  <= entry_to_word(entry);
                    end if;

                    -- Nächster Slot/Bucket
                    if age_slot = BUCKET_SIZE-1 then
                        age_slot <= (others => '0');
                        if age_bucket = NUM_BUCKETS-1 then
                            age_active <= '0';
                        else
                            age_bucket <= age_bucket + 1;
                        end if;
                    else
                        age_slot <= age_slot + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end rtl;