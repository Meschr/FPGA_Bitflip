-- =============================================================================
-- Modul: round_robin
-- Beschreibung:
--   Implementiert einen Round-Robin-Arbiter fuer 4 Eingangskanaele.
--   Der Arbiter beobachtet, welche der 4 Virtual-Output-Queues (VOQs) einen
--   fertigen Frame bereitstehen haben (frame_rdy). Er waehlt reihum (fair)
--   den naechsten bereiten Kanal aus, sperrt den Grant bis das Frame-Ende
--   (eof) signalisiert wird, und geht danach zum naechsten Kanal weiter.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- -----------------------------------------------------------------------------
-- Entity-Schnittstelle
-- -----------------------------------------------------------------------------
entity round_robin is
    port (
        clk       : in  std_logic;  -- Systemtakt
        reset     : in  std_logic;  -- Synchroner Reset (aktiv high)

        -- Eingang: VOQ-Status
        -- frame_rdy(i) = '1' bedeutet: Kanal i hat ein Frame bereit zum Senden
        frame_rdy : in  std_logic_vector(3 downto 0);

        -- eof = '1' fuer genau einen Takt, wenn das aktuell gesendete Frame endet
        -- (kommt aus der VOQ, signalisiert das Ende eines Frames)
        eof       : in  std_logic;

        -- Ausgaenge
        -- sel: 2-Bit-Index des aktuell gewaehrten Kanals (0-3), geht an den MUX
        sel       : out std_logic_vector(1 downto 0);

        -- grant: One-Hot-Kodierung welcher Kanal gerade Sendeerlaubnis hat,
        --        geht an die FIFOs damit das richtige FIFO ausgelesen wird
        grant     : out std_logic_vector(3 downto 0);

        -- active = '1': ein Kanal ist aktiv und der Grant ist gueltig,
        --         = '0': Arbiter sucht noch nach einem bereiten Kanal
        active    : out std_logic
    );
end entity round_robin;

-- -----------------------------------------------------------------------------
-- Architektur (RTL)
-- -----------------------------------------------------------------------------
architecture rtl of round_robin is

    -- Zustandsautomat (FSM) mit zwei Zustaenden:
    --   IDLE   -> Kein Kanal aktiv, Arbiter sucht den naechsten bereiten Eingang
    --   LOCKED -> Ein Kanal wurde gewaehlt und haelt seinen Grant bis Frame-Ende
    type state_t is (IDLE, LOCKED);

    -- Register: aktueller Zustand | naechster Zustand (berechnet im comb_proc)
    signal state_reg, state_next   : state_t;

    -- Round-Robin-Zeiger: gibt an, bei welchem Kanal die naechste Suche beginnt.
    -- Nach jedem Frame wird der Zeiger auf den Kanal nach dem zuletzt bedienten
    -- gesetzt, um Fairness sicherzustellen.
    signal rr_ptr_reg, rr_ptr_next : unsigned(1 downto 0);

    -- Ausgewaehlter Kanal (als 2-Bit-Index), wird in sel_reg gespeichert
    signal sel_reg, sel_next       : unsigned(1 downto 0);

