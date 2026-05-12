-- =============================================================================
-- Top-Level Modul: voq_rr_crossbar_switch_top
--
-- Zweck:
--   Implementiert einen 4x4 VOQ-Switch (Virtual Output Queuing) mit
--   Round-Robin-Arbitrierung und Crossbar-Ausgangsstufe.
--
-- Architektur-Ueberblick:
--   Fuer jeden der 4 Ausgaenge gibt es ein unabhaengiges VOQ-Buendel:
--     - voq_4to1  : 4 FIFOs, je einer pro Eingangsport, puffern die Frames
--                   die fuer diesen Ausgang bestimmt sind.
--     - round_robin: Arbiter, der entscheidet welcher der 4 FIFOs als naechstes
--                   lesen darf. Er vergibt den Grant erst nach vollstaendigem
--                   Uebertragen eines Frames (Lock bis EOF).
--     - crossbar_switch: Schaltet fuer jeden Ausgang den Datenstrom des aktuell
--                   granteten FIFOs durch (gesteuert per rr_sel).
--
-- Datenfluss (Beispiel: Eingang 2 -> Ausgang 1):
--   wr_data_in2_out1 --> VOQ(out1).FIFO(in2) --> round_robin(out1) vergibt Grant
--   --> rd_en_o1(2) = '1' --> rd_data_o1_2 --> crossbar (sel_1="10") --> out_data_1
--
-- VOQ-Prinzip:
--   Jeder Eingang schreibt gleichzeitig in bis zu 4 FIFOs (einen je Zielausgang).
--   Dadurch koennen keine Head-of-Line-Blocking-Probleme entstehen, die beim
--   klassischen Shared-Memory-Switch auftreten wuerden.
--
-- Schnittstellen-Konvention:
--   wr_data_inX_outY : Schreibdaten von Eingang X fuer Ausgang Y
--   wr_en_inX_outY   : Schreibfreigabe (aktiv high)
--   wr_eof_inX_outY  : End-of-Frame Markierung beim letzten Byte eines Frames
--   out_data_Y       : Ausgabedaten an Ausgang Y
--   out_valid_Y      : Gibt an, ob die Ausgabedaten gueltig sind (FIFO nicht leer)
--
-- Wichtige interne Signale:
--   frame_rdy_oX  : 4-Bit Vektor, Bit i = '1' wenn FIFO(i) von Queue X einen
--                   vollstaendigen Frame (mind. 1 EOF gesehen) bereit haelt
--   rr_sel_oX     : 2-Bit Index des aktuell bedienten FIFOs (0..3)
--   rr_grant_oX   : One-Hot Lesefreigabe fuer die 4 FIFOs der Queue X
--                   (z.B. "0100" = FIFO 2 darf lesen)
--   eof_mux_oX    : EOF-Signal des aktuell vom RR selektierten FIFOs;
--                   signalisiert dem Arbiter, dass der aktuelle Frame zu Ende ist
--   rd_en_oX      : wird direkt mit rr_grant_oX belegt -> FIFO-Lese-Enable
--
-- Debug-Ausgaenge:
--   rr_sel_X, rr_grant_X, rr_active_X : RR-Zustand pro Output
--   frame_rdy_dbg_X, rd_eof_dbg_X     : FIFO-Bereitschaft und EOF-Status
--   full_dbg_X, empty_dbg_X           : FIFO-Fuellstand-Flags
--
-- Generics:
--   DEPTH : Tiefe jedes einzelnen VOQ-FIFOs in Byte (Standard: 4096)
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity voq_rr_crossbar_switch_top is
    generic (
        DEPTH : integer := 4096  -- Tiefe jedes einzelnen VOQ-FIFOs in Byte
    );
    port (
        clk   : in  std_logic;  -- Systemtakt (steigende Flanke aktiv)
        reset : in  std_logic;  -- Synchroner Reset, aktiv high

        -- Flush-Signale: setzt die FIFOs einer Output-Queue zurueck.
        -- Bit i = '1' leert FIFO i der jeweiligen Queue sofort.
        flush_out0 : in std_logic_vector(3 downto 0);  -- Queue fuer Ausgang 0
        flush_out1 : in std_logic_vector(3 downto 0);  -- Queue fuer Ausgang 1
        flush_out2 : in std_logic_vector(3 downto 0);  -- Queue fuer Ausgang 2
        flush_out3 : in std_logic_vector(3 downto 0);  -- Queue fuer Ausgang 3

        -- =====================================================================
        -- Schreibseite: 4 Eingangsports x 4 Zielports = 16 getrennte Kanaele
        -- Jeder Kanal schreibt byteweise in das zugehoerige VOQ-FIFO.
        -- =====================================================================

        -- Eingang 0: Frames von Port 0 fuer jeden der 4 Ausgaenge
        wr_en_in0   : in std_logic_vector(3 downto 0);       -- Schreibfreigabe   
        wr_data_in0 : in std_logic_vector(7 downto 0);  -- Datenbyte
        wr_eof_in0  : in std_logic;                     -- '1' beim letzten Byte des Frames




        -- Eingang 1: Frames von Port 1 fuer jeden der 4 Ausgaenge
        wr_en_in1   : in std_logic_vector(3 downto 0);       -- Schreibfreigabe   
        wr_data_in1 : in std_logic_vector(7 downto 0);  -- Datenbyte
        wr_eof_in1  : in std_logic; 




        -- Eingang 2: Frames von Port 2 fuer jeden der 4 Ausgaenge
        wr_en_in2   : in std_logic_vector(3 downto 0);       -- Schreibfreigabe   
        wr_data_in2 : in std_logic_vector(7 downto 0);  -- Datenbyte
        wr_eof_in2  : in std_logic; 





        -- Eingang 3: Frames von Port 3 fuer jeden der 4 Ausgaenge
        wr_en_in3   : in std_logic_vector(3 downto 0);       -- Schreibfreigabe   
        wr_data_in3 : in std_logic_vector(7 downto 0);  -- Datenbyte
        wr_eof_in3  : in std_logic;




        -- =====================================================================
        -- Ausgangsseite: Nutzdaten und Valid-Flag je Ausgangsport
        -- =====================================================================
        out_data_0  : out std_logic_vector(7 downto 0);  -- Ausgabedaten Ausgang 0
        out_data_1  : out std_logic_vector(7 downto 0);  -- Ausgabedaten Ausgang 1
        out_data_2  : out std_logic_vector(7 downto 0);  -- Ausgabedaten Ausgang 2
        out_data_3  : out std_logic_vector(7 downto 0);  -- Ausgabedaten Ausgang 3

        -- Valid = '1': Ausgabedaten sind gueltig (mind. ein FIFO dieser Queue aktiv)
        out_valid_0 : out std_logic;
        out_valid_1 : out std_logic;
        out_valid_2 : out std_logic;
        out_valid_3 : out std_logic;




        -- =====================================================================
        -- Debug-Ausgaenge: RR-Zustand je Ausgangsport
        -- =====================================================================

        -- Aktuell selektierter FIFO-Index (0..3) im Round-Robin
        rr_sel_0    : out std_logic_vector(1 downto 0);
        rr_sel_1    : out std_logic_vector(1 downto 0);
        rr_sel_2    : out std_logic_vector(1 downto 0);
        rr_sel_3    : out std_logic_vector(1 downto 0);

        -- One-Hot Grant: welcher FIFO gerade lesen darf (Bit i = FIFO i)
        rr_grant_0  : out std_logic_vector(3 downto 0);
        rr_grant_1  : out std_logic_vector(3 downto 0);
        rr_grant_2  : out std_logic_vector(3 downto 0);
        rr_grant_3  : out std_logic_vector(3 downto 0);

        -- '1': RR-Arbiter ist aktiv (bedient gerade einen Frame)
        rr_active_0 : out std_logic;
        rr_active_1 : out std_logic;
        rr_active_2 : out std_logic;
        rr_active_3 : out std_logic;




        -- =====================================================================
        -- Debug-Ausgaenge: FIFO-Statussignale je Ausgangsqueue
        -- Alle als 4-Bit-Vektoren, Bit i entspricht dem FIFO von Eingang i.
        -- =====================================================================

        -- '1': FIFO haelt mindestens einen vollstaendigen Frame bereit (EOF gesehen)
        frame_rdy_dbg_0 : out std_logic_vector(3 downto 0);
        frame_rdy_dbg_1 : out std_logic_vector(3 downto 0);
        frame_rdy_dbg_2 : out std_logic_vector(3 downto 0);
        frame_rdy_dbg_3 : out std_logic_vector(3 downto 0);

        -- '1': Das aktuell gelesene Byte ist das letzte Byte eines Frames (EOF)
        rd_eof_dbg_0 : out std_logic_vector(3 downto 0);
        rd_eof_dbg_1 : out std_logic_vector(3 downto 0);
        rd_eof_dbg_2 : out std_logic_vector(3 downto 0);
        rd_eof_dbg_3 : out std_logic_vector(3 downto 0);

        -- '1': FIFO ist voll, neue Schreibzugriffe werden verworfen
        full_dbg_0 : out std_logic_vector(3 downto 0);
        full_dbg_1 : out std_logic_vector(3 downto 0);
        full_dbg_2 : out std_logic_vector(3 downto 0);
        full_dbg_3 : out std_logic_vector(3 downto 0);

        -- '1': FIFO ist leer, Lesedaten sind nicht gueltig
        empty_dbg_0 : out std_logic_vector(3 downto 0);
        empty_dbg_1 : out std_logic_vector(3 downto 0);
        empty_dbg_2 : out std_logic_vector(3 downto 0);
        empty_dbg_3 : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of voq_rr_crossbar_switch_top is

    ---------------------------------------------------------------------------
    -- Interne Signale fuer Output-Queue 0
    -- Verbinden voq_4to1, round_robin und crossbar fuer Ausgang 0.
    ---------------------------------------------------------------------------

    -- One-Hot Lesefreigabe: Bit i = '1' -> FIFO i von Queue 0 darf lesen.
    -- Wird direkt vom RR-Grant getrieben.
    signal rd_en_o0      : std_logic_vector(3 downto 0);

    -- Ausgangsdaten der vier FIFOs in Queue 0 (je ein Byte pro Takt)
    -- rd_data_o0_i: Lesedaten des FIFOs von Eingang i, destined fuer Ausgang 0
    signal rd_data_o0_0  : std_logic_vector(7 downto 0);
    signal rd_data_o0_1  : std_logic_vector(7 downto 0);
    signal rd_data_o0_2  : std_logic_vector(7 downto 0);
    signal rd_data_o0_3  : std_logic_vector(7 downto 0);

    -- EOF-Flags der vier FIFOs (Bit i = '1': aktuelles Byte ist Frame-Ende)
    signal rd_eof_o0     : std_logic_vector(3 downto 0);
    -- Frame-Ready-Flags (Bit i = '1': FIFO i hat vollstaendigen Frame)
    signal frame_rdy_o0  : std_logic_vector(3 downto 0);
    -- Full/Empty-Status der vier FIFOs
    signal full_o0       : std_logic_vector(3 downto 0);
    signal empty_o0      : std_logic_vector(3 downto 0);

    -- RR-Ausgangssignale fuer Queue 0
    signal rr_sel_o0     : std_logic_vector(1 downto 0);  -- Index des granteten FIFOs
    signal rr_grant_o0   : std_logic_vector(3 downto 0);  -- One-Hot Grant
    signal rr_active_o0  : std_logic;                     -- Arbiter belegt
    -- EOF des aktuell vom RR selektierten FIFOs (via MUX aus rd_eof_o0 ausgewaehlt)
    signal eof_mux_o0    : std_logic;

    ---------------------------------------------------------------------------
    -- Interne Signale fuer Output-Queue 1 (analog zu Queue 0)
    ---------------------------------------------------------------------------
    signal rd_en_o1      : std_logic_vector(3 downto 0);

    signal rd_data_o1_0  : std_logic_vector(7 downto 0);
    signal rd_data_o1_1  : std_logic_vector(7 downto 0);
    signal rd_data_o1_2  : std_logic_vector(7 downto 0);
    signal rd_data_o1_3  : std_logic_vector(7 downto 0);

    signal rd_eof_o1     : std_logic_vector(3 downto 0);
    signal frame_rdy_o1  : std_logic_vector(3 downto 0);
    signal full_o1       : std_logic_vector(3 downto 0);
    signal empty_o1      : std_logic_vector(3 downto 0);

    signal rr_sel_o1     : std_logic_vector(1 downto 0);
    signal rr_grant_o1   : std_logic_vector(3 downto 0);
    signal rr_active_o1  : std_logic;
    signal eof_mux_o1    : std_logic;

    ---------------------------------------------------------------------------
    -- Interne Signale fuer Output-Queue 2 (analog zu Queue 0)
    ---------------------------------------------------------------------------
    signal rd_en_o2      : std_logic_vector(3 downto 0);

    signal rd_data_o2_0  : std_logic_vector(7 downto 0);
    signal rd_data_o2_1  : std_logic_vector(7 downto 0);
    signal rd_data_o2_2  : std_logic_vector(7 downto 0);
    signal rd_data_o2_3  : std_logic_vector(7 downto 0);

    signal rd_eof_o2     : std_logic_vector(3 downto 0);
    signal frame_rdy_o2  : std_logic_vector(3 downto 0);
    signal full_o2       : std_logic_vector(3 downto 0);
    signal empty_o2      : std_logic_vector(3 downto 0);

    signal rr_sel_o2     : std_logic_vector(1 downto 0);
    signal rr_grant_o2   : std_logic_vector(3 downto 0);
    signal rr_active_o2  : std_logic;
    signal eof_mux_o2    : std_logic;

    ---------------------------------------------------------------------------
    -- Interne Signale fuer Output-Queue 3 (analog zu Queue 0)
    ---------------------------------------------------------------------------
    signal rd_en_o3      : std_logic_vector(3 downto 0);

    signal rd_data_o3_0  : std_logic_vector(7 downto 0);
    signal rd_data_o3_1  : std_logic_vector(7 downto 0);
    signal rd_data_o3_2  : std_logic_vector(7 downto 0);
    signal rd_data_o3_3  : std_logic_vector(7 downto 0);

    signal rd_eof_o3     : std_logic_vector(3 downto 0);
    signal frame_rdy_o3  : std_logic_vector(3 downto 0);
    signal full_o3       : std_logic_vector(3 downto 0);
    signal empty_o3      : std_logic_vector(3 downto 0);

    signal rr_sel_o3     : std_logic_vector(1 downto 0);
    signal rr_grant_o3   : std_logic_vector(3 downto 0);
    signal rr_active_o3  : std_logic;
    signal eof_mux_o3    : std_logic;

begin

    ---------------------------------------------------------------------------
    -- Output-Queue 0: VOQ-Buendel + Round-Robin-Arbitrierung
    --
    -- voq_4to1 buendelt die 4 FIFOs (einen je Eingangsport) fuer Ausgang 0.
    -- Der Round-Robin bestimmt, welcher FIFO gerade lesen darf.
    -- Steuerfluss: frame_rdy -> RR -> grant -> rd_en -> FIFO liest
    ---------------------------------------------------------------------------
    u_voq_out0 : entity work.voq_4to1
        generic map (DEPTH => DEPTH)
        port map (
            clk         => clk,
            reset       => reset,
            flush       => flush_out0,

            -- Schreibports: Eingang 0..3, alle fuer Ausgang 0
            wr_data_in0 =>wr_data_in0,
            wr_en_in0   => wr_en_in0(0),
            wr_eof_in0  => wr_eof_in0,

            wr_data_in1 => wr_data_in1,
            wr_en_in1   => wr_en_in1(0),
            wr_eof_in1  => wr_eof_in1,

            wr_data_in2 => wr_data_in2,
            wr_en_in2   => wr_en_in2(0),
            wr_eof_in2  => wr_eof_in2,

            wr_data_in3 => wr_data_in3,
            wr_en_in3   => wr_en_in3(0),
            wr_eof_in3  => wr_eof_in3,

            -- One-Hot Lesefreigabe: kommt vom RR-Arbiter (via rd_en_o0)
            rd_en       => rd_en_o0,

            -- Ausgangsdaten der 4 FIFOs (parallel verfuegbar, Crossbar waehlt aus)
            rd_data_0   => rd_data_o0_0,
            rd_data_1   => rd_data_o0_1,
            rd_data_2   => rd_data_o0_2,
            rd_data_3   => rd_data_o0_3,

            rd_valid    => out_valid_0,   -- '1': mind. ein FIFO liefert gueltige Daten
            rd_eof      => rd_eof_o0,     -- EOF-Flags aller 4 FIFOs
            frame_rdy   => frame_rdy_o0,  -- Frame-Ready-Flags fuer RR-Eingabe
            full        => full_o0,
            empty       => empty_o0
        );

    -- EOF-MUX fuer Queue 0:
    -- Der RR-Arbiter benoetigt das EOF-Signal des aktuell bedienten FIFOs,
    -- um zu erkennen, wann ein Frame abgeschlossen ist und der naechste Grant
    -- vergeben werden kann. rr_sel_o0 gibt den Index (0..3) an.
    with rr_sel_o0 select
        eof_mux_o0 <= rd_eof_o0(0) when "00",
                     rd_eof_o0(1) when "01",
                     rd_eof_o0(2) when "10",
                     rd_eof_o0(3) when others;

    -- Round-Robin Arbiter fuer Queue 0:
    -- Wartet auf frame_rdy, vergibt Grant, haelt diesen bis EOF ('1'),
    -- dann naechster bereiter FIFO in Round-Robin-Reihenfolge.
    u_rr_o0 : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_o0,  -- Welche FIFOs haben einen Frame bereit?
            eof       => eof_mux_o0,    -- Ende des aktuellen Frames -> Grant wechseln
            sel       => rr_sel_o0,     -- Aktueller FIFO-Index (an Crossbar)
            grant     => rr_grant_o0,   -- One-Hot Grant (an FIFO rd_en)
            active    => rr_active_o0   -- Arbiter bedient gerade einen Frame
        );

    -- Grant direkt als FIFO-Lesefreigabe verwenden
    rd_en_o0 <= rr_grant_o0;

    ---------------------------------------------------------------------------
    -- Output-Queue 1: VOQ-Buendel + Round-Robin-Arbitrierung (analog zu Queue 0)
    ---------------------------------------------------------------------------
    u_voq_out1 : entity work.voq_4to1
        generic map (DEPTH => DEPTH)
        port map (
            clk         => clk,
            reset       => reset,
            flush       => flush_out1,

            wr_data_in0 =>wr_data_in0,
            wr_en_in0   => wr_en_in0(1),
            wr_eof_in0  => wr_eof_in0,

            wr_data_in1 => wr_data_in1,
            wr_en_in1   => wr_en_in1(1),
            wr_eof_in1  => wr_eof_in1,

            wr_data_in2 => wr_data_in2,
            wr_en_in2   => wr_en_in2(1),
            wr_eof_in2  => wr_eof_in2,

            wr_data_in3 => wr_data_in3,
            wr_en_in3   => wr_en_in3(1),
            wr_eof_in3  => wr_eof_in3,

            rd_en       => rd_en_o1,

            rd_data_0   => rd_data_o1_0,
            rd_data_1   => rd_data_o1_1,
            rd_data_2   => rd_data_o1_2,
            rd_data_3   => rd_data_o1_3,

            rd_valid    => out_valid_1,
            rd_eof      => rd_eof_o1,
            frame_rdy   => frame_rdy_o1,
            full        => full_o1,
            empty       => empty_o1
        );

    -- EOF-MUX fuer Queue 1: waehlt EOF des aktuell granteten FIFOs aus
    with rr_sel_o1 select
        eof_mux_o1 <= rd_eof_o1(0) when "00",
                     rd_eof_o1(1) when "01",
                     rd_eof_o1(2) when "10",
                     rd_eof_o1(3) when others;

    -- Round-Robin Arbiter fuer Queue 1
    u_rr_o1 : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_o1,
            eof       => eof_mux_o1,
            sel       => rr_sel_o1,
            grant     => rr_grant_o1,
            active    => rr_active_o1
        );

    rd_en_o1 <= rr_grant_o1;

    ---------------------------------------------------------------------------
    -- Output-Queue 2: VOQ-Buendel + Round-Robin-Arbitrierung (analog zu Queue 0)
    ---------------------------------------------------------------------------
    u_voq_out2 : entity work.voq_4to1
        generic map (DEPTH => DEPTH)
        port map (
            clk         => clk,
            reset       => reset,
            flush       => flush_out2,

            wr_data_in0 => wr_data_in0,
            wr_en_in0   => wr_en_in0(2),
            wr_eof_in0  => wr_eof_in0,

            wr_data_in1 => wr_data_in1,
            wr_en_in1   => wr_en_in1(2),
            wr_eof_in1  => wr_eof_in1,

            wr_data_in2 => wr_data_in2,
            wr_en_in2   => wr_en_in2(2),
            wr_eof_in2  => wr_eof_in2,

            wr_data_in3 => wr_data_in3,
            wr_en_in3   => wr_en_in3(2),
            wr_eof_in3  => wr_eof_in3,

            rd_en       => rd_en_o2,

            rd_data_0   => rd_data_o2_0,
            rd_data_1   => rd_data_o2_1,
            rd_data_2   => rd_data_o2_2,
            rd_data_3   => rd_data_o2_3,

            rd_valid    => out_valid_2,

            rd_eof      => rd_eof_o2,
            frame_rdy   => frame_rdy_o2,
            full        => full_o2,
            empty       => empty_o2
        );

    -- EOF-MUX fuer Queue 2: waehlt EOF des aktuell granteten FIFOs aus
    with rr_sel_o2 select
        eof_mux_o2 <= rd_eof_o2(0) when "00",
                     rd_eof_o2(1) when "01",
                     rd_eof_o2(2) when "10",
                     rd_eof_o2(3) when others;

    -- Round-Robin Arbiter fuer Queue 2
    u_rr_o2 : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_o2,
            eof       => eof_mux_o2,
            sel       => rr_sel_o2,
            grant     => rr_grant_o2,
            active    => rr_active_o2
        );

    rd_en_o2 <= rr_grant_o2;

    ---------------------------------------------------------------------------
    -- Output-Queue 3: VOQ-Buendel + Round-Robin-Arbitrierung (analog zu Queue 0)
    ---------------------------------------------------------------------------
    u_voq_out3 : entity work.voq_4to1
        generic map (DEPTH => DEPTH)
        port map (
            clk         => clk,
            reset       => reset,
            flush       => flush_out3,

            wr_data_in0 =>wr_data_in0,
            wr_en_in0   => wr_en_in0(3),
            wr_eof_in0  => wr_eof_in0,

            wr_data_in1 => wr_data_in1,
            wr_en_in1   => wr_en_in1(3),
            wr_eof_in1  => wr_eof_in1,

            wr_data_in2 => wr_data_in2,
            wr_en_in2   => wr_en_in2(3),
            wr_eof_in2  => wr_eof_in2,

            wr_data_in3 => wr_data_in3,
            wr_en_in3   => wr_en_in3(3),
            wr_eof_in3  => wr_eof_in3,

            rd_en       => rd_en_o3,

            rd_data_0   => rd_data_o3_0,
            rd_data_1   => rd_data_o3_1,
            rd_data_2   => rd_data_o3_2,
            rd_data_3   => rd_data_o3_3,

            rd_valid    => out_valid_3,

            rd_eof      => rd_eof_o3,
            frame_rdy   => frame_rdy_o3,
            full        => full_o3,
            empty       => empty_o3
        );

    -- EOF-MUX fuer Queue 3: waehlt EOF des aktuell granteten FIFOs aus
    with rr_sel_o3 select
        eof_mux_o3 <= rd_eof_o3(0) when "00",
                     rd_eof_o3(1) when "01",
                     rd_eof_o3(2) when "10",
                     rd_eof_o3(3) when others;

    -- Round-Robin Arbiter fuer Queue 3
    u_rr_o3 : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_o3,
            eof       => eof_mux_o3,
            sel       => rr_sel_o3,
            grant     => rr_grant_o3,
            active    => rr_active_o3
        );

    rd_en_o3 <= rr_grant_o3;

    ---------------------------------------------------------------------------
    -- Crossbar-Switch: Ausgangsmultiplexer
    --
    -- Die Crossbar nimmt alle 16 FIFO-Ausgangsdatenstroeme entgegen und
    -- schaltet fuer jeden Ausgangsport (0..3) genau einen Datenstrom durch.
    -- Die Auswahl erfolgt ueber rr_sel_oX (2-Bit Index des granteten FIFOs).
    --
    -- Port-Benennung: data_mX_iY
    --   mX = Output-Queue X (welcher Ausgang diese Daten benoetigt)
    --   iY = FIFO von Eingang Y innerhalb dieser Queue
    --
    -- Beispiel: data_m2_i1 = Daten aus Queue 2, FIFO von Eingang 1
    --           -> diese Bytes kommen von Eingang 1 und sind fuer Ausgang 2 bestimmt
    ---------------------------------------------------------------------------
    u_xbar : entity work.crossbar_switch
        port map (
            clk   => clk,
            reset => reset,

            -- Eingangsdaten fuer Ausgangsport 0 (alle 4 FIFOs von Queue 0)
            data_m0_i0 => rd_data_o0_0,  -- Queue 0, FIFO von Eingang 0
            data_m0_i1 => rd_data_o0_1,  -- Queue 0, FIFO von Eingang 1
            data_m0_i2 => rd_data_o0_2,  -- Queue 0, FIFO von Eingang 2
            data_m0_i3 => rd_data_o0_3,  -- Queue 0, FIFO von Eingang 3

            -- Eingangsdaten fuer Ausgangsport 1 (alle 4 FIFOs von Queue 1)
            data_m1_i0 => rd_data_o1_0,
            data_m1_i1 => rd_data_o1_1,
            data_m1_i2 => rd_data_o1_2,
            data_m1_i3 => rd_data_o1_3,

            -- Eingangsdaten fuer Ausgangsport 2 (alle 4 FIFOs von Queue 2)
            data_m2_i0 => rd_data_o2_0,
            data_m2_i1 => rd_data_o2_1,
            data_m2_i2 => rd_data_o2_2,
            data_m2_i3 => rd_data_o2_3,

            -- Eingangsdaten fuer Ausgangsport 3 (alle 4 FIFOs von Queue 3)
            data_m3_i0 => rd_data_o3_0,
            data_m3_i1 => rd_data_o3_1,
            data_m3_i2 => rd_data_o3_2,
            data_m3_i3 => rd_data_o3_3,

            -- Auswahlsignale: Index des aktuell granteten FIFOs je Queue
            -- (kommen direkt vom jeweiligen Round-Robin-Arbiter)
            sel_0 => rr_sel_o0,  -- Steuert MUX fuer out_data_0
            sel_1 => rr_sel_o1,  -- Steuert MUX fuer out_data_1
            sel_2 => rr_sel_o2,  -- Steuert MUX fuer out_data_2
            sel_3 => rr_sel_o3,  -- Steuert MUX fuer out_data_3

            -- Ausgabedaten der vier Ausgangsports
            out_data_0 => out_data_0,
            out_data_1 => out_data_1,
            out_data_2 => out_data_2,
            out_data_3 => out_data_3
        );

    ---------------------------------------------------------------------------
    -- Debug-Ausgaenge: interne Signale nach aussen durchschleifen
    -- Alle Zuweisungen sind reine Leitungsverbindungen (keine Logik).
    ---------------------------------------------------------------------------

    -- RR-Selektions-Index und Grant-Vektoren (fuer Beobachtung der Arbitrierung)
    rr_sel_0 <= rr_sel_o0;
    rr_sel_1 <= rr_sel_o1;
    rr_sel_2 <= rr_sel_o2;
    rr_sel_3 <= rr_sel_o3;

    rr_grant_0 <= rr_grant_o0;
    rr_grant_1 <= rr_grant_o1;
    rr_grant_2 <= rr_grant_o2;
    rr_grant_3 <= rr_grant_o3;

    -- Active-Flag: zeigt an ob der RR gerade einen Frame durchleitet
    rr_active_0 <= rr_active_o0;
    rr_active_1 <= rr_active_o1;
    rr_active_2 <= rr_active_o2;
    rr_active_3 <= rr_active_o3;

    -- FIFO-Bereitschaft: mind. ein vollstaendiger Frame im jeweiligen FIFO
    frame_rdy_dbg_0 <= frame_rdy_o0;
    frame_rdy_dbg_1 <= frame_rdy_o1;
    frame_rdy_dbg_2 <= frame_rdy_o2;
    frame_rdy_dbg_3 <= frame_rdy_o3;

    -- EOF beim aktuellen Lesebyte je FIFO
    rd_eof_dbg_0 <= rd_eof_o0;
    rd_eof_dbg_1 <= rd_eof_o1;
    rd_eof_dbg_2 <= rd_eof_o2;
    rd_eof_dbg_3 <= rd_eof_o3;

    -- FIFO voll (Schreibseite: Ueberlauf-Warnung)
    full_dbg_0 <= full_o0;
    full_dbg_1 <= full_o1;
    full_dbg_2 <= full_o2;
    full_dbg_3 <= full_o3;

    -- FIFO leer (Leseseite: keine gueltigen Daten verfuegbar)
    empty_dbg_0 <= empty_o0;
    empty_dbg_1 <= empty_o1;
    empty_dbg_2 <= empty_o2;
    empty_dbg_3 <= empty_o3;

end architecture rtl;
