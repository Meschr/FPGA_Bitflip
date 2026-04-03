-------------------------------------------------------------------------------
-- voq_fifo.vhd
-- Generischer Store-and-Forward FIFO für die VOQ-Matrix
--
-- Speicher: DEPTH x 9 Bit (8 Bit Daten + 1 Bit EOF-Flag)
-- Dual-Port: Schreiben und Lesen gleichzeitig möglich
-- frame_rdy wird erst aktiv, wenn mindestens ein kompletter Frame gespeichert ist
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity voq_fifo is
    generic (
        DEPTH : integer := 4096
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        flush       : in  std_logic;  -- neue logische Leerung der FIFO

        -- Schreibseite
        wr_en       : in  std_logic;
        wr_data     : in  std_logic_vector(7 downto 0);
        wr_eof      : in  std_logic;

        -- Leseseite
        rd_en       : in  std_logic;
        rd_data     : out std_logic_vector(7 downto 0);
        rd_eof      : out std_logic; --
        rd_valid    : out std_logic;  -- neues Valid-Signal fuer gelesene Daten

        -- Status
        frame_rdy   : out std_logic;
        full        : out std_logic;
        empty       : out std_logic
    );
end entity voq_fifo;

architecture rtl of voq_fifo is

    function log2_ceil(n : integer) return integer is
        variable result : integer := 0;
        variable val    : integer := n - 1;
    begin
        while val > 0 loop
            val    := val / 2;
            result := result + 1;
        end loop;
        return result;
    end function;

    constant ADDR_WIDTH : integer := log2_ceil(DEPTH);

    type ram_t is array (0 to DEPTH - 1) of std_logic_vector(8 downto 0);
    signal ram : ram_t;

    signal wr_ptr         : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_ptr         : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal count          : unsigned(ADDR_WIDTH downto 0)     := (others => '0');
    signal frames_stored  : unsigned(ADDR_WIDTH downto 0)     := (others => '0');

    signal rd_reg         : std_logic_vector(8 downto 0)      := (others => '0');-- Register für aktuell gelesene Daten (inkl. EOF-Flag)
    signal rd_valid_reg   : std_logic                         := '0'; -- Register, das anzeigt, ob rd_reg gültige Daten enthält

    signal full_int       : std_logic;
    signal empty_int      : std_logic;
    signal can_write      : std_logic;
    signal can_read       : std_logic;

begin

    full_int  <= '1' when count = to_unsigned(DEPTH, count'length) else '0';
    empty_int <= '1' when count = to_unsigned(0, count'length) else '0';

    can_write <= '1' when (wr_en = '1' and full_int = '0') else '0';
    can_read  <= '1' when (rd_en = '1' and empty_int = '0') else '0';

    ---------------------------------------------------------------------------
    -- Schreibport
    ---------------------------------------------------------------------------
    write_proc : process(clk)
    begin
        if rising_edge(clk) then
            if can_write = '1' then
                ram(to_integer(wr_ptr)) <= wr_eof & wr_data;
            end if;
        end if;
    end process write_proc;

    ---------------------------------------------------------------------------
    -- Leseport (synchron)
    -- rd_data / rd_eof sind gueltig, wenn rd_valid = '1'
    ---------------------------------------------------------------------------
    read_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or flush = '1' then
                rd_reg <= (others => '0');
            elsif can_read = '1' then
                rd_reg <= ram(to_integer(rd_ptr));
            end if;
        end if;
    end process read_proc;

    rd_data  <= rd_reg(7 downto 0);
    
    rd_eof   <= rd_reg(8) and rd_valid_reg;  -- rd_eof ist nur gueltig, wenn rd_valid_reg = '1'
    rd_valid <= rd_valid_reg;

    ---------------------------------------------------------------------------
    -- Pointer, Count und Frame-Zaehler
    ---------------------------------------------------------------------------
    ptr_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or flush = '1' then
                wr_ptr        <= (others => '0');
                rd_ptr        <= (others => '0');
                count         <= (others => '0');
                frames_stored <= (others => '0');
                rd_valid_reg  <= '0';
            else
                -- zeigt in diesem Takt an, ob rd_reg frisch gueltige Daten enthaelt
                rd_valid_reg <= can_read;

                -- Pointer und Belegungszaehler
                if can_write = '1' and can_read = '0' then
                    wr_ptr <= wr_ptr + 1;
                    count  <= count + 1;
                elsif can_write = '0' and can_read = '1' then
                    rd_ptr <= rd_ptr + 1;
                    count  <= count - 1;
                elsif can_write = '1' and can_read = '1' then
                    wr_ptr <= wr_ptr + 1;
                    rd_ptr <= rd_ptr + 1;
                end if;

                -- Anzahl vollstaendiger Frames verwalten
                -- Schreiben eines EOF erhoeht die Zahl kompletter Frames
                -- Auslesen eines EOF verringert sie wieder
                if (can_write = '1' and wr_eof = '1') and
                   (rd_valid_reg = '1' and rd_reg(8) = '1') then
                    null;  -- in diesem Takt kommt netto ein kompletter Frame rein und einer raus
                elsif (can_write = '1' and wr_eof = '1') then
                    frames_stored <= frames_stored + 1;
                elsif (rd_valid_reg = '1' and rd_reg(8) = '1') then
                    frames_stored <= frames_stored - 1;
                end if;
            end if;
        end if;
    end process ptr_proc;

    frame_rdy <= '1' when frames_stored > to_unsigned(0, frames_stored'length) else '0';  -- frame_rdy ist '1', wenn mindestens ein kompletter Frame in der FIFO liegt
    full      <= full_int;
    empty     <= empty_int;

end architecture rtl;