-- =============================================================================
-- Modul: round_robin
-- Beschreibung:
--   Implementiert einen Round-Robin-Arbiter fuer 4 Eingangskanaele.
--   Der Arbiter beobachtet, welche der 4 Virtual-Output-Queues (VOQs) einen
--   fertigen Frame bereitstehen haben (frame_rdy). Er waehlt reihum (fair)
--   den naechsten bereiten Kanal aus, sperrt den Grant bis das Frame-Ende
--   (eof) signalisiert wird, und geht danach zum naechsten Kanal weiter.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- -----------------------------------------------------------------------------
-- Entity-Schnittstelle
-- -----------------------------------------------------------------------------
ENTITY round_robin IS
    PORT (
        clk : IN STD_LOGIC; -- Systemtakt
        reset : IN STD_LOGIC; -- Synchroner Reset (aktiv high)

        -- Eingang: VOQ-Status
        -- frame_rdy(i) = '1' bedeutet: Kanal i hat ein Frame bereit zum Senden
        frame_rdy : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

        -- eof = '1' fuer genau einen Takt, wenn das aktuell gesendete Frame endet
        -- (kommt aus der VOQ, signalisiert das Ende eines Frames)
        eof : IN STD_LOGIC;

        -- Ausgaenge
        -- sel: 2-Bit-Index des aktuell gewaehrten Kanals (0-3), geht an den MUX
        sel : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);

        -- grant: One-Hot-Kodierung welcher Kanal gerade Sendeerlaubnis hat,
        --        geht an die FIFOs damit das richtige FIFO ausgelesen wird
        grant : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

        -- active = '1': ein Kanal ist aktiv und der Grant ist gueltig,
        --         = '0': Arbiter sucht noch nach einem bereiten Kanal
        active : OUT STD_LOGIC
    );
END ENTITY round_robin;

-- -----------------------------------------------------------------------------
-- Architektur (RTL)
-- -----------------------------------------------------------------------------
ARCHITECTURE rtl OF round_robin IS

    -- Zustandsautomat (FSM) mit zwei Zustaenden:
    --   IDLE   -> Kein Kanal aktiv, Arbiter sucht den naechsten bereiten Eingang
    --   LOCKED -> Ein Kanal wurde gewaehlt und haelt seinen Grant bis Frame-Ende
    TYPE state_t IS (IDLE, LOCKED);

    -- Register: aktueller Zustand | naechster Zustand (berechnet im comb_proc)
    SIGNAL state_reg, state_next : state_t;

    -- Round-Robin-Zeiger: gibt an, bei welchem Kanal die naechste Suche beginnt.
    -- Nach jedem Frame wird der Zeiger auf den Kanal nach dem zuletzt bedienten
    -- gesetzt, um Fairness sicherzustellen.
    SIGNAL rr_ptr_reg, rr_ptr_next : unsigned(1 DOWNTO 0);

    -- Ausgewaehlter Kanal (als 2-Bit-Index), wird in sel_reg gespeichert
    SIGNAL sel_reg, sel_next : unsigned(1 DOWNTO 0);

