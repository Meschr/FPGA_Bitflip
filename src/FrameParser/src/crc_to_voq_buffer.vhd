library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity crc_to_voq_buffer is
    generic (
        DEPTH : INTEGER := 256
    );
    port (
        clk   : in STD_LOGIC;
        reset : in STD_LOGIC;
        flush : in STD_LOGIC;

        wr_en          : in STD_LOGIC;
        wr_data        : in STD_LOGIC_VECTOR(7 downto 0);
        wr_eof         : in STD_LOGIC;
        crc_valid      : in STD_LOGIC;
        dest_port      : in STD_LOGIC_VECTOR(3 downto 0);
        dest_port_flag : in STD_LOGIC;

        rd_data         : out STD_LOGIC_VECTOR(7 downto 0);
        rd_eof          : out STD_LOGIC;
        rd_en_dest_port : out STD_LOGIC_VECTOR(3 downto 0);
        crc_valid_out   : out STD_LOGIC

        
    );
end entity crc_to_voq_buffer;

architecture rtl of crc_to_voq_buffer is

    -- Helper function: calculates minimum bit-width for a counter
    -- e.g. log2_ceil(4096) = 12 because 2^12 = 4096
    function log2_ceil(n : INTEGER) return INTEGER is
        variable result      : INTEGER := 0;
        variable val         : INTEGER := n - 1;
    begin
        while val > 0 loop
            val    := val / 2;
            result := result + 1;
        end loop;
        return result;
    end function;

    constant ADDR_WIDTH : INTEGER := log2_ceil(DEPTH);

    -- FIFO memory: each entry is 9 bits (8 data + 1 EOF)
    type ram_t is array (0 to DEPTH - 1) of STD_LOGIC_VECTOR(8 downto 0);
    signal ram : ram_t;

    -- Pointers and counters
    signal wr_ptr : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0'); -- write address
    signal rd_ptr : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0'); -- read address
    signal count  : unsigned(ADDR_WIDTH downto 0)     := (others => '0'); -- number of bytes in FIFO

    signal rd_reg       : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');
    signal rd_valid_reg : STD_LOGIC                    := '0';
    signal eof          : STD_LOGIC;

    -- Internal flags
    signal full_int      : STD_LOGIC;
    signal empty_int     : STD_LOGIC;
    signal can_write     : STD_LOGIC;                           -- write allowed (wr_en AND not full)
    signal can_read      : STD_LOGIC;                           -- read allowed (rd_active AND not empty)
    signal rd_active     : STD_LOGIC                    := '0'; -- frame read active until EOF seen
    signal dest_port_reg : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

begin
    -- Compute FIFO status flags
    full_int <= '1' when count = to_unsigned(DEPTH, count'length) else
        '0';
    empty_int <= '1' when count = to_unsigned(0, count'length) else
        '0';

    can_write <= '1' when (wr_en = '1' and full_int = '0') else
        '0';

    can_read <= '1' when (rd_active = '1' and empty_int = '0') else
        '0';
    rd_en_dest_port <= dest_port_reg when rd_valid_reg = '1' else
        (others => '0');

    crc_valid_out <= '1' when (rd_valid_reg = '1' and eof = '1' and crc_valid = '1') else
        '0'; -- TODO: feature not fully finished

    write_proc : process (all)
    begin
        if rising_edge(clk) then
            if can_write = '1' then
                
                ram(to_integer(wr_ptr)) <= wr_eof & wr_data;
            end if;
        end if;
    end process write_proc;

    read_proc : process (all)
    begin
        if rising_edge(clk) then
            if can_read = '1' then
                -- Load byte from RAM: EOF flag + data byte
                rd_reg <= ram(to_integer(rd_ptr));
            end if;
        end if;
    end process read_proc;

    rd_data <= rd_reg(7 downto 0);
    rd_eof <= rd_reg(8) and rd_valid_reg;
    eof    <= rd_reg(8) and rd_valid_reg;

    ptr_proc : process (all)
        variable count_next : unsigned(count'range);
    begin

        if reset = '0' or flush = '1' then
            -- Reset: all pointers to 0, FIFO is empty
            wr_ptr        <= (others => '0');
            rd_ptr        <= (others => '0');
            count         <= (others => '0');
            rd_valid_reg  <= '0';
            rd_active     <= '0';
            dest_port_reg <= (others => '0');

        elsif rising_edge(clk) then
            -- rd_valid_reg follows can_read: becomes '1' when a byte was just read
            rd_valid_reg <= can_read;

            if dest_port_flag = '1' then
                rd_active     <= '1';
                dest_port_reg <= dest_port;
            elsif eof = '1' then
                rd_active     <= '0';
                dest_port_reg <= (others => '0');
            end if;

            -- Update pointer and occupancy counter
            -- Count writes always; decrement for reads only when not EOF
            if can_write = '1' then
                wr_ptr <= wr_ptr + 1;
            end if;

            if can_read = '1' and eof = '0' then
                rd_ptr <= rd_ptr + 1;
            end if;

            count_next := count;
            if can_write = '1' then
                count_next := count_next + 1;
            end if;
            if can_read = '1' and eof = '0' then
                count_next := count_next - 1;
            end if;
            count <= count_next;

        end if;
    end process ptr_proc;

end architecture rtl;
