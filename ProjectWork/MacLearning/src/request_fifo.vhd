library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity request_fifo is
    generic (
        DATA_WIDTH : positive := 1;
        DEPTH      : positive := 4
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        wr_en  : in  std_logic;
        wr_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        rd_en  : in  std_logic;
        rd_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
        empty  : out std_logic;
        full   : out std_logic
    );
end request_fifo;

architecture rtl of request_fifo is

    type mem_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    signal mem    : mem_t := (others => (others => '0'));
    signal wr_ptr : integer range 0 to DEPTH-1 := 0;
    signal rd_ptr : integer range 0 to DEPTH-1 := 0;
    signal count  : integer range 0 to DEPTH := 0;

    function next_idx(idx : integer) return integer is
    begin
        if idx = DEPTH - 1 then
            return 0;
        end if;

        return idx + 1;
    end function;

begin

    rd_data <= mem(rd_ptr);
    empty <= '1' when count = 0 else '0';
    full  <= '1' when count = DEPTH else '0';

    process(clk)
        variable next_count : integer range 0 to DEPTH;
        variable do_write   : boolean;
        variable do_read    : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wr_ptr <= 0;
                rd_ptr <= 0;
                count  <= 0;

            else
                do_write := wr_en = '1' and (count < DEPTH or rd_en = '1');
                do_read  := rd_en = '1' and count > 0;

                next_count := count;

                if do_write then
                    mem(wr_ptr) <= wr_data;
                    wr_ptr <= next_idx(wr_ptr);
                    next_count := next_count + 1;
                end if;

                if do_read then
                    rd_ptr <= next_idx(rd_ptr);
                    next_count := next_count - 1;
                end if;

                count <= next_count;
            end if;
        end if;
    end process;

end rtl;