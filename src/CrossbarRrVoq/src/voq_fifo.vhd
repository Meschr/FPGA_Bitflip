-- =============================================================================
-- Modul: voq_fifo
-- Beschreibung:
--   Generischer Store-and-Forward FIFO fuer die VOQ-Matrix eines Crossbar-Switch.
--   Speichert komplette Frames (erkannt durch EOF-Flag) und signalisiert,
--   wenn ein Frame fertig vorliegt (frame_rdy).
--
-- Speicher: DEPTH x 9 Bit (8 Bit Daten + 1 Bit EOF-Flag)
-- Dual-Port: Schreiben und Lesen gleichzeitig moeglich
-- frame_rdy: wird nur aktiv, wenn mindestens ein kompletter Frame gespeichert ist
--
-- Neue Signale (erweitert):
--   flush:    Logische Leerung des FIFOs (setzt alles auf Anfangswert)
--   rd_valid: '1' wenn rd_data und rd_eof gueltige Daten enthalten
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY voq_fifo IS
    GENERIC (
        DEPTH : INTEGER := 4096 -- Tiefe des FIFO-Speichers in Eintraegen (Bytes)
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
        wr_eof : IN STD_LOGIC; -- '1' wenn dies das letzte Byte des Frames ist

        -- -----------------------------------------------------------------
        -- Leseseite: Synchrones Lesen mit rd_valid-Flag
        -- -----------------------------------------------------------------
        rd_en : IN STD_LOGIC; -- Lesefreigabe
        rd_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Ausgelesenes Datenbyte
        rd_eof : OUT STD_LOGIC; -- '1' wenn dies das EOF-Byte ist (nur gueltig wenn rd_valid='1')
        rd_valid : OUT STD_LOGIC; -- '1' wenn rd_data und rd_eof gueltige Daten enthalten

        -- -----------------------------------------------------------------
        -- Status-Ausgaenge
        -- -----------------------------------------------------------------
        frame_rdy : OUT STD_LOGIC; -- '1' wenn mindestens ein kompletter Frame im FIFO vorliegt
        full : OUT STD_LOGIC; -- '1' wenn FIFO voll ist (Schreiben nicht moeglich)
        empty : OUT STD_LOGIC -- '1' wenn FIFO leer ist
    );
END ENTITY voq_fifo;

ARCHITECTURE rtl OF voq_fifo IS

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
    SIGNAL frames_stored : unsigned(ADDR_WIDTH DOWNTO 0) := (OTHERS => '0'); -- Anzahl kompletter Frames

    -- Lese-Register (Pipeline-Stage)
    SIGNAL rd_reg : STD_LOGIC_VECTOR(8 DOWNTO 0) := (OTHERS => '0'); -- Register fuer aktuell gelesene Daten (Bit 8: EOF, Bits 7-0: Daten)
    SIGNAL rd_valid_reg : STD_LOGIC := '0'; -- '1' wenn rd_reg frisch mit Daten gefuellt wurde

    -- Interne Flags
    SIGNAL full_int : STD_LOGIC;
    SIGNAL empty_int : STD_LOGIC;
    SIGNAL can_write : STD_LOGIC; -- Schreiben erlaubt (wr_en UND nicht voll)
    SIGNAL can_read : STD_LOGIC; -- Lesen erlaubt (rd_en UND nicht leer)

