-- =============================================================================
-- Module: voq_fifo
-- Purpose:
--   Store-and-forward FIFO for VOQ use. Stores complete frames (EOF flagged)
--   and asserts frame_rdy when at least one full frame is present.
--
-- Memory:
--   DEPTH x 9 bits (8-bit data + 1-bit EOF)
--
-- Extensions:
--   flush    : logical clear of all pointers and counters
--   rd_valid : indicates rd_data/rd_eof are valid for the current cycle
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity voq_fifo is
    generic (
        DEPTH : INTEGER := 4096 -- FIFO depth in bytes
    );
    port (
        clk   : in STD_LOGIC; -- System clock
        reset : in STD_LOGIC; -- Synchronous reset (active low)
        flush : in STD_LOGIC; -- Logical clear (active high)

        -- Write side
        wr_en    : in STD_LOGIC;                    -- Write enable
        wr_data  : in STD_LOGIC_VECTOR(7 downto 0); -- Data byte
        wr_eof   : in STD_LOGIC;                    -- '1' for last byte of frame
        wr_abort : in STD_LOGIC;                    -- '1' discards current frame (e.g., CRC error)

        -- Read side
        rd_en    : in STD_LOGIC;                     -- Read enable
        rd_data  : out STD_LOGIC_VECTOR(7 downto 0); -- Data byte
        rd_eof   : out STD_LOGIC;                    -- '1' for EOF byte (valid only when rd_valid='1')
        rd_valid : out STD_LOGIC;                    -- '1' when rd_data/rd_eof are valid

        -- Status
        frame_rdy : out STD_LOGIC; -- '1' when at least one full frame is stored
        full      : out STD_LOGIC; -- '1' when FIFO is full
        empty     : out STD_LOGIC  -- '1' when FIFO is empty
    );
end entity voq_fifo;

