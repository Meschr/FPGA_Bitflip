library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mac_hash is
    port (

        -- System
        clk      : in  std_logic;
        rst      : in  std_logic;
    
        -- Eingaben
        mac_in   : in  std_logic_vector(47 downto 0);
        en       : in  std_logic;

        -- Ausgaben
        hash_out : inout std_logic_vector(12 downto 0);
        ready    : out std_logic
    );
end mac_hash;

architecture rtl of mac_hash is
    type state_t is (IDLE, RUN);

    signal state         : state_t;
    signal crc_reg       : std_logic_vector(15 downto 0);
    signal mac_reg       : std_logic_vector(47 downto 0);
    signal bit_counter   : integer range 0 to 47;
begin

    process(clk, rst)
        variable crc_next : std_logic_vector(15 downto 0);
        variable feedback : std_logic;
    begin
        if rst = '0' then
            crc_reg     <= x"FFFF";
            mac_reg     <= (others => '0');
            bit_counter <= 47;
            hash_out    <= (others => '0');
            ready       <= '0';
        elsif rising_edge(clk) then
            
            case( state ) is
                when IDLE =>
                    -- Standardverhalten im Leerlauf
                    state       <= IDLE;
                    mac_reg     <= mac_reg;
                    crc_reg     <= x"FFFF";
                    bit_counter <= 47;
                    -- Ausgaben
                    hash_out    <= crc_reg(12 downto 0);
                    ready       <= '1';

                    if en = '1' then
                        state       <= RUN;
                        -- Neue MAC-Adresse laden und Berechnung starten
                        mac_reg     <= mac_in;
                        
                        ready       <= '0';

                    end if;

                when RUN =>
                    -- Standardverhalten im Laufen
                    state       <= RUN;
                    mac_reg     <= mac_reg;
                    -- Ausgaben
                    hash_out    <= hash_out;
                    ready       <= '0';


                    -- Verarbeite ein Bit pro Takt
                    feedback := mac_reg(bit_counter) xor crc_reg(15);
                    crc_next := crc_reg(14 downto 0) & '0';
                    if feedback = '1' then
                        crc_next := crc_next xor x"8005";
                    end if;
                    crc_reg <= crc_next;
                    
                    if bit_counter = 0 then
                        -- Berechnung fertig
                        state       <= IDLE;
                        bit_counter <= 47;
                    else
                        bit_counter <= bit_counter - 1;
                    end if;  
            end case ;
        end if;

    end process;

end rtl;