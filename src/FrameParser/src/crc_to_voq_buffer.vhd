LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY crc_to_voq_buffer IS
    GENERIC (
        DEPTH : INTEGER := 64 -- Tiefe des FIFO-Speichers in Eintraegen (Bytes)
    );
    PORT (
        clk : IN STD_LOGIC; -- Systemtakt
        reset : IN STD_LOGIC; -- Synchroner Reset (aktiv high)
        flush : IN STD_LOGIC; -- Logische Leerung (aktiv high): setzt alle Pointer und Zaehler auf Anfangswert

        -- -----------------------------------------------------------------
        -- Schreibseite: Eingangsframe mit EOF-Markierung
        -- -----------------------------------------------------------------
        wr_en : IN STD_LOGIC; -- Schreibfreigabe
        wr_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Datenbyte
        wr_eof : IN STD_LOGIC;
        crc_valid : IN STD_LOGIC; -- '1' wenn dies das letzte Byte des Frames ist
        dest_port : IN STD_LOGIC_VECTOR(3 DOWNTO 0); -- Zielport des aktuellen Frames (nur gueltig bei wr_eof='1')                  
        dest_port_flag : IN STD_LOGIC; -- '1' wenn dest_port gültig ist (nur bei wr_eof='1')

        -- -----------------------------------------------------------------
        -- Leseseite: Synchrones Lesen mit rd_valid-Flag
        -- -----------------------------------------------------------------
        rd_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Ausgelesenes Datenbyte
        rd_eof : OUT STD_LOGIC; -- '1' wenn dies das EOF-Byte ist (nur gueltig wenn rd_valid='1')
        rd_en_dest_port : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- Zielport des aktuellen Frames
        crc_valid_out : OUT STD_LOGIC -- '1' wenn das gelesene Byte das letzte Byte eines Frames mit korrektem CRC ist
        -- rd_en : out std_logic;                    -- Lesefreigabe (optional, da Lesen automatisch bei rd_valid='1' erfolgt)

        -- -----------------------------------------------------------------
        -- Status-Ausgaenge
        -- -----------------------------------------------------------------
    );
END ENTITY crc_to_voq_buffer;

ARCHITECTURE rtl OF crc_to_voq_buffer IS

    -- Hilfsfunktion: Berechnet die minimale Bit-Breite fuer einen Counter
    -- z.B. log2_ceil(4096) = 12, da 2^12 = 4096
    FUNCTION log2_ceil(n : INTEGER) RETURN INTEGER IS
        VARIABLE result : INTEGER := 0;
        VARIABLE val : INTEGER := n - 1;
    BEGIN
        WHILE val > 0 LOOP
            val := val / 2;
            result := result + 1;
        END LOOP;
        RETURN result;
    END FUNCTION;

    CONSTANT ADDR_WIDTH : INTEGER := log2_ceil(DEPTH);

    -- FIFO-Speicher: Jeder Eintrag ist 9 Bit (8 Bit Daten + 1 Bit EOF)
    TYPE ram_t IS ARRAY (0 TO DEPTH - 1) OF STD_LOGIC_VECTOR(8 DOWNTO 0);
    SIGNAL ram : ram_t;

    -- Pointer und Zaehler
    SIGNAL wr_ptr : unsigned(ADDR_WIDTH - 1 DOWNTO 0) := (OTHERS => '0'); -- Schreib-Adresse
    SIGNAL rd_ptr : unsigned(ADDR_WIDTH - 1 DOWNTO 0) := (OTHERS => '0'); -- Lese-Adresse
    SIGNAL count : unsigned(ADDR_WIDTH DOWNTO 0) := (OTHERS => '0'); -- Anzahl Bytes im FIFO

    -- Lese-Register (Pipeline-Stage)
    SIGNAL rd_reg : STD_LOGIC_VECTOR(8 DOWNTO 0) := (OTHERS => '0'); -- Register fuer aktuell gelesene Daten (Bit 8: EOF, Bits 7-0: Daten)
    SIGNAL rd_valid_reg : STD_LOGIC := '0'; -- '1' wenn rd_reg frisch mit Daten gefuellt wurde
    SIGNAL eof : STD_LOGIC; -- '1' wenn das aktuell gelesene Byte das EOF-Byte ist

    -- Interne Flags
    SIGNAL full_int : STD_LOGIC;
    SIGNAL empty_int : STD_LOGIC;
    SIGNAL can_write : STD_LOGIC; -- Schreiben erlaubt (wr_en UND nicht voll)
    SIGNAL can_read : STD_LOGIC; -- Lesen erlaubt (rd_en UND nicht leer)
    SIGNAL rd_active : STD_LOGIC := '0'; -- Frame-Read aktiv bis EOF gelesen
    SIGNAL dest_port_reg : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