architecture rtl of voq_fifo is

    -- Return the minimum counter width for a given depth
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

    -- -------------------------------------------------------------------------
    -- FIFO RAM: 9 bits per entry (8 data + 1 EOF)
    type ram_t is array (0 to DEPTH - 1) of STD_LOGIC_VECTOR(8 downto 0);
    signal ram : ram_t;

    -- -------------------------------------------------------------------------
    -- Pointers and counters
    signal wr_ptr        : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0'); -- Write address
    signal rd_ptr        : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0'); -- Read address
    signal count         : unsigned(ADDR_WIDTH downto 0)     := (others => '0'); -- Bytes in FIFO
    signal frames_stored : unsigned(ADDR_WIDTH downto 0)     := (others => '0'); -- Complete frames stored

    -- Track current frame length to allow rollback on abort
    signal frame_active    : STD_LOGIC                    := '0';
    signal frame_byte_cnt  : unsigned(count'range)        := (others => '0');

    -- Read pipeline register
    signal rd_reg       : STD_LOGIC_VECTOR(8 downto 0) := (others => '0'); -- Bit 8: EOF, bits 7-0: data
    signal rd_valid_reg : STD_LOGIC                    := '0';             -- '1' when rd_reg holds valid data

    -- Internal flags
    signal full_int  : STD_LOGIC;
    signal empty_int : STD_LOGIC;
    signal can_write : STD_LOGIC; -- Write allowed
    signal can_read  : STD_LOGIC; -- Read allowed

begin

    -- -------------------------------------------------------------------------
    -- Status flags
    -- -------------------------------------------------------------------------
    -- FIFO status flags
    full_int <= '1' when count = to_unsigned(DEPTH, count'length) else
        '0';
    empty_int <= '1' when count = to_unsigned(0, count'length) else
        '0';

    can_write <= '1' when (wr_en = '1' and full_int = '0' and wr_abort = '0') else
        '0';
    can_read <= '1' when (rd_en = '1' and empty_int = '0') else
        '0';

    ---------------------------------------------------------------------------
    -- Write port: store data and EOF flag at wr_ptr
    ---------------------------------------------------------------------------
    write_proc : process(all)
    begin
        if rising_edge(clk) then
            if can_write = '1' then
                -- Bit 8 = EOF, bits 7-0 = data
                ram(to_integer(wr_ptr)) <= wr_eof & wr_data;
            end if;
        end if;
    end process write_proc;

    ---------------------------------------------------------------------------
    -- Read port: load rd_reg when reading and track validity
    ---------------------------------------------------------------------------
    read_proc : process(all)
    begin
        if reset = '0' or flush = '1' then
            rd_reg <= (others => '0');

        elsif rising_edge(clk) then
            if can_read = '1' then
                -- EOF flag + data byte
                rd_reg <= ram(to_integer(rd_ptr));
            end if;
        end if;
    end process read_proc;

    -- Decode read register
    rd_data <= rd_reg(7 downto 0); -- Lower 8 bits = data
    rd_eof   <= rd_reg(8) and rd_valid_reg; -- EOF only valid with rd_valid_reg
    rd_valid <= rd_valid_reg when rd_valid_reg = '1' else
        '0';

    ---------------------------------------------------------------------------
    -- Pointers, occupancy, and frame tracking
    ---------------------------------------------------------------------------
    ptr_proc : process(all)
        variable count_next : unsigned(count'range);
    begin

        if reset = '0' or flush = '1' then
            -- Reset all pointers and counters
            wr_ptr        <= (others => '0');
            rd_ptr        <= (others => '0');
            count         <= (others => '0');
            frames_stored <= (others => '0');
            rd_valid_reg  <= '0';
            frame_active  <= '0';
            frame_byte_cnt <= (others => '0');
        end if;

        if rising_edge(clk) then
            -- rd_valid_reg follows can_read; cleared immediately after EOF
            rd_valid_reg <= can_read and not (rd_reg(8) and rd_valid_reg);

            -- Update pointers and occupancy
            -- Reads are only counted when EOF has not been consumed
            count_next := count;

            if can_read = '1' and rd_eof = '0' then
                rd_ptr <= rd_ptr + 1;
                count_next := count_next - 1;
            end if;

            if wr_abort = '1' and frame_active = '1' then
                wr_ptr <= wr_ptr - resize(frame_byte_cnt, wr_ptr'length);
                count_next := count_next - frame_byte_cnt;
                frame_byte_cnt <= (others => '0');
                frame_active <= '0';
            else
                if can_write = '1' then
                    wr_ptr <= wr_ptr + 1;
                    count_next := count_next + 1;

                    if frame_active = '0' then
                        frame_active <= '1';
                        frame_byte_cnt <= to_unsigned(1, frame_byte_cnt'length);
                    else
                        frame_byte_cnt <= frame_byte_cnt + 1;
                    end if;

                    if wr_eof = '1' then
                        frame_active <= '0';
                        frame_byte_cnt <= (others => '0');
                    end if;
                end if;
            end if;

            count <= count_next;

            -- Frame counter: increment on write EOF, decrement on read EOF
            if (can_write = '1' and wr_eof = '1') and
                (rd_valid_reg = '1' and rd_reg(8) = '1') then
                -- One frame in and one frame out in same cycle
                null;
            elsif (can_write = '1' and wr_eof = '1') then
                -- New frame completed
                frames_stored <= frames_stored + 1;
            elsif (rd_valid_reg = '1' and rd_reg(8) = '1') then
                -- Frame consumed
                frames_stored <= frames_stored - 1;
            end if;

        end if;
    end process ptr_proc;

    -- -------------------------------------------------------------------------
    -- Outputs
    -- -------------------------------------------------------------------------
    frame_rdy <= '1' when frames_stored > to_unsigned(0, frames_stored'length) else
        '0';
    full  <= full_int;
    empty <= empty_int;

end architecture rtl;
