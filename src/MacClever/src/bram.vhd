library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram is
    generic (
        ADDR_WIDTH : positive := 13;
        DATA_WIDTH : positive := 8
    );
    port (
        address_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        address_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        clock    : in  std_logic;
        data_a    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_b    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        rden_a    : in  std_logic;
        rden_b    : in  std_logic;
        wren_a    : in  std_logic;
        wren_b    : in  std_logic;
        q_a       : out std_logic_vector(DATA_WIDTH-1 downto 0);
        q_b       : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity bram;

architecture rtl of bram is
    constant DEPTH : natural := 2 ** ADDR_WIDTH;

    type ram_t is array (0 to DEPTH - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram   : ram_t := (others => (others => '0'));
    signal q_a_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal q_b_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
begin

    process (clock)
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