BEGIN
    -- Berechne FIFO-Status-Flags
    full_int <= '1' WHEN count = to_unsigned(DEPTH, count'length) ELSE
        '0';
    empty_int <= '1' WHEN count = to_unsigned(0, count'length) ELSE
        '0';

    can_write <= '1' WHEN (wr_en = '1' AND full_int = '0') ELSE
        '0';

    can_read <= '1' WHEN (rd_active = '1' AND empty_int = '0') ELSE
        '0';
    rd_en_dest_port <= dest_port_reg WHEN rd_valid_reg = '1' ELSE
        (OTHERS => '0');

    crc_valid_out <= '1' WHEN (rd_valid_reg = '1' AND eof = '1' AND crc_valid = '1') ELSE
        '0'; ---TBD NOCH nicht fertig



    write_proc : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF can_write = '1' THEN
                -- Speicherformat: Bit 8 = EOF, Bits 7-0 = Daten
                ram(to_integer(wr_ptr)) <= wr_eof & wr_data;
            END IF;
        END IF;
    END PROCESS write_proc;



    read_proc : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF can_read = '1' THEN
                -- Lade Byte aus RAM: EOF-Flag + Datenbyte
                rd_reg <= ram(to_integer(rd_ptr));
            END IF;
        END IF;
    END PROCESS read_proc;



    -- Dekodiere das Read-Register
    rd_data <= rd_reg(7 DOWNTO 0); -- Lower 8 Bits = Daten

    -- rd_eof ist nur gueltig, wenn rd_valid_reg='1'
    rd_eof <= rd_reg(8) AND rd_valid_reg; -- Bit 8 = EOF-Flag
    eof <= rd_reg(8) AND rd_valid_reg;

    ptr_proc : PROCESS (clk)
        VARIABLE count_next : unsigned(count'RANGE);
    BEGIN

        IF reset = '0' OR flush = '1' THEN
                -- Reset: Alle Pointer auf 0, FIFO ist leer
                wr_ptr <= (OTHERS => '0');
                rd_ptr <= (OTHERS => '0');
                count <= (OTHERS => '0');
                rd_valid_reg <= '0';
                rd_active <= '0';
                dest_port_reg <= (OTHERS => '0');

         ELSIF rising_edge(clk) THEN
                -- rd_valid_reg folgt can_read: wird '1' wenn gerade ein Byte gelesen wurde
                rd_valid_reg <= can_read;

                IF dest_port_flag = '1' THEN
                    rd_active <= '1';
                    dest_port_reg <= dest_port;
                ELSIF eof = '1' THEN
                    rd_active <= '0';
                    dest_port_reg <= (OTHERS => '0');
                END IF;

                -- Pointer- und Belegungszaehler aktualisieren
                -- Schreiben immer zaehlen, Lesen nur wenn nicht EOF
                IF can_write = '1' THEN
                    wr_ptr <= wr_ptr + 1;
                END IF;

                IF can_read = '1' AND eof = '0' THEN
                    rd_ptr <= rd_ptr + 1;
                END IF;

                count_next := count;
                IF can_write = '1' THEN
                    count_next := count_next + 1;
                END IF;
                IF can_read = '1' AND eof = '0' THEN
                    count_next := count_next - 1;
                END IF;
                count <= count_next;

            END IF;
    END PROCESS ptr_proc;

END ARCHITECTURE rtl;