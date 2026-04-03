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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity voq_fifo is
    generic (
        DEPTH : integer := 4096  -- Tiefe des FIFO-Speichers in Eintraegen (Bytes)
    );
    port (
        clk         : in  std_logic;  -- Systemtakt
        reset       : in  std_logic;  -- Synchroner Reset (aktiv high)
        flush       : in  std_logic;  -- Logische Leerung (aktiv high): setzt alle Pointer und Zaehler auf Anfangswert

        -- -----------------------------------------------------------------
        -- Schreibseite: Eingangsframe mit EOF-Markierung
        -- -----------------------------------------------------------------
        wr_en       : in  std_logic;                    -- Schreibfreigabe
        wr_data     : in  std_logic_vector(7 downto 0); -- Datenbyte
        wr_eof      : in  std_logic;                    -- '1' wenn dies das letzte Byte des Frames ist

        -- -----------------------------------------------------------------
        -- Leseseite: Synchrones Lesen mit rd_valid-Flag
        -- -----------------------------------------------------------------
        rd_en       : in  std_logic;                    -- Lesefreigabe
        rd_data     : out std_logic_vector(7 downto 0); -- Ausgelesenes Datenbyte
        rd_eof      : out std_logic;                    -- '1' wenn dies das EOF-Byte ist (nur gueltig wenn rd_valid='1')
        rd_valid    : out std_logic;                    -- '1' wenn rd_data und rd_eof gueltige Daten enthalten

        -- -----------------------------------------------------------------
        -- Status-Ausgaenge
        -- -----------------------------------------------------------------
        frame_rdy   : out std_logic;  -- '1' wenn mindestens ein kompletter Frame im FIFO vorliegt
        full        : out std_logic;  -- '1' wenn FIFO voll ist (Schreiben nicht moeglich)
        empty       : out std_logic   -- '1' wenn FIFO leer ist
    );
end entity voq_fifo;

architecture rtl of voq_fifo is

    -- Hilfsfunktion: Berechnet die minimale Bit-Breite fuer einen Counter
    -- z.B. log2_ceil(4096) = 12, da 2^12 = 4096
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

    -- FIFO-Speicher: Jeder Eintrag ist 9 Bit (8 Bit Daten + 1 Bit EOF)
    type ram_t is array (0 to DEPTH - 1) of std_logic_vector(8 downto 0);
    signal ram : ram_t;

    -- Pointer und Zaehler
    signal wr_ptr         : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0'); -- Schreib-Adresse
    signal rd_ptr         : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0'); -- Lese-Adresse
    signal count          : unsigned(ADDR_WIDTH downto 0)     := (others => '0'); -- Anzahl Bytes im FIFO
    signal frames_stored  : unsigned(ADDR_WIDTH downto 0)     := (others => '0'); -- Anzahl kompletter Frames

    -- Lese-Register (Pipeline-Stage)
    signal rd_reg         : std_logic_vector(8 downto 0)      := (others => '0'); -- Register fuer aktuell gelesene Daten (Bit 8: EOF, Bits 7-0: Daten)
    signal rd_valid_reg   : std_logic                         := '0'; -- '1' wenn rd_reg frisch mit Daten gefuellt wurde

    -- Interne Flags
    signal full_int       : std_logic;
    signal empty_int      : std_logic;
    signal can_write      : std_logic;  -- Schreiben erlaubt (wr_en UND nicht voll)
    signal can_read       : std_logic;  -- Lesen erlaubt (rd_en UND nicht leer)

