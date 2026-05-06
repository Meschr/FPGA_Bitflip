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


        crc_valid        : in  std_logic;                    -- CRC-Status (nur gueltig bei wr_eof='1')
        dest_port       : in  std_logic_vector(3 downto 0); -- Zielport des aktuellen Frames (nur gueltig bei wr_eof='1')                  
        dest_port_flag  : in  std_logic;                    -- '1' wenn dest_port gültig ist (nur bei wr_eof='1')

        -- -----------------------------------------------------------------
        -- Leseseite: Synchrones Lesen mit rd_valid-Flag
        -- -----------------------------------------------------------------
        rd_data       : out std_logic_vector(7 downto 0); -- Ausgelesenes Datenbyte
        rd_eof        : out std_logic;                    -- '1' wenn dies das EOF-Byte ist (nur gueltig wenn rd_valid='1')
        rd_dest_port_en  : out std_logic_vector(3 downto 0); -- Zielport des aktuellen Frames

        -- -----------------------------------------------------------------
        -- Status-Ausgaenge
        -- -----------------------------------------------------------------
        frame_rdy     : out std_logic;                     -- '1' wenn mindestens ein kompletter Frame im FIFO vorliegt
        full          : out std_logic_vector(3 downto 0)  -- '1' wenn FIFO voll ist (Schreiben nicht moeglich)
    );
end entity crc_to_voq_buffer;

architecture rtl of crc_to_voq_buffer is

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

    -- Lese-Register (Pipeline-Stage)
    signal rd_reg         : std_logic_vector(8 downto 0)      := (others => '0'); -- Register fuer aktuell gelesene Daten (Bit 8: EOF, Bits 7-0: Daten)
    signal rd_valid_reg   : std_logic                         := '0'; -- '1' wenn rd_reg frisch mit Daten gefuellt wurde

    -- Interne Flags
    signal full_int       : std_logic;
    signal empty_int      : std_logic;
    signal can_write      : std_logic;  -- Schreiben erlaubt (wr_en UND nicht voll)
    signal can_read       : std_logic;  -- Lesen erlaubt (rd_en UND nicht leer)

    signal start_rd      : std_logic;     
    

begin
    process (dest_port_flag) 
        variable rd_dest_port_en_int : std_logic_vector(3 downto 0) := (others => '0');

    begin
        if rising_edge(dest_port_flag) then       

            if    dest_port(0)='1' then
                rd_dest_port_en_int(0) := '1';
            elsif dest_port(1)='1' then
                rd_dest_port_en_int(1) := '1';
            elsif dest_port(2)='1' then
                rd_dest_port_en_int(2) := '1';
            elsif dest_port(3)='1' then
                rd_dest_port_en_int(3) :='1';
            end if;        
            
        end if;    

        rd_dest_port_en <= rd_dest_port_en_int;

    end process;
end architecture;