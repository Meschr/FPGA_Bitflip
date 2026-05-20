library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram is
    generic (
        ADDR_WIDTH : POSITIVE := 13;
        DATA_WIDTH : POSITIVE := 8
    );
    port (
        address_a : in STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
        address_b : in STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
        clock     : in STD_LOGIC;
        data_a    : in STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
        data_b    : in STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
        rden_a    : in STD_LOGIC;
        rden_b    : in STD_LOGIC;
        wren_a    : in STD_LOGIC;
        wren_b    : in STD_LOGIC;
        q_a       : out STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
        q_b       : out STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0)
    );
end entity bram;

architecture rtl of bram is
    constant DEPTH : NATURAL := 2 ** ADDR_WIDTH;

    type ram_t is array (0 to DEPTH - 1) of STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
    signal ram : ram_t := (others => (others => '0'));
    signal q_a_reg : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal q_b_reg : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0) := (others => '0');
begin

    process (all)
    begin
        if rising_edge(clock) then
            if wren_a = '1' then
                ram(to_integer(unsigned(address_a))) <= data_a;
            end if;

            if wren_b = '1' then
                ram(to_integer(unsigned(address_b))) <= data_b;
            end if;

            if rden_a = '1' then
                q_a_reg <= ram(to_integer(unsigned(address_a)));
            end if;

            if rden_b = '1' then
                q_b_reg <= ram(to_integer(unsigned(address_b)));
            end if;
        end if;
    end process;

    q_a <= q_a_reg;
    q_b <= q_b_reg;

end architecture rtl;
