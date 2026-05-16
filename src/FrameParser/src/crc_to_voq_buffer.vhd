library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity crc_to_voq_buffer is
    generic (
        DEPTH : INTEGER := 256 -- Tiefe des FIFO-Speichers in Eintraegen (Bytes)
    );
    port (
        clk   : in STD_LOGIC; -- Systemtakt
        reset : in STD_LOGIC; -- Synchroner Reset (aktiv high)
        flush : in STD_LOGIC; -- Logische Leerung (aktiv high): setzt alle Pointer und Zaehler auf Anfangswert

        -- -----------------------------------------------------------------
        -- Schreibseite: Eingangsframe mit EOF-Markierung
        -- -----------------------------------------------------------------
        wr_en          : in STD_LOGIC;                    -- Schreibfreigabe
        wr_data        : in STD_LOGIC_VECTOR(7 downto 0); -- Datenbyte
        wr_eof         : in STD_LOGIC;
        crc_valid      : in STD_LOGIC;                    -- '1' wenn dies das letzte Byte des Frames ist
        dest_port      : in STD_LOGIC_VECTOR(3 downto 0); -- Zielport des aktuellen Frames (nur gueltig bei wr_eof='1')                  
        dest_port_flag : in STD_LOGIC;                    -- '1' wenn dest_port gültig ist (nur bei wr_eof='1')

        -- -----------------------------------------------------------------
        -- Leseseite: Synchrones Lesen mit rd_valid-Flag
        -- -----------------------------------------------------------------
        rd_data         : out STD_LOGIC_VECTOR(7 downto 0); -- Ausgelesenes Datenbyte
        rd_eof          : out STD_LOGIC;                    -- '1' wenn dies das EOF-Byte ist (nur gueltig wenn rd_valid='1')
        rd_en_dest_port : out STD_LOGIC_VECTOR(3 downto 0); -- Zielport des aktuellen Frames
        crc_valid_out   : out STD_LOGIC                     -- '1' wenn das gelesene Byte das letzte Byte eines Frames mit korrektem CRC ist
        -- rd_en : out std_logic;                    -- Lesefreigabe (optional, da Lesen automatisch bei rd_valid='1' erfolgt)

        -- -----------------------------------------------------------------
        -- Status-Ausgaenge
        -- -----------------------------------------------------------------
    );
end entity crc_to_voq_buffer;

architecture rtl of crc_to_voq_buffer is

    -- Hilfsfunktion: Berechnet die minimale Bit-Breite fuer einen Counter
    -- z.B. log2_ceil(4096) = 12, da 2^12 = 4096
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

    -- FIFO-Speicher: Jeder Eintrag ist 9 Bit (8 Bit Daten + 1 Bit EOF)
    type ram_t is array (0 to DEPTH - 1) of STD_LOGIC_VECTOR(8 downto 0);
    signal ram : ram_t;

    -- Pointer und Zaehler
    signal wr_ptr : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0'); -- Schreib-Adresse
    signal rd_ptr : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0'); -- Lese-Adresse
    signal count  : unsigned(ADDR_WIDTH downto 0)     := (others => '0'); -- Anzahl Bytes im FIFO

    -- Lese-Register (Pipeline-Stage)
    signal rd_reg       : STD_LOGIC_VECTOR(8 downto 0) := (others => '0'); -- Register fuer aktuell gelesene Daten (Bit 8: EOF, Bits 7-0: Daten)
    signal rd_valid_reg : STD_LOGIC                    := '0';             -- '1' wenn rd_reg frisch mit Daten gefuellt wurde
    signal eof          : STD_LOGIC;                                       -- '1' wenn das aktuell gelesene Byte das EOF-Byte ist

    -- Interne Flags
    signal full_int      : STD_LOGIC;
    signal empty_int     : STD_LOGIC;
    signal can_write     : STD_LOGIC;                           -- Schreiben erlaubt (wr_en UND nicht voll)
    signal can_read      : STD_LOGIC;                           -- Lesen erlaubt (rd_en UND nicht leer)
    signal rd_active     : STD_LOGIC                    := '0'; -- Frame-Read aktiv bis EOF gelesen
    signal dest_port_reg : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

begin
    -- Berechne FIFO-Status-Flags
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
        '0'; ---TBD NOCH nicht fertig

    write_proc : process(all)
    begin
        if rising_edge(clk) then
            if can_write = '1' then
                -- Speicherformat: Bit 8 = EOF, Bits 7-0 = Daten
                ram(to_integer(wr_ptr)) <= wr_eof & wr_data;
            end if;
        end if;
    end process write_proc;

    read_proc : process(all)
    begin
        if rising_edge(clk) then
            if can_read = '1' then
                -- Lade Byte aus RAM: EOF-Flag + Datenbyte
                rd_reg <= ram(to_integer(rd_ptr));
            end if;
        end if;
    end process read_proc;

    -- Dekodiere das Read-Register
    rd_data <= rd_reg(7 downto 0); -- Lower 8 Bits = Daten

    -- rd_eof ist nur gueltig, wenn rd_valid_reg='1'
    rd_eof <= rd_reg(8) and rd_valid_reg; -- Bit 8 = EOF-Flag
    eof    <= rd_reg(8) and rd_valid_reg;

    ptr_proc : process(all)
        variable count_next : unsigned(count'range);
    begin

        if reset = '0' or flush = '1' then
            -- Reset: Alle Pointer auf 0, FIFO ist leer
            wr_ptr        <= (others => '0');
            rd_ptr        <= (others => '0');
            count         <= (others => '0');
            rd_valid_reg  <= '0';
            rd_active     <= '0';
            dest_port_reg <= (others => '0');

        elsif rising_edge(clk) then
            -- rd_valid_reg folgt can_read: wird '1' wenn gerade ein Byte gelesen wurde
            rd_valid_reg <= can_read;

            if dest_port_flag = '1' then
                rd_active     <= '1';
                dest_port_reg <= dest_port;
            elsif eof = '1' then
                rd_active     <= '0';
                dest_port_reg <= (others => '0');
            end if;

            -- Pointer- und Belegungszaehler aktualisieren
            -- Schreiben immer zaehlen, Lesen nur wenn nicht EOF
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
