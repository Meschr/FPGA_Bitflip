library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

entity mac_hash is
    generic (
        ADDR_WIDTH : POSITIVE := 13 -- address size, max 16
    );
    port (

        -- System
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;

        -- Eingaben
        mac_in : in STD_LOGIC_VECTOR(47 downto 0);
        en     : in STD_LOGIC;
        ack    : in STD_LOGIC;

        -- Ausgaben
        hash_out : inout STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
        ready    : out STD_LOGIC
    );
end mac_hash;

architecture rtl of mac_hash is
    type state_t is (IDLE, RUN, FIN);

    signal state : state_t;
    signal crc_reg : STD_LOGIC_VECTOR(15 downto 0);
    signal mac_reg : STD_LOGIC_VECTOR(47 downto 0);
    signal bit_counter : unsigned(5 downto 0);
begin

    process (all)
        variable crc_next : STD_LOGIC_VECTOR(15 downto 0);
        variable feedback : STD_LOGIC;
    begin
        if rst = '0' then
            crc_reg <= x"FFFF";
            mac_reg <= (others => '0');
            bit_counter <= to_unsigned(47, 6);
            hash_out <= (others => '0');
            ready <= '0';
        elsif rising_edge(clk) then

            case(state) is
                when IDLE =>
                -- Standardverhalten im Leerlauf
                state <= IDLE;
                mac_reg <= mac_reg;
                crc_reg <= x"FFFF";
                bit_counter <= to_unsigned(47, 6);
                -- Ausgaben
                hash_out <= hash_out;
                ready <= '0';

                if en = '1' then
                    state <= RUN;
                    -- Neue MAC-Adresse laden und Berechnung starten
                    mac_reg <= mac_in;
                end if;

                when RUN =>
                -- Standardverhalten im Laufen
                state <= RUN;
                mac_reg <= mac_reg;
                -- Ausgaben
                hash_out <= hash_out;
                ready <= '0';
                -- Verarbeite ein Bit pro Takt
                feedback := mac_reg(to_integer(bit_counter)) xor crc_reg(15);
                crc_next := crc_reg(14 downto 0) & '0';
                if feedback = '1' then
                    crc_next := crc_next xor x"8005";
                end if;
                crc_reg <= crc_next;

                if bit_counter = 0 then
                    -- Berechnung fertig
                    state <= FIN;
                else
                    bit_counter <= bit_counter - 1;
                end if;
                when FIN =>
                bit_counter <= to_unsigned(47, 6);
                if ack = '1' then
                    state <= IDLE;
                else
                    state <= FIN;
                end if;
                hash_out <= crc_reg(ADDR_WIDTH - 1 downto 0);
                ready <= '1';
            end case;
        end if;

    end process;

end rtl;