begin

    -- Berechne FIFO-Status-Flags
    full_int  <= '1' when count = to_unsigned(DEPTH, count'length) else '0';
    empty_int <= '1' when count = to_unsigned(0, count'length) else '0';

    can_write <= '1' when (wr_en = '1' and full_int = '0') else '0';
    can_read  <= '1' when (rd_en = '1' and empty_int = '0') else '0';

    ---------------------------------------------------------------------------
    -- 1) Schreibport (kombinatorisch auf RAM)
    -- Schreibt Datenbyte und EOF-Flag gemeinsam auf die RAM-Adresse wr_ptr
    ---------------------------------------------------------------------------
    write_proc : process(clk)
    begin
        if rising_edge(clk) then
            if can_write = '1' then
                -- Speicherformat: Bit 8 = EOF, Bits 7-0 = Daten
                ram(to_integer(wr_ptr)) <= wr_eof & wr_data;
            end if;
        end if;
    end process write_proc;

    ---------------------------------------------------------------------------
    -- 2) Leseport (synchron mit rd_valid-Pipeline)
    -- rd_reg wird mit Daten aus RAM gefuellt, wenn rd_en='1' und FIFO nicht leer
    -- rd_valid_reg merkt sich, ob rd_reg gueltige Daten enthaelt
    ---------------------------------------------------------------------------
    read_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or flush = '1' then
                rd_reg <= (others => '0');
            elsif can_read = '1' then
                -- Lade Byte aus RAM: EOF-Flag + Datenbyte
                rd_reg <= ram(to_integer(rd_ptr));
            end if;
        end if;
    end process read_proc;

    -- Dekodiere das Read-Register
    rd_data  <= rd_reg(7 downto 0);  -- Lower 8 Bits = Daten

    -- rd_eof ist nur gueltig, wenn rd_valid_reg='1'
    rd_eof   <= rd_reg(8) and rd_valid_reg;  -- Bit 8 = EOF-Flag
    rd_valid <= rd_valid_reg;                -- Signalisiere, ob Register gueltig ist

    ---------------------------------------------------------------------------
    -- 3) Pointer, Belegungszaehler und Frame-Zaehler
    -- Verwalte Schreib-/Lese-Pointer, Belegungstiefe und komplette Frames
    ---------------------------------------------------------------------------
    ptr_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or flush = '1' then
                -- Reset: Alle Pointer auf 0, FIFO ist leer
                wr_ptr        <= (others => '0');
                rd_ptr        <= (others => '0');
                count         <= (others => '0');
                frames_stored <= (others => '0');
                rd_valid_reg  <= '0';
            else
                -- rd_valid_reg folgt can_read: wird '1' wenn gerade ein Byte gelesen wurde
                rd_valid_reg <= can_read;

                -- Pointer- und Belegungszaehler aktualisieren:
                if can_write = '1' and can_read = '0' then
                    -- Nur Schreiben: wr_ptr erhoehen, count erhoehen
                    wr_ptr <= wr_ptr + 1;
                    count  <= count + 1;
                elsif can_write = '0' and can_read = '1' then
                    -- Nur Lesen: rd_ptr erhoehen, count verringern
                    rd_ptr <= rd_ptr + 1;
                    count  <= count - 1;
                elsif can_write = '1' and can_read = '1' then
                    -- Gleichzeitiges Schreiben und Lesen: beide Pointer erhoehen, count bleibt gleich
                    wr_ptr <= wr_ptr + 1;
                    rd_ptr <= rd_ptr + 1;
                end if;

                -- Frame-Zaehler: Zaehle komplette Frames
                -- Schreiben eines EOF-Bytes (wr_eof='1') erhoeht den Zaehler
                -- Auslesen eines EOF-Bytes (rd_eof=rd_reg(8)='1') verringert den Zaehler
                if (can_write = '1' and wr_eof = '1') and
                   (rd_valid_reg = '1' and rd_reg(8) = '1') then
                    -- Gleichzeitig: ein komplettes Frame rein, eines raus -> netto keine Aenderung
                    null;
                elsif (can_write = '1' and wr_eof = '1') then
                    -- Nur Schreiben mit EOF: neues Frame fertig, Zaehler +1
                    frames_stored <= frames_stored + 1;
                elsif (rd_valid_reg = '1' and rd_reg(8) = '1') then
                    -- Nur Lesen mit EOF: ein Frame verlasst das FIFO, Zaehler -1
                    frames_stored <= frames_stored - 1;
                end if;
            end if;
        end if;
    end process ptr_proc;

    -- Ausgabe Status-Signale
    frame_rdy <= '1' when frames_stored > to_unsigned(0, frames_stored'length) else '0';
    full      <= full_int;
    empty     <= empty_int;

end architecture rtl;
