-- =============================================================================
-- Modul: voq_4to1
-- Beschreibung:
--   Buendelt 4 Virtual-Output-Queues (VOQs) fuer einen gemeinsamen Ausgangsport.
--
--   Im Crossbar-Switch hat jeder Eingangsport pro Ausgangsport eine eigene
--   FIFO-Queue (VOQ). Dieses Modul fasst genau die 4 VOQs zusammen, die alle
--   auf denselben Zielport schreiben wollen.
--
--   Struktur:
--     Eingang 0 --> FIFO 0 (fifo_in0_out0) --> rd_data_0
--     Eingang 1 --> FIFO 1 (fifo_in1_out0) --> rd_data_1
--     Eingang 2 --> FIFO 2 (fifo_in2_out0) --> rd_data_2
--     Eingang 3 --> FIFO 3 (fifo_in3_out0) --> rd_data_3
--
--   Der Round-Robin-Arbiter steuert ueber rd_en(i), welches FIFO gerade
--   ausgelesen werden darf. frame_rdy(i) meldet dem Arbiter zurueck,
--   ob FIFO i ein vollstaendiges Frame bereit hat.
--
-- Generic:
--   DEPTH  Tiefe jedes einzelnen FIFOs in Eintraegen (Standard: 4096 Bytes)
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity voq_4to1 is
    generic (
        DEPTH : integer := 4096  -- Tiefe jedes FIFO-Speichers in Eintraegen
    );
    port (
        clk   : in std_logic;  -- Systemtakt
        reset : in std_logic;  -- Synchroner Reset (aktiv high)
        flush : in std_logic_vector(3 downto 0);-- neue logische Leerung der jeweiligen FIFO (flush(i) = '1' leert FIFO i)

        -- -----------------------------------------------------------------
        -- Schreibseite: 4 unabhaengige Eingangsdatenstroeme
        -- Jeder Eingang schreibt in sein eigenes FIFO (fuer denselben Zielport).
        -- wr_en_inX  : Schreibfreigabe fuer Eingang X
        -- wr_data_inX: 8-Bit-Datenwort von Eingang X
        -- wr_eof_inX : End-of-Frame-Markierung fuer Eingang X
        -- -----------------------------------------------------------------
        wr_data_in0 : in std_logic_vector(7 downto 0);
        wr_en_in0   : in std_logic;
        wr_eof_in0  : in std_logic;

        wr_data_in1 : in std_logic_vector(7 downto 0);
        wr_en_in1   : in std_logic;
        wr_eof_in1  : in std_logic;

        wr_data_in2 : in std_logic_vector(7 downto 0);
        wr_en_in2   : in std_logic;
        wr_eof_in2  : in std_logic;

        wr_data_in3 : in std_logic_vector(7 downto 0);
        wr_en_in3   : in std_logic;
        wr_eof_in3  : in std_logic;

        -- -----------------------------------------------------------------
        -- Leseseite: vom Round-Robin-Arbiter gesteuert
        -- rd_en(i)    : Lesefreigabe fuer FIFO i (One-Hot vom RR-Grant)
        -- rd_data_i   : Ausgelesenes Datenwort aus FIFO i
        -- rd_eof(i)   : '1' wenn das aktuelle Byte das letzte im Frame ist
        -- frame_rdy(i): '1' wenn FIFO i ein vollstaendiges Frame enthaelt
        --               -> geht als Eingangssignal an den Round-Robin-Arbiter
        -- full(i)     : '1' wenn FIFO i voll ist (kein Schreiben moeglich)
        -- empty(i)    : '1' wenn FIFO i leer ist
        -- -----------------------------------------------------------------
        rd_en       : in  std_logic_vector(3 downto 0);

        rd_data_0   : out std_logic_vector(7 downto 0);
        rd_data_1   : out std_logic_vector(7 downto 0);
        rd_data_2   : out std_logic_vector(7 downto 0);
        rd_data_3   : out std_logic_vector(7 downto 0);
        
        rd_valid    : out STD_LOGIC;  -- '1' wenn rd_data_i gültige Daten enthält (mindestens ein FIFO hat gültige Daten)
        rd_eof      : out std_logic_vector(3 downto 0);
        frame_rdy   : out std_logic_vector(3 downto 0);
        full        : out std_logic_vector(3 downto 0);
        empty       : out std_logic_vector(3 downto 0)
    );