BEGIN

    ---------------------------------------------------------------------------
    -- 1) Sequentielle Register
    --    Alle Zustands- und Datenregister werden hier bei jeder steigenden
    --    Taktflanke aktualisiert. Bei Reset kehren alle auf den Ausgangswert.
    ---------------------------------------------------------------------------
    seq_proc : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                state_reg <= IDLE; -- Startzustand: kein Kanal aktiv
                rr_ptr_reg <= (OTHERS => '0'); -- Zeiger beginnt bei Kanal 0
                sel_reg <= (OTHERS => '0'); -- kein Kanal gewaehlt
            ELSE
                -- Uebernahme der im Kombinatorik-Prozess berechneten Naechstwerte
                state_reg <= state_next;
                rr_ptr_reg <= rr_ptr_next;
                sel_reg <= sel_next;
            END IF;
        END IF;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- 2) Kombinatorische Zustandslogik (Next-State Logic)
    --    Berechnet den naechsten Zustand und die naechsten Registerwerte,
    --    abhaengig vom aktuellen Zustand und den Eingangssignalen.
    ---------------------------------------------------------------------------
    comb_proc : PROCESS (state_reg, rr_ptr_reg, sel_reg, frame_rdy, eof)
        VARIABLE found_v : BOOLEAN; -- Wurde ein bereiter Kanal gefunden?
        VARIABLE idx_v : INTEGER RANGE 0 TO 3; -- Laufender Kandidatenindex (0-3)
        VARIABLE cand_v : unsigned(1 DOWNTO 0); -- Ausgewaehlter Kandidat
    BEGIN
        -- Standardmaessig: Werte unveraendert halten (keine ungewollten Latches)
        state_next <= state_reg;
        rr_ptr_next <= rr_ptr_reg;
        sel_next <= sel_reg;

        CASE state_reg IS

                -------------------------------------------------------------------
                -- Zustand IDLE: Suche nach dem naechsten bereiten Eingangskanal
                --
                -- Startpunkt der Suche ist rr_ptr_reg (letzter Gewinner + 1).
                -- Es werden alle 4 Kanaele der Reihe nach geprueft (Round-Robin).
                -- Der erste gefundene bereite Kanal wird ausgewaehlt.
                -------------------------------------------------------------------
            WHEN IDLE =>
                found_v := false;
                cand_v := rr_ptr_reg; -- Voreinstellung: aktueller Zeiger

                -- Schleife ueber alle 4 Kanaele, beginnend beim rr_ptr_reg
                -- (k=0 -> rr_ptr, k=1 -> rr_ptr+1, ..., modulo 4 fuer Wraparound)
                FOR k IN 0 TO 3 LOOP
                    idx_v := (to_integer(rr_ptr_reg) + k) MOD 4;

                    -- Nur den ersten Treffer merken (not found_v verhindert Ueberschreiben)
                    IF (NOT found_v) AND (frame_rdy(idx_v) = '1') THEN
                        cand_v := to_unsigned(idx_v, 2); -- Kandidaten speichern
                        found_v := true; -- Suche abgeschlossen
                    END IF;
                END LOOP;

                -- Wurde ein bereiter Kanal gefunden -> Grant vergeben und sperren
                IF found_v THEN
                    sel_next <= cand_v; -- Ausgewaehlten Kanal speichern
                    state_next <= LOCKED; -- Wechsel in LOCKED-Zustand
                END IF;
                -- Kein bereiter Kanal -> IDLE bleibt, naechsten Takt erneut suchen

                -------------------------------------------------------------------
                -- Zustand LOCKED: Grant halten bis das aktuelle Frame endet
                --
                -- Der gewaehlte Kanal (sel_reg) behielt seinen Grant.
                -- Sobald eof = '1' signalisiert wird (Frame-Ende), wird der
                -- Round-Robin-Zeiger auf den naechsten Kanal weitergeschoben
                -- und der Arbiter wechselt zurueck nach IDLE.
                -------------------------------------------------------------------
            WHEN LOCKED =>
                IF eof = '1' THEN
                    -- Zeiger auf naechsten Kanal setzen (mod 4 durch 2-Bit-Ueberlauf)
                    rr_ptr_next <= sel_reg + 1;
                    state_next <= IDLE; -- Naechsten Kanal suchen
                END IF;
                -- eof = '0' -> Grant bleibt unveraendert (Frame laeuft noch)

        END CASE;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- 3) Ausgangslogik
    --
    --    sel:    Gibt den 2-Bit-Index des aktuell aktiven Kanals an den MUX.
    --    active: Zeigt an ob der Grant gueltig ist (nur im LOCKED-Zustand).
    --    grant:  One-Hot-Signal fuer die FIFOs: genau das FIFO, das gerade
    --            lesen darf, bekommt eine '1'.
    ---------------------------------------------------------------------------
    -- MUX-Steuerung: immer der aktuell gespeicherte Kanalindex
    sel <= STD_LOGIC_VECTOR(sel_reg);

    -- active ist genau dann '1', wenn ein Kanal einen gueltigen Grant haelt
    active <= '1' WHEN state_reg = LOCKED ELSE
        '0';

    -- Grant-Dekodierung: Umwandlung des 2-Bit-Index in One-Hot fuer die FIFOs
    grant_proc : PROCESS (state_reg, sel_reg)
    BEGIN
        grant <= "0000"; -- Standard: kein Grant (IDLE oder Reset)

        IF state_reg = LOCKED THEN
            -- Nur im LOCKED-Zustand wird ein Grant-Bit gesetzt
            CASE sel_reg IS
                WHEN "00" => grant <= "0001"; -- Kanal 0 hat Grant
                WHEN "01" => grant <= "0010"; -- Kanal 1 hat Grant
                WHEN "10" => grant <= "0100"; -- Kanal 2 hat Grant
                WHEN OTHERS => grant <= "1000"; -- Kanal 3 hat Grant
            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;