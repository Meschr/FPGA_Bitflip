-------------------------------------------------------------------------------
-- voq_fifo.vhd
-- Generischer Store-and-Forward FIFO für die VOQ-Matrix
--
-- Speicher: 4096 x 9 Bit (8 Bit Daten + 1 Bit EOF-Flag)
-- Dual-Port: Schreiben und Lesen gleichzeitig möglich
-- Frame-Zähler: frame_rdy erst wenn ein kompletter Frame drin liegt
-- Backpressure: full-Signal wenn kein Platz mehr ist
--
-- Wird 16× instanziiert (4 Eingänge × 4 Ziele)
--
-- DTU Fotonik - FPGA Design for Communications Systems
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity voq_fifo is
    generic (
        DEPTH : integer := 4096   -- FIFO-Tiefe in Bytes
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;

        -- Schreibseite (vom FCS-Block)
        wr_en       : in  std_logic;                      -- Byte schreiben
        wr_data     : in  std_logic_vector(7 downto 0);   -- Frame-Daten
        wr_eof      : in  std_logic;                      -- '1' beim letzten Byte

        -- Leseseite (zum Crossbar-MUX, gesteuert vom RR-Grant)
        rd_en       : in  std_logic;                      -- Byte lesen
        rd_data     : out std_logic_vector(7 downto 0);   -- Frame-Daten
        rd_eof      : out std_logic;                      -- '1' beim letzten Byte

        -- Status
        frame_rdy   : out std_logic;                      -- mind. 1 kompletter Frame drind
        full        : out std_logic;                      -- FIFO voll (Backpressure)
        empty       : out std_logic                       -- FIFO leer
    );
end entity voq_fifo;

architecture rtl of voq_fifo is

    -- Berechne Adressbreite aus DEPTH (funktioniert für jede 2er-Potenz)
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

    constant ADDR_WIDTH : integer := log2_ceil(DEPTH);  -- z.B. 5 für DEPTH=32, 12 für DEPTH=4096

    -- Dual-Port RAM: 9 Bit breit (8 Daten + 1 EOF)
    -- Synthesiser erkennt dieses Muster und mappt auf BRAM
    type ram_t is array (0 to DEPTH - 1) of std_logic_vector(8 downto 0);
    signal ram : ram_t;

    -- Schreib- und Lesezeiger
    signal wr_ptr   : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_ptr   : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');

    -- F�llstand (ein Bit mehr als Adresse, f�r voll/leer Unterscheidung)
    signal count    : unsigned(ADDR_WIDTH downto 0) := (others => '0');

    -- Frame-Z�hler: wie viele komplette Frames liegen im FIFO
    signal frames_stored : unsigned(7 downto 0) := (others => '0');  -- max 255 Frames

    -- Lese-Register
    signal rd_reg   : std_logic_vector(8 downto 0) := (others => '0');

    -- Verzögertes rd_en: gibt an, ob rd_reg im letzten Takt frisch geladen wurde.
    -- Nötig weil das BRAM synchron liest: rd_reg ist erst einen Takt NACH rd_en gültig.
    -- Erst wenn rd_valid='1' darf rd_reg(8) als EOF-Indikator ausgewertet werden.
    signal rd_valid : std_logic := '0';

begin

    ---------------------------------------------------------------------------
    -- Schreib-Prozess
    ---------------------------------------------------------------------------
    write_proc : process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                -- 9 Bit schreiben: EOF & Daten
                ram(to_integer(wr_ptr)) <= wr_eof & wr_data;
            end if;
        end if;
    end process write_proc;

    ---------------------------------------------------------------------------
    -- Lese-Prozess (synchrones Lesen für BRAM-Inferenz)
    ---------------------------------------------------------------------------
    read_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                rd_reg <= (others => '0');
            elsif rd_en = '1' then
                rd_reg <= ram(to_integer(rd_ptr));
            end if;
        end if;
    end process read_proc;

    -- Leseausgänge aufteilen
    rd_data <= rd_reg(7 downto 0);
    rd_eof  <= rd_reg(8);

    ---------------------------------------------------------------------------
    -- Pointer- und Zähler-Verwaltung
    ---------------------------------------------------------------------------
    ptr_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                wr_ptr        <= (others => '0');
                rd_ptr        <= (others => '0');
                count         <= (others => '0');
                frames_stored <= (others => '0');
                rd_valid      <= '0';

            else
                -- rd_valid: einen Takt hinter rd_en verzögert.
                -- Wenn rd_valid='1', liegt in rd_reg das gültige Byte vom Vortakt.
                rd_valid <= rd_en;

                -- Gleichzeitiges Lesen und Schreiben möglich
                -- Count ändert sich nur wenn nicht beides gleichzeitig
                if wr_en = '1' and rd_en = '0' then
                    -- Nur Schreiben
                    wr_ptr <= wr_ptr + 1;
                    count  <= count + 1;

                elsif wr_en = '0' and rd_en = '1' then
                    -- Nur Lesen
                    rd_ptr <= rd_ptr + 1;
                    count  <= count - 1;

                elsif wr_en = '1' and rd_en = '1' then
                    -- Beides gleichzeitig: count bleibt gleich
                    wr_ptr <= wr_ptr + 1;
                    rd_ptr <= rd_ptr + 1;
                end if;

                -- Frame-Zähler: hoch bei geschriebenem EOF,
                -- runter bei gelesenem EOF.
                -- rd_valid statt rd_en, weil rd_reg erst einen Takt nach rd_en gültig ist.
                if wr_en = '1' and wr_eof = '1' and rd_valid = '1' and rd_reg(8) = '1' then
                    -- EOF geschrieben UND EOF gelesen (versetzt): Zähler bleibt gleich
                    null;
                elsif wr_en = '1' and wr_eof = '1' then
                    -- Nur EOF geschrieben: ein Frame mehr
                    frames_stored <= frames_stored + 1;
                elsif rd_valid = '1' and rd_reg(8) = '1' then
                    -- Nur EOF gelesen: ein Frame weniger
                    frames_stored <= frames_stored - 1;
                end if;

            end if;
        end if;
    end process ptr_proc;

    ---------------------------------------------------------------------------
    -- Status-Signale (kombinatorisch)
    ---------------------------------------------------------------------------
    frame_rdy <= '1' when frames_stored > 0 else '0';
    full      <= '1' when count >= DEPTH - 1 else '0';
    empty     <= '1' when count = 0 else '0';

end architecture rtl;