end entity;

-- -----------------------------------------------------------------------------
-- Architektur: Vier parallele voq_fifo-Instanzen
-- Jede Instanz ist identisch aufgebaut, unterscheidet sich nur in den
-- angeschlossenen Signalen (Eingang 0..3).
-- -----------------------------------------------------------------------------
architecture rtl of voq_4to1 is
    signal rd_valid_internal : std_logic_vector(3 downto 0) := (others => '0');
    signal rd_valid_any      : std_logic;
   

begin


    -- FIFO fuer Eingang 0 -> dieser Ausgangsport
    -- Speichert Frames von Eingang 0, bis der RR-Arbiter Grant erteilt
    fifo_in0_out0 : entity work.voq_fifo
        generic map (DEPTH => DEPTH)
        port map (
            clk       => clk,
            reset     => reset,
            flush => flush(0),
            wr_en     => wr_en_in0,
            wr_data   => wr_data_in0,
            wr_eof    => wr_eof_in0,
            rd_en     => rd_en(0),       -- Lesefreigabe vom RR fuer Kanal 0
            rd_data   => rd_data_0,
            rd_eof    => rd_eof(0),
            rd_valid => rd_valid_internal(0),
            frame_rdy => frame_rdy(0),   -- Meldet dem RR: Kanal 0 hat Frame bereit
            full      => full(0),
            empty     => empty(0)
        );

    -- FIFO fuer Eingang 1 -> dieser Ausgangsport
    fifo_in1_out0 : entity work.voq_fifo
        generic map (DEPTH => DEPTH)
        port map (
            clk       => clk,
            reset     => reset,
            flush => flush(0),
            wr_en     => wr_en_in1,
            wr_data   => wr_data_in1,
            wr_eof    => wr_eof_in1,
            rd_en     => rd_en(1),       -- Lesefreigabe vom RR fuer Kanal 1
            rd_data   => rd_data_1,
            rd_eof    => rd_eof(1),
            rd_valid => rd_valid_internal(1),
            frame_rdy => frame_rdy(1),   -- Meldet dem RR: Kanal 1 hat Frame bereit
            full      => full(1),
            empty     => empty(1)
        );

    -- FIFO fuer Eingang 2 -> dieser Ausgangsport
    fifo_in2_out0 : entity work.voq_fifo
        generic map (DEPTH => DEPTH)
        port map (
            clk       => clk,
            reset     => reset,
            flush => flush(0),
            wr_en     => wr_en_in2,
            wr_data   => wr_data_in2,
            wr_eof    => wr_eof_in2,
            rd_en     => rd_en(2),       -- Lesefreigabe vom RR fuer Kanal 2
            rd_data   => rd_data_2,
            rd_eof    => rd_eof(2),
            rd_valid => rd_valid_internal(2),
            
            frame_rdy => frame_rdy(2),   -- Meldet dem RR: Kanal 2 hat Frame bereit
            full      => full(2),
            empty     => empty(2)
        );

    -- FIFO fuer Eingang 3 -> dieser Ausgangsport
    fifo_in3_out0 : entity work.voq_fifo
        generic map (DEPTH => DEPTH)
        port map (
            clk       => clk,
            reset     => reset,
            flush => flush(0),
            wr_en     => wr_en_in3,
            wr_data   => wr_data_in3,
            wr_eof    => wr_eof_in3,
            rd_en     => rd_en(3),       -- Lesefreigabe vom RR fuer Kanal 3
            rd_data   => rd_data_3,
            rd_eof    => rd_eof(3),
                rd_valid => rd_valid_internal(3),
            frame_rdy => frame_rdy(3),   -- Meldet dem RR: Kanal 3 hat Frame bereit
            full      => full(3),
            empty     => empty(3)
        );

            rd_valid_any <= '1' when  rd_valid_internal /= "0000" else '0';
            rd_valid     <= rd_valid_any;

    

end architecture rtl;
