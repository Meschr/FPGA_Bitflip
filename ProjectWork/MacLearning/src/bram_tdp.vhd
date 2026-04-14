library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- True Dual-Port BRAM: Port A = Lesen, Port B = Schreiben
entity bram_tdp is
    generic (
        DATA_WIDTH : integer := 64;
        ADDR_WIDTH : integer := 15   -- 2^15 = 32768 Slots gesamt
    );
    port (
        -- Port A: Lesen
        clk_a   : in  std_logic;
        en_a    : in  std_logic;
        addr_a  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        dout_a  : out std_logic_vector(DATA_WIDTH-1 downto 0);

        -- Port B: Schreiben
        clk_b   : in  std_logic;
        en_b    : in  std_logic;
        we_b    : in  std_logic;
        addr_b  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        din_b   : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end bram_tdp;

architecture rtl of bram_tdp is
    type ram_t is array(0 to 2**ADDR_WIDTH-1) 
                  of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_t := (others => (others => '0'));
begin
    -- Port A: synchrones Lesen
    process(clk_a)
    begin
        if rising_edge(clk_a) then
            if en_a = '1' then
                dout_a <= ram(to_integer(unsigned(addr_a)));
            end if;
        end if;
    end process;

    -- Port B: synchrones Schreiben
    process(clk_b)
    begin
        if rising_edge(clk_b) then
            if en_b = '1' and we_b = '1' then
                ram(to_integer(unsigned(addr_b))) <= din_b;
            end if;
        end if;
    end process;
end rtl;