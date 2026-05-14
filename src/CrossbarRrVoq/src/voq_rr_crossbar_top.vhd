-- =============================================================================
-- Top-Level Modul: voq_rr_crossbar_top
-- Beschreibung:
--   Kombiniert VOQ + Round-Robin + Crossbar Switch zu einem funktionsfaehigen
--   Switch fuer einen Zielport (currently nur Output 0 benutzt).
--
--   Blockdiagramm:
--
--     Eingang 0 ---|
--     Eingang 1 ---|
--     Eingang 2 ---|----> voq_4to1 ------+---> rd_data_0/1/2/3
--     Eingang 3 ---|                     |
--                                        |---> frame_rdy ---> Round-Robin
--                                        |
--                                        +---> rd_eof
--
--                         Round-Robin Steuert:
--                          - Welches VOQ wird gerade gelesen (rd_en, grant)
--                          - EOF-Signal geht zurueck vom multiplexten Ausgang
--
--                         Crossbar Switch:
--                          - MUX 0 schaltet eines der 4 VOQ-Ausgaenge durch
--                          - Selector kommt vom Round-Robin (rr_sel_s)
--
--   Diese Architektur implementiert einen Single-Output-Arbiter,
--   der reihum (Fair) zwischen den 4 Eingangskanaelen multiplext.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY voq_rr_crossbar_top IS
    GENERIC (
        DEPTH : INTEGER := 4096 -- Tiefe jedes VOQ-FIFOs
    );
    PORT (
        clk : IN STD_LOGIC; -- Systemtakt
        reset : IN STD_LOGIC; -- Synchroner Reset (aktiv high)
        flush : IN STD_LOGIC_VECTOR(3 DOWNTO 0); -- Flush-Signal fuer die VOQ-FIFOs (Bit i flusht FIFO i)

        -- -----------------------------------------------------------------
        -- Schreibseite (VOQ-Eingaenge): 4 unabhaengige Eingangsdatenstroeme
        -- -----------------------------------------------------------------
        wr_data_in0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en_in0 : IN STD_LOGIC;
        wr_eof_in0 : IN STD_LOGIC;

        wr_data_in1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en_in1 : IN STD_LOGIC;
        wr_eof_in1 : IN STD_LOGIC;

        wr_data_in2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en_in2 : IN STD_LOGIC;
        wr_eof_in2 : IN STD_LOGIC;

        wr_data_in3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en_in3 : IN STD_LOGIC;
        wr_eof_in3 : IN STD_LOGIC;

        -- -----------------------------------------------------------------
        -- Hauptausgang (nach Crossbar): Ausgangskanal 0
        -- -----------------------------------------------------------------
        out_data_0 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Gemultiplextes Datenbyte
        out_valid : OUT STD_LOGIC; -- '1' wenn out_data_0 gueltige Daten enthaelt

        -- -----------------------------------------------------------------
        -- Debug / Observation Ausgaenge (fuer Simulationen)
        -- -----------------------------------------------------------------
        rr_sel : OUT STD_LOGIC_VECTOR(1 DOWNTO 0); -- Aktuell vom RR gewaehltej Kanal
        rr_grant : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- Grant (One-Hot) vom RR
        rr_active : OUT STD_LOGIC; -- '1' wenn RR einen Kanal active hat

        frame_rdy_dbg : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- frame_rdy Status aller 4 VOQs
        rd_eof_dbg : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- rd_eof Status aller 4 VOQs
        full_dbg : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- full Status aller 4 VOQs
        empty_dbg : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) -- empty Status aller 4 VOQs
    );
END ENTITY;