BEGIN

    -- Berechne FIFO-Status-Flags
    full_int <= '1' WHEN count = to_unsigned(DEPTH, count'length) ELSE
        '0';
    empty_int <= '1' WHEN count = to_unsigned(0, count'length) ELSE
        '0';

    can_write <= '1' WHEN (wr_en = '1' AND full_int = '0') ELSE
        '0';
    can_read <= '1' WHEN (rd_en = '1' AND empty_int = '0') ELSE
        '0';

    ---------------------------------------------------------------------------
    -- 1) Schreibport (kombinatorisch auf RAM)
    -- Schreibt Datenbyte und EOF-Flag gemeinsam auf die RAM-Adresse wr_ptr
    ---------------------------------------------------------------------------
    write_proc : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF can_write = '1' THEN
                -- Speicherformat: Bit 8 = EOF, Bits 7-0 = Daten
                ram(to_integer(wr_ptr)) <= wr_eof & wr_data;
            END IF;
        END IF;
    END PROCESS write_proc;

    ---------------------------------------------------------------------------
    -- 2) Leseport (synchron mit rd_valid-Pipeline)
    -- rd_reg wird mit Daten aus RAM gefuellt, wenn rd_en='1' und FIFO nicht leer
    -- rd_valid_reg merkt sich, ob rd_reg gueltige Daten enthaelt
    ---------------------------------------------------------------------------
    read_proc : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' OR flush = '1' THEN
                rd_reg <= (OTHERS => '0');
            ELSIF can_read = '1' THEN
                -- Lade Byte aus RAM: EOF-Flag + Datenbyte
                rd_reg <= ram(to_integer(rd_ptr));
            END IF;
        END IF;
    END PROCESS read_proc;

    -- Dekodiere das Read-Register
    rd_data <= rd_reg(7 DOWNTO 0); -- Lower 8 Bits = Daten

    -- rd_eof ist nur gueltig, wenn rd_valid_reg='1'
    rd_eof <= rd_reg(8) AND rd_valid_reg; -- Bit 8 = EOF-Flag
    rd_valid <= rd_valid_reg WHEN rd_valid_reg = '1' ELSE
        '0'; -- Signalisiere, ob Register gueltig ist

    ---------------------------------------------------------------------------
    -- 3) Pointer, Belegungszaehler und Frame-Zaehler
    -- Verwalte Schreib-/Lese-Pointer, Belegungstiefe und komplette Frames
    ---------------------------------------------------------------------------
    ptr_proc : PROCESS (clk)
        VARIABLE count_next : unsigned(count'RANGE);
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' OR flush = '1' THEN
                -- Reset: Alle Pointer auf 0, FIFO ist leer
                wr_ptr <= (OTHERS => '0');
                rd_ptr <= (OTHERS => '0');
                count <= (OTHERS => '0');
                frames_stored <= (OTHERS => '0');
                rd_valid_reg <= '0';
            ELSE
                -- rd_valid_reg folgt can_read, wird aber nach EOF sofort deaktiviert
                rd_valid_reg <= can_read AND NOT (rd_reg(8) AND rd_valid_reg);

                -- Pointer- und Belegungszaehler aktualisieren
                -- Schreiben immer zaehlen, Lesen nur wenn nicht EOF
                IF can_write = '1' THEN
                    wr_ptr <= wr_ptr + 1;
                END IF;

                IF can_read = '1' AND rd_eof = '0' THEN
                    rd_ptr <= rd_ptr + 1;
                END IF;

                count_next := count;
                IF can_write = '1' THEN
                    count_next := count_next + 1;
                END IF;
                IF can_read = '1' AND rd_eof = '0' THEN
                    count_next := count_next - 1;
                END IF;
                count <= count_next;

                -- Frame-Zaehler: Zaehle komplette Frames
                -- Schreiben eines EOF-Bytes (wr_eof='1') erhoeht den Zaehler
                -- Auslesen eines EOF-Bytes (rd_eof=rd_reg(8)='1') verringert den Zaehler
                IF (can_write = '1' AND wr_eof = '1') AND
                    (rd_valid_reg = '1' AND rd_reg(8) = '1') THEN
                    -- Gleichzeitig: ein komplettes Frame rein, eines raus -> netto keine Aenderung
                    NULL;
                ELSIF (can_write = '1' AND wr_eof = '1') THEN
                    -- Nur Schreiben mit EOF: neues Frame fertig, Zaehler +1
                    frames_stored <= frames_stored + 1;
                ELSIF (rd_valid_reg = '1' AND rd_reg(8) = '1') THEN
                    -- Nur Lesen mit EOF: ein Frame verlasst das FIFO, Zaehler -1
                    frames_stored <= frames_stored - 1;
                END IF;
            END IF;
        END IF;
    END PROCESS ptr_proc;

    -- Ausgabe Status-Signale
    frame_rdy <= '1' WHEN frames_stored > to_unsigned(0, frames_stored'length) ELSE
        '0';
    full <= full_int;
    empty <= empty_int;

END ARCHITECTURE rtl;