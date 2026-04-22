library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram is
    generic (
        ADDR_WIDTH : positive := 10;
        DATA_WIDTH : positive := 8
    );
    port (
        address_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        address_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        clock0    : in  std_logic;
        data_a    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        rden_b    : in  std_logic;
        wren_a    : in  std_logic;
        q_b       : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity bram;

architecture rtl of bram is
    constant DEPTH : natural := 2 ** ADDR_WIDTH;

    type ram_t is array (0 to DEPTH - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram   : ram_t := (others => (others => '0'));
    signal q_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
begin

    process (clock0)
    begin
        if rising_edge(clock0) then
            if wren_a = '1' then
                ram(to_integer(unsigned(address_a))) <= data_a;
            end if;

            if rden_b = '1' then
                q_reg <= ram(to_integer(unsigned(address_b)));
            end if;
        end if;
    end process;

    q_b <= q_reg;

end architecture rtl;