ARCHITECTURE rtl OF voq_rr_crossbar_top IS

    -- =========================================================================
    -- Interne Signale fuer VOQ-zu-RR Schnittstelle
    -- =========================================================================
    SIGNAL rd_en_s : STD_LOGIC_VECTOR(3 DOWNTO 0); -- Lesefreigabe vom RR zu den VOQs (One-Hot)

    -- Ausgaenge der 4 VOQ-FIFOs (Daten)
    SIGNAL rd_data_0_s : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Datenausgang FIFO 0
    SIGNAL rd_data_1_s : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Datenausgang FIFO 1
    SIGNAL rd_data_2_s : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Datenausgang FIFO 2
    SIGNAL rd_data_3_s : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Datenausgang FIFO 3

    -- Ausgaenge der 4 VOQ-FIFOs (Status)
    SIGNAL rd_eof_s : STD_LOGIC_VECTOR(3 DOWNTO 0); -- EOF-Flags aller 4 FIFOs
    SIGNAL frame_rdy_s : STD_LOGIC_VECTOR(3 DOWNTO 0); -- frame_rdy Signale aller 4 FIFOs -> RR
    SIGNAL full_s : STD_LOGIC_VECTOR(3 DOWNTO 0); -- full Flags aller 4 FIFOs
    SIGNAL empty_s : STD_LOGIC_VECTOR(3 DOWNTO 0); -- empty Flags aller 4 FIFOs
    SIGNAL rd_valid_all_s : STD_LOGIC_VECTOR(3 DOWNTO 0); -- rd_valid Flags aller 4 FIFOs (derzeit ungenutzt)

    -- =========================================================================
    -- Interne Signale fuer Round-Robin Steuersignale
    -- =========================================================================
    SIGNAL rr_sel_s : STD_LOGIC_VECTOR(1 DOWNTO 0); -- Ausgewaehlter Kanal (RR Output, 0..3)
    SIGNAL rr_grant_s : STD_LOGIC_VECTOR(3 DOWNTO 0); -- One-Hot Grant (RR Output)
    SIGNAL rr_active_s : STD_LOGIC; -- '1' wenn RR einen gueltigen Grant haelt

    -- EOF-Signal fuer Round-Robin
    -- Der RR braucht das EOF des aktuell selektierten FIFOs
    SIGNAL eof_mux_s : STD_LOGIC;

    -- Dummy-Ausgaenge fuer Crossbar MUXe 1, 2, 3 (derzeit ungenutzt)
    SIGNAL out1_dummy : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL out2_dummy : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL out3_dummy : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    ---------------------------------------------------------------------------
    -- INSTANZ: voq_4to1
    -- Vier Virtual-Output-Queues (FIFOs) fuer einen Zielport
    -- Schreibseite: 4 unabhaengige Eingangsquellen
    -- Leseseite: Wird gesteuert durch rd_en_s (vom Round-Robin)
    ---------------------------------------------------------------------------
    u_voq_4to1 : ENTITY work.voq_4to1
        GENERIC MAP(
            DEPTH => DEPTH
        )
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => flush, -- Flush-Signale pro FIFO

            -- Schreibseite: Je ein Eingangsdatenstrom pro FIFO
            wr_data_in0 => wr_data_in0,
            wr_en_in0 => wr_en_in0,
            wr_eof_in0 => wr_eof_in0,

            wr_data_in1 => wr_data_in1,
            wr_en_in1 => wr_en_in1,
            wr_eof_in1 => wr_eof_in1,

            wr_data_in2 => wr_data_in2,
            wr_en_in2 => wr_en_in2,
            wr_eof_in2 => wr_eof_in2,

            wr_data_in3 => wr_data_in3,
            wr_en_in3 => wr_en_in3,
            wr_eof_in3 => wr_eof_in3,

            -- Leseseite: One-Hot Lesefreigabe vom RR
            rd_en => rd_en_s,

            -- Datenausgaenge
            rd_data_0 => rd_data_0_s,
            rd_data_1 => rd_data_1_s,
            rd_data_2 => rd_data_2_s,
            rd_data_3 => rd_data_3_s,

            -- Statusausgaenge
            rd_eof => rd_eof_s,
            frame_rdy => frame_rdy_s,
            full => full_s,
            empty => empty_s,
            rd_valid => out_valid
        );

    ---------------------------------------------------------------------------
    -- EOF-Multiplexer
    -- Der Round-Robin braucht das EOF-Signal des aktuell gewaehlten FIFOs,
    -- um zu wissen, wann das aktuelle Frame zu Ende geht.
    -- Der Multiplexer waehlt rd_eof(i) basierend auf rr_sel_s aus.
    ---------------------------------------------------------------------------
    WITH rr_sel_s SELECT
        eof_mux_s <= rd_eof_s(0) WHEN "00", -- rr_sel_s=0: nimm rd_eof_s(0)
        rd_eof_s(1) WHEN "01", -- rr_sel_s=1: nimm rd_eof_s(1)
        rd_eof_s(2) WHEN "10", -- rr_sel_s=2: nimm rd_eof_s(2)
        rd_eof_s(3) WHEN OTHERS; -- rr_sel_s=3: nimm rd_eof_s(3)

    ---------------------------------------------------------------------------
    -- INSTANZ: round_robin
    -- Arbiter: Waehlt reihum (Fair) welches VOQ gerade lesen darf.
    -- Input: frame_rdy_s (von den VOQs) - sagt welche VOQs Frames haben
    --        eof_mux_s (von multiplextem rd_eof) - sagt wann Frame endet
    -- Output: rr_sel_s (Index des gewaehrten VOQ)
    --         rr_grant_s (One-Hot Representation von rr_sel_s)
    --         rr_active_s ('1' wenn Grant gueltig)
    ---------------------------------------------------------------------------
    u_rr : ENTITY work.round_robin
        PORT MAP(
            clk => clk,
            reset => reset,
            frame_rdy => frame_rdy_s, -- Input: welche FIFOs haben Frames
            eof => eof_mux_s, -- Input: EOF des aktuellen Frames
            sel => rr_sel_s, -- Output: 2-Bit Index (0..3)
            grant => rr_grant_s, -- Output: One-Hot Grant
            active => rr_active_s -- Output: '1' wenn Grant aktiv
        );

    -- Der RR-Grant wird direkt als Lesefreigabe an die VOQs durchgereicht
    rd_en_s <= rr_grant_s;

    ---------------------------------------------------------------------------
    -- INSTANZ: crossbar_switch
    -- Multiplexer: Routing-Struktur mit 4 unabhaengigen 4:1 MUXen.
    -- In dieser Anwendung wird nur MUX 0 tatsaechlich benutzt.
    -- MUX 0 waehlt einen der 4 VOQ-Ausgaenge aus und sendet ihn auf Output 0.
    -- Der Select-Signal (rr_sel_s) kommt vom Round-Robin.
    ---------------------------------------------------------------------------
    u_xbar : ENTITY work.crossbar_switch
        PORT MAP(
            
            -- MUX 0: Bekommt die 4 FIFO-Datenausgaenge als Eingang
            -- Diese werden muliplexed, je nachdem welcher RR-Kanal aktiv ist
            data_m0_i0 => rd_data_0_s,
            data_m0_i1 => rd_data_1_s,
            data_m0_i2 => rd_data_2_s,
            data_m0_i3 => rd_data_3_s,

            -- MUX 1, 2, 3: unbenutzt, mit Nullen gefuettert
            data_m1_i0 => (OTHERS => '0'),
            data_m1_i1 => (OTHERS => '0'),
            data_m1_i2 => (OTHERS => '0'),
            data_m1_i3 => (OTHERS => '0'),

            data_m2_i0 => (OTHERS => '0'),
            data_m2_i1 => (OTHERS => '0'),
            data_m2_i2 => (OTHERS => '0'),
            data_m2_i3 => (OTHERS => '0'),

            data_m3_i0 => (OTHERS => '0'),
            data_m3_i1 => (OTHERS => '0'),
            data_m3_i2 => (OTHERS => '0'),
            data_m3_i3 => (OTHERS => '0'),

            -- Select-Signale
            sel_0 => rr_sel_s, -- MUX 0 wird vom RR gesteuert
            sel_1 => "00", -- MUX 1, 2, 3 unbenutzt (Select "00")
            sel_2 => "00",
            sel_3 => "00",

            -- Die Ausgaenge des Crossbar
            out_data_0 => out_data_0, -- Hauptausgang
            out_data_1 => out1_dummy, -- ungenutzt
            out_data_2 => out2_dummy, -- ungenutzt
            out_data_3 => out3_dummy -- ungenutzt
        );

    ---------------------------------------------------------------------------
    -- Debug-Ausgaenge: Kopiele interne Signale nach aussen fuer Beobachtung
    -- Diese sind hilfreich fuer Simulationen und Hardware-Debugging.
    ---------------------------------------------------------------------------
    rr_sel <= rr_sel_s;
    rr_grant <= rr_grant_s;
    rr_active <= rr_active_s;

    frame_rdy_dbg <= frame_rdy_s;
    rd_eof_dbg <= rd_eof_s;
    full_dbg <= full_s;
    empty_dbg <= empty_s;

END ARCHITECTURE rtl;