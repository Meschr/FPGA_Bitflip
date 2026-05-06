library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity crc_to_voq_buffer is
    generic (
        DEPTH       : integer := 2000; -- Tiefe des FIFO-Speichers in Eintraegen (Bytes)
        NUM_OUTPUTS : integer := 4     -- Anzahl der Ziel-VOQs
    );
    port (
        clk           : in  std_logic;  -- Systemtakt
        reset         : in  std_logic;  -- Synchroner Reset (aktiv high)
        flush         : in  std_logic;  -- Logische Leerung (aktiv high): setzt alle Pointer und Zaehler auf Anfangswert

        -- -----------------------------------------------------------------
        -- Schreibseite: Eingangsframe mit EOF-Markierung
        -- -----------------------------------------------------------------
        wr_en         : in  std_logic;                    -- Schreibfreigabe
        wr_data       : in  std_logic_vector(7 downto 0); -- Datenbyte
        wr_eof        : in  std_logic;                    -- '1' wenn dies das letzte Byte des Frames ist
        wr_crc_ok     : in  std_logic;                    -- CRC-Status (nur gueltig bei wr_eof='1')
        wr_dest_port  : in  std_logic_vector(1 downto 0); -- Zielport (nur gueltig bei wr_eof='1')
        wr_dest_valid : in  std_logic;                    -- Zielport gueltig (nur gueltig bei wr_eof='1')

        -- -----------------------------------------------------------------
        -- Leseseite: Synchrones Lesen mit rd_valid-Flag
        -- -----------------------------------------------------------------
        rd_en         : in  std_logic;                    -- Lesefreigabe
        rd_data       : out std_logic_vector(7 downto 0); -- Ausgelesenes Datenbyte
        rd_eof        : out std_logic;                    -- '1' wenn dies das EOF-Byte ist (nur gueltig wenn rd_valid='1')
        rd_valid      : out std_logic;                    -- '1' wenn rd_data und rd_eof gueltige Daten enthalten
        rd_dest_port  : out std_logic_vector(1 downto 0); -- Zielport des aktuellen Frames

        -- -----------------------------------------------------------------
        -- Status-Ausgaenge
        -- -----------------------------------------------------------------
        frame_rdy     : out std_logic;  -- '1' wenn mindestens ein kompletter Frame im FIFO vorliegt
        full          : out std_logic;  -- '1' wenn FIFO voll ist (Schreiben nicht moeglich)
        empty         : out std_logic   -- '1' wenn FIFO leer ist
    );
end entity crc_to_voq_buffer;

architecture rtl of crc_to_voq_buffer is

    -- Hilfsfunktion: Berechnet die minimale Bit-Breite fuer einen Counter
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

    constant ADDR_WIDTH      : integer := log2_ceil(DEPTH);
    constant DEST_WIDTH      : integer := log2_ceil(NUM_OUTPUTS);
    constant DESC_DEPTH      : integer := 16;
    constant DESC_ADDR_WIDTH : integer := log2_ceil(DESC_DEPTH);

    -- FIFO-Speicher: Jeder Eintrag ist 9 Bit (8 Bit Daten + 1 Bit EOF)
    type ram_t is array (0 to DEPTH - 1) of std_logic_vector(8 downto 0);
    signal ram : ram_t;

    -- Descriptor-FIFO fuer Zielport pro committetem Frame
    type desc_ram_t is array (0 to DESC_DEPTH - 1) of std_logic_vector(DEST_WIDTH - 1 downto 0);
    signal desc_ram : desc_ram_t;

    -- Pointer und Zaehler
    signal wr_ptr              : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_ptr              : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal wr_commit_ptr       : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal wr_frame_start_ptr  : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal count_total         : unsigned(ADDR_WIDTH downto 0)     := (others => '0');
    signal wr_frame_len        : unsigned(ADDR_WIDTH downto 0)     := (others => '0');

    signal desc_wr_ptr         : unsigned(DESC_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal desc_rd_ptr         : unsigned(DESC_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal desc_count          : unsigned(DESC_ADDR_WIDTH downto 0)     := (others => '0');

    -- Zustandsflags
    signal in_frame            : std_logic := '0';
    signal drop_frame          : std_logic := '0';
    signal rd_in_frame         : std_logic := '0';

    -- Lese-Register (Pipeline-Stage)
    signal rd_reg              : std_logic_vector(8 downto 0) := (others => '0');
    signal rd_valid_reg        : std_logic := '0';
    signal rd_dest_port_reg    : std_logic_vector(DEST_WIDTH - 1 downto 0) := (others => '0');

    -- Interne Flags
    signal full_int            : std_logic;
    signal empty_int           : std_logic;
    signal desc_full_int       : std_logic;
    signal can_write           : std_logic;
    signal can_read            : std_logic;

begin

    -- Berechne Status-Flags
    full_int      <= '1' when count_total = to_unsigned(DEPTH, count_total'length) else '0';
    empty_int     <= '1' when rd_ptr = wr_commit_ptr else '0';
    desc_full_int <= '1' when desc_count = to_unsigned(DESC_DEPTH, desc_count'length) else '0';

    can_write <= '1' when (wr_en = '1' and full_int = '0' and drop_frame = '0') else '0';
    can_read  <= '1' when (rd_en = '1' and empty_int = '0') else '0';

    ---------------------------------------------------------------------------
    -- 1) Schreibport (kombinatorisch auf RAM)
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
    -- 2) Leseport (synchron mit rd_valid-Pipeline)
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
    rd_eof   <= rd_reg(8) and rd_valid_reg;
    rd_valid <= rd_valid_reg;
    rd_dest_port <= rd_dest_port_reg(1 downto 0);

    ---------------------------------------------------------------------------
    -- 3) Pointer, Zaehler und Descriptor-FIFO
    -- Commit/Rollback und Pointer-Verwaltung in einem Prozess
    ---------------------------------------------------------------------------
    ptr_proc : process(clk)
        variable v_wr_ptr             : unsigned(ADDR_WIDTH - 1 downto 0);
        variable v_rd_ptr             : unsigned(ADDR_WIDTH - 1 downto 0);
        variable v_wr_commit_ptr      : unsigned(ADDR_WIDTH - 1 downto 0);
        variable v_wr_frame_start_ptr : unsigned(ADDR_WIDTH - 1 downto 0);
        variable v_count_total        : unsigned(ADDR_WIDTH downto 0);
        variable v_wr_frame_len       : unsigned(ADDR_WIDTH downto 0);
        variable v_desc_wr_ptr        : unsigned(DESC_ADDR_WIDTH - 1 downto 0);
        variable v_desc_rd_ptr        : unsigned(DESC_ADDR_WIDTH - 1 downto 0);
        variable v_desc_count         : unsigned(DESC_ADDR_WIDTH downto 0);
        variable v_in_frame           : std_logic;
        variable v_drop_frame         : std_logic;
        variable v_rd_in_frame        : std_logic;
        variable v_rd_dest_port       : std_logic_vector(DEST_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' or flush = '1' then
                wr_ptr             <= (others => '0');
                rd_ptr             <= (others => '0');
                wr_commit_ptr      <= (others => '0');
                wr_frame_start_ptr <= (others => '0');
                count_total        <= (others => '0');
                wr_frame_len       <= (others => '0');
                desc_wr_ptr        <= (others => '0');
                desc_rd_ptr        <= (others => '0');
                desc_count         <= (others => '0');
                in_frame           <= '0';
                drop_frame         <= '0';
                rd_in_frame        <= '0';
                rd_valid_reg       <= '0';
                rd_dest_port_reg   <= (others => '0');
            else
                rd_valid_reg <= can_read;

                v_wr_ptr             := wr_ptr;
                v_rd_ptr             := rd_ptr;
                v_wr_commit_ptr      := wr_commit_ptr;
                v_wr_frame_start_ptr := wr_frame_start_ptr;
                v_count_total        := count_total;
                v_wr_frame_len       := wr_frame_len;
                v_desc_wr_ptr        := desc_wr_ptr;
                v_desc_rd_ptr        := desc_rd_ptr;
                v_desc_count         := desc_count;
                v_in_frame           := in_frame;
                v_drop_frame         := drop_frame;
                v_rd_in_frame        := rd_in_frame;
                v_rd_dest_port       := rd_dest_port_reg;

                -- Lesen: rd_ptr und count_total anpassen
                if can_read = '1' then
                    v_rd_ptr      := rd_ptr + 1;
                    v_count_total := v_count_total - 1;

                    if v_rd_in_frame = '0' then
                        v_rd_dest_port := desc_ram(to_integer(desc_rd_ptr));
                        v_rd_in_frame  := '1';
                    end if;

                    if rd_reg(8) = '1' then
                        v_rd_in_frame := '0';
                        v_desc_rd_ptr := desc_rd_ptr + 1;
                        v_desc_count  := v_desc_count - 1;
                    end if;
                end if;

                -- Schreiben: Frame-Start, Pointer und Rollback/Commit
                if wr_en = '1' then
                    if v_in_frame = '0' then
                        v_in_frame           := '1';
                        v_drop_frame         := '0';
                        v_wr_frame_len       := (others => '0');
                        v_wr_frame_start_ptr := wr_ptr;
                        if full_int = '1' then
                            v_drop_frame := '1';
                        end if;
                    end if;

                    if v_drop_frame = '0' and full_int = '0' then
                        v_wr_ptr       := wr_ptr + 1;
                        v_count_total  := v_count_total + 1;
                        v_wr_frame_len := v_wr_frame_len + 1;
                    elsif v_drop_frame = '0' and full_int = '1' then
                        v_drop_frame := '1';
                    end if;

                    if wr_eof = '1' then
                        if v_drop_frame = '0' and wr_crc_ok = '1' and wr_dest_valid = '1' and desc_full_int = '0' then
                            v_wr_commit_ptr := v_wr_ptr;
                            desc_ram(to_integer(desc_wr_ptr)) <= wr_dest_port(DEST_WIDTH - 1 downto 0);
                            v_desc_wr_ptr := desc_wr_ptr + 1;
                            v_desc_count  := v_desc_count + 1;
                        else
                            v_wr_ptr      := v_wr_frame_start_ptr;
                            v_count_total := v_count_total - v_wr_frame_len;
                        end if;

                        v_in_frame     := '0';
                        v_drop_frame   := '0';
                        v_wr_frame_len := (others => '0');
                    end if;
                end if;

                wr_ptr             <= v_wr_ptr;
                rd_ptr             <= v_rd_ptr;
                wr_commit_ptr      <= v_wr_commit_ptr;
                wr_frame_start_ptr <= v_wr_frame_start_ptr;
                count_total        <= v_count_total;
                wr_frame_len       <= v_wr_frame_len;
                desc_wr_ptr        <= v_desc_wr_ptr;
                desc_rd_ptr        <= v_desc_rd_ptr;
                desc_count         <= v_desc_count;
                in_frame           <= v_in_frame;
                drop_frame         <= v_drop_frame;
                rd_in_frame        <= v_rd_in_frame;
                rd_dest_port_reg   <= v_rd_dest_port;
            end if;
        end if;
    end process ptr_proc;

    frame_rdy <= '1' when desc_count > to_unsigned(0, desc_count'length) else '0';
    full      <= full_int;
    empty     <= empty_int;

end architecture rtl;