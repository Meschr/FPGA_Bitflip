library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Package declaration at the top of the file
package mem_ctrl_pkg is
    type addr_t is array (natural range <>) of std_logic_vector(7 downto 0);
end package mem_ctrl_pkg;

-- Now use it in the entity
use work.mem_ctrl_pkg.all;

entity bram is
    generic (
        NUMBER_OF_HEADS : positive := 4;
        ADDR_WIDTH      : positive := 10;
        DATA_WIDTH      : positive := 8
    );
    port (
        raddr : in  addr_t(0 to NUMBER_OF_HEADS-1);
        waddr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        clk   : in  std_logic;
        rst   : in  std_logic;
        datai : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        rden  : in  std_logic;
        wren  : in  std_logic;
        datao : out std_logic_vector(DATA_WIDTH-1 downto 0)
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