begin

    ---------------------------------------------------------------------------
    -- 1) Sequentielle Register
    --    Alle Zustands- und Datenregister werden hier bei jeder steigenden
    --    Taktflanke aktualisiert. Bei Reset kehren alle auf den Ausgangswert.
    ---------------------------------------------------------------------------
    seq_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg  <= IDLE;          -- Startzustand: kein Kanal aktiv
                rr_ptr_reg <= (others => '0'); -- Zeiger beginnt bei Kanal 0
                sel_reg    <= (others => '0'); -- kein Kanal gewaehlt
            else
                -- Uebernahme der im Kombinatorik-Prozess berechneten Naechstwerte
                state_reg  <= state_next;
                rr_ptr_reg <= rr_ptr_next;
                sel_reg    <= sel_next;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- 2) Kombinatorische Zustandslogik (Next-State Logic)
    --    Berechnet den naechsten Zustand und die naechsten Registerwerte,
    --    abhaengig vom aktuellen Zustand und den Eingangssignalen.
    ---------------------------------------------------------------------------
    comb_proc : process(state_reg, rr_ptr_reg, sel_reg, frame_rdy, eof)
        variable found_v : boolean;            -- Wurde ein bereiter Kanal gefunden?
        variable idx_v   : integer range 0 to 3; -- Laufender Kandidatenindex (0-3)
        variable cand_v  : unsigned(1 downto 0); -- Ausgewaehlter Kandidat
    begin
        -- Standardmaessig: Werte unveraendert halten (keine ungewollten Latches)
        state_next  <= state_reg;
        rr_ptr_next <= rr_ptr_reg;
        sel_next    <= sel_reg;

        case state_reg is

            -------------------------------------------------------------------
            -- Zustand IDLE: Suche nach dem naechsten bereiten Eingangskanal
            --
            -- Startpunkt der Suche ist rr_ptr_reg (letzter Gewinner + 1).
            -- Es werden alle 4 Kanaele der Reihe nach geprueft (Round-Robin).
            -- Der erste gefundene bereite Kanal wird ausgewaehlt.
            -------------------------------------------------------------------
            when IDLE =>
                found_v := false;
                cand_v  := rr_ptr_reg; -- Voreinstellung: aktueller Zeiger

                -- Schleife ueber alle 4 Kanaele, beginnend beim rr_ptr_reg
                -- (k=0 -> rr_ptr, k=1 -> rr_ptr+1, ..., modulo 4 fuer Wraparound)
                for k in 0 to 3 loop
                    idx_v := (to_integer(rr_ptr_reg) + k) mod 4;

                    -- Nur den ersten Treffer merken (not found_v verhindert Ueberschreiben)
                    if (not found_v) and (frame_rdy(idx_v) = '1') then
                        cand_v  := to_unsigned(idx_v, 2); -- Kandidaten speichern
                        found_v := true;                  -- Suche abgeschlossen
                    end if;
                end loop;

                -- Wurde ein bereiter Kanal gefunden -> Grant vergeben und sperren
                if found_v then
                    sel_next   <= cand_v;   -- Ausgewaehlten Kanal speichern
                    state_next <= LOCKED;   -- Wechsel in LOCKED-Zustand
                end if;
                -- Kein bereiter Kanal -> IDLE bleibt, naechsten Takt erneut suchen

            -------------------------------------------------------------------
            -- Zustand LOCKED: Grant halten bis das aktuelle Frame endet
            --
            -- Der gewaehlte Kanal (sel_reg) behielt seinen Grant.
            -- Sobald eof = '1' signalisiert wird (Frame-Ende), wird der
            -- Round-Robin-Zeiger auf den naechsten Kanal weitergeschoben
            -- und der Arbiter wechselt zurueck nach IDLE.
            -------------------------------------------------------------------
            when LOCKED =>
                if eof = '1' then
                    -- Zeiger auf naechsten Kanal setzen (mod 4 durch 2-Bit-Ueberlauf)
                    rr_ptr_next <= sel_reg + 1;
                    state_next  <= IDLE;    -- Naechsten Kanal suchen
                end if;
                -- eof = '0' -> Grant bleibt unveraendert (Frame laeuft noch)

        end case;
    end process;

    ---------------------------------------------------------------------------
    -- 3) Ausgangslogik
    --
    --    sel:    Gibt den 2-Bit-Index des aktuell aktiven Kanals an den MUX.
    --    active: Zeigt an ob der Grant gueltig ist (nur im LOCKED-Zustand).
    --    grant:  One-Hot-Signal fuer die FIFOs: genau das FIFO, das gerade
    --            lesen darf, bekommt eine '1'.
    ---------------------------------------------------------------------------
    -- MUX-Steuerung: immer der aktuell gespeicherte Kanalindex
    sel    <= std_logic_vector(sel_reg);

    -- active ist genau dann '1', wenn ein Kanal einen gueltigen Grant haelt
    active <= '1' when state_reg = LOCKED else '0';

    -- Grant-Dekodierung: Umwandlung des 2-Bit-Index in One-Hot fuer die FIFOs
    grant_proc : process(state_reg, sel_reg)
    begin
        grant <= "0000"; -- Standard: kein Grant (IDLE oder Reset)

        if state_reg = LOCKED then
            -- Nur im LOCKED-Zustand wird ein Grant-Bit gesetzt
            case sel_reg is
                when "00"   => grant <= "0001"; -- Kanal 0 hat Grant
                when "01"   => grant <= "0010"; -- Kanal 1 hat Grant
                when "10"   => grant <= "0100"; -- Kanal 2 hat Grant
                when others => grant <= "1000"; -- Kanal 3 hat Grant
            end case;
        end if;
    end process;

end architecture rtl;