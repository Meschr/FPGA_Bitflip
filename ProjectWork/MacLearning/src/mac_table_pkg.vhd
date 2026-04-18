library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package mac_table_pkg is

    constant MAC_WIDTH    : integer := 48;
    constant PORT_WIDTH   : integer := 2;
    constant HASH_WIDTH   : integer := 13;   -- 8192 Buckets
    constant NUM_BUCKETS  : integer := 8192;
    constant BUCKET_SIZE  : integer := 4;    -- Slots pro Bucket
    constant AGE_WIDTH    : integer := 8;    -- Aging Counter

    -- Ein einzelner Tabellen-Eintrag
    type mac_entry_t is record
        mac   : std_logic_vector(MAC_WIDTH-1 downto 0);
        port_id : std_logic_vector(PORT_WIDTH-1 downto 0);
        age   : std_logic_vector(AGE_WIDTH-1 downto 0);
        valid : std_logic;
    end record;

    -- Flaches BRAM-Wort (64 Bit) für einen Eintrag
    -- [63]      = valid
    -- [62:55]   = age
    -- [54:53]   = port
    -- [52:5]    = mac (48 bit)
    -- [4:0]     = reserviert
    subtype bram_word_t is std_logic_vector(63 downto 0);

    function entry_to_word(e : mac_entry_t) return bram_word_t;
    function word_to_entry(w : bram_word_t) return mac_entry_t;

end package;

package body mac_table_pkg is

    function entry_to_word(e : mac_entry_t) return bram_word_t is
        variable w : bram_word_t := (others => '0');
    begin
        w(63)          := e.valid;
        w(62 downto 55):= e.age;
        w(54 downto 53):= e.port_id;
        w(52 downto 5) := e.mac;
        return w;
    end function;

    function word_to_entry(w : bram_word_t) return mac_entry_t is
        variable e : mac_entry_t;
    begin
        e.valid := w(63);
        e.age   := w(62 downto 55);
        e.port_id  := w(54 downto 53);
        e.mac   := w(52 downto 5);
        return e;
    end function;

end package body;