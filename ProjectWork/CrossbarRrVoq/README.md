# 4-Port Gigabit Ethernet Switch — FPGA Design

**Kurs:** FPGA Design for Communications Systems  
**Institution:** DTU Fotonik, Technical University of Denmark  
**Sprache:** VHDL  
**Zielplattform:** FPGA (Zynq / UltraScale+)

---

## 1. Projektübersicht

Entwurf eines 4-Port Gigabit Ethernet Switch Core in VHDL. Der Switch empfängt Ethernet-Frames über 4 Eingangsports, leitet sie anhand der MAC-Adressen an den korrekten Ausgangsport weiter und verwirft fehlerhafte Frames. Die gesamte Verarbeitung erfolgt synchron bei 125 MHz (8 Bit parallel = 1 Gbit/s pro Port).

---

## 2. Anforderungen (Pflichtenheft)

| Anforderung | Spezifikation |
|---|---|
| Anzahl Ports | 4 Eingangs- und 4 Ausgangsports |
| Datenrate | 1000 Mbit/s pro Port (Gigabit Ethernet) |
| Interface | GMII — 8 Bit parallel, 125 MHz Takt |
| Frame-Größen | 64 Byte bis 1518 Byte (exkl. Preamble und IFG) |
| MAC-Adressen | 8192 (8k) Einträge in der MAC-Tabelle |
| Blocking | Non-blocking (kein Eingang wird dauerhaft blockiert) |
| Frame-Reihenfolge | Keine Umordnung von Frames des gleichen Flows |
| Fehlerhafte Frames | Erkennung via CRC-32, sofortiges Verwerfen |
| Taktdomäne | Single-Clock Design, 125 MHz |

---

## 3. Ethernet Frame Format (IEEE 802.3)

```
+-----------+-----+----------+----------+-----------+--------------+-----+-----+
| Preamble  | SFD |   DMAC   |   SMAC   | EtherType |   Payload    | FCS | IFG |
| 7 Bytes   | 1B  | 6 Bytes  | 6 Bytes  |  2 Bytes  | 46-1500 B    | 4B  | 12B |
+-----------+-----+----------+----------+-----------+--------------+-----+-----+
                   |<------------- 64 bis 1518 Bytes ------------->|
```

**Felder im Detail:**

- **Preamble (7 Bytes):** Synchronisationsmuster 10101010, wird von der physikalischen Schicht verarbeitet (nicht Teil unseres Designs).
- **SFD (1 Byte):** Start-of-Frame Delimiter 10101011, markiert den Beginn des Frames.
- **DMAC (6 Bytes):** Ziel-MAC-Adresse — wird für den MAC-Tabellen-Lookup verwendet um den Ausgangsport zu bestimmen.
- **SMAC (6 Bytes):** Quell-MAC-Adresse — wird gelernt und in der MAC-Tabelle mit dem Eingangsport gespeichert.
- **EtherType/Length (2 Bytes):** Gibt den Payload-Typ an (z.B. 0x0800 = IPv4).
- **Payload (46–1500 Bytes):** Nutzdaten des höheren Protokolls. Minimum 46 Bytes (ggf. mit Padding aufgefüllt).
- **FCS (4 Bytes):** CRC-32 Frame Check Sum — wird über DMAC+SMAC+EtherType+Payload berechnet.
- **IFG (12 Bytes):** Interframe Gap — Pause zwischen Frames, wird von der physikalischen Schicht eingefügt.

---

## 4. Architektur

### 4.1 Pipeline-Übersicht

Der Datenfluss pro Eingangsport verläuft in folgender Reihenfolge:

```
Rx (GMII) → FCS-Check + Puffer → MAC-Learning → VOQ → RR + Crossbar-MUX → Tx (GMII)
```

Jede Stufe hat eine klare Aufgabe und definierte Signale zu den Nachbarstufen.

### 4.2 Modulübersicht

| Modul | Datei | Funktion | Status |
|---|---|---|---|
| Crossbar-MUX | `crossbar_switch.vhd` | 4× unabhängige 4:1 MUX (with...select) | Fertig, getestet |
| Round-Robin | `round_robin.vhd` | 4× Arbiter mit Frame-Lock (FSM: IDLE/LOCKED) | Fertig, getestet |
| VOQ-FIFO | `voq_fifo.vhd` | Generischer Store-and-Forward FIFO, frame_rdy, flush, rd_valid | Fertig, getestet |
| VOQ 4:1 | `voq_4to1.vhd` | 4 VOQ-FIFOs für einen Ausgangsport gebündelt | Fertig, getestet |
| VOQ+RR+Crossbar | `voq_rr_crossbar_top.vhd` | Single-Output Top-Level: VOQ + RR + Crossbar verdrahtet | Fertig, getestet |
| FCS-Block | `fcs_check.vhd` | CRC-32 Berechnung + Frame-Puffer, nur gute Frames weiter | Ausstehend |
| MAC-Learning | `mac_table.vhd` | SMAC lernen, DMAC nachschlagen, dest_port bestimmen | Ausstehend |
| Top-Level (4-Port) | `switch_core.vhd` | Vollständige Verdrahtung aller 4 Ports, Top-Level Entity | Ausstehend |

### 4.3 Top-Level Interface

```
                    Switch Core
                 ┌──────────────────┐
   Rx0  8 ──────►│                  │──────► 8  Tx0
   Rx1  8 ──────►│                  │──────► 8  Tx1
   Rx2  8 ──────►│                  │──────► 8  Tx2
   Rx3  8 ──────►│                  │──────► 8  Tx3
                 │                  │
    Rx_ctrl 1 ──►│                  │──────► 1  Tx_ctrl
                 │                  │
    Clk   1 ────►│                  │
    Reset 1 ────►│                  │
                 └──────────────────┘
```

**Port-Beschreibung:**

- `Rx0..Rx3` (in, 8 Bit): Empfangsdaten der 4 Eingangsports (GMII)
- `Rx_ctrl` (in, 1 Bit): Gültigkeitssignal für Empfangsdaten
- `Tx0..Tx3` (out, 8 Bit): Sendedaten der 4 Ausgangsports
- `Tx_ctrl` (out, 1 Bit): Gültigkeitssignal für Sendedaten
- `Clk` (in): 125 MHz Systemtakt
- `Reset` (in): Synchroner Reset (active high)

---

## 5. Modulbeschreibung

### 5.1 Crossbar-MUX (`crossbar_switch.vhd`)

**Funktion:** 4 unabhängige 4:1 Multiplexer. Jeder Ausgangsport hat seinen eigenen MUX, der aus den 4 VOQ-Spalten-Eingängen wählt.

**Implementierung:** `with...select` (concurrent MUX, kein Process für die Auswahl). Registered outputs über einen separaten Process für sauberes Timing.

**Signale:**

| Signal | Richtung | Breite | Beschreibung |
|---|---|---|---|
| `data_mN_iX` | in | 8 Bit | Daten von Input X für Destination N |
| `sel_N` | in | 2 Bit | Select-Signal für MUX N (von Round-Robin) |
| `out_data_N` | out | 8 Bit | Ausgangsdaten für Tx-Port N |

**Latenz:** 1 Taktzyklus (8 ns bei 125 MHz)

**Ressourcen:** ca. 9 LUT6 pro MUX (8 für Daten + 1 für Valid), gesamt ca. 36 LUTs.

**Testbench:** `tb_crossbar_switch.vhd` — Tests: Reset, Straight-through, Reverse, Broadcast, dynamische Umschaltung, Datenänderung.

### 5.2 Round-Robin Arbiter (`round_robin.vhd`)

**Funktion:** Fair-Scheduling für einen Ausgangs-MUX. Wählt unter den VOQs mit bereiten Frames aus und bleibt auf dem gewählten Eingang gelockt bis der Frame komplett übertragen ist.

**Implementierung:** Zwei-Zustands-FSM (IDLE / LOCKED) mit verschachteltem `case`/`if-elsif` für die Prioritätssuche ab `rr_ptr`.

**Zustandsmaschine:**

```
        frame_rdy /= "0000"
  IDLE ──────────────────────► LOCKED
   ▲                              │
   │         eof = '1'            │
   │     ptr = winner + 1         │
   └──────────────────────────────┘
```

- **IDLE:** Kein Frame aktiv. Sucht nächsten Eingang mit `frame_rdy` ab `rr_ptr` im Round-Robin. Bei Fund: Grant setzen, `sel` ausgeben, nach LOCKED wechseln.
- **LOCKED:** Frame wird übertragen. `sel` und `grant` bleiben stabil. Bei `eof`: Pointer auf winner+1 setzen, zurück zu IDLE.

**Signale:**

| Signal | Richtung | Breite | Beschreibung |
|---|---|---|---|
| `frame_rdy` | in | 4 Bit | Welche VOQs einen fertigen Frame haben |
| `eof` | in | 1 Bit | Letztes Byte des aktuellen Frames |
| `sel` | out | 2 Bit | MUX-Select (an Crossbar) |
| `grant` | out | 4 Bit | One-hot Grant (an VOQ, für Dequeue) |
| `active` | out | 1 Bit | Frame wird gerade übertragen |

**Instanziierung:** 4× — eine Instanz pro Ausgangsport.

**Testbench:** `tb_round_robin.vhd` — Tests: Reset, Einzelanfrage, Frame-Lock über mehrere Takte, EOF-Behandlung, Rotation (0→1→2→3→0), Idle ohne Anfrage, Überspringen leerer Eingänge.

### 5.3 VOQ-FIFO (`voq_fifo.vhd`) — Fertig

**Funktion:** Generischer Store-and-Forward FIFO für eine einzelne VOQ. Speichert komplette Frames (erkannt durch EOF-Flag) und signalisiert über `frame_rdy`, wenn mindestens ein vollständiger Frame vorliegt.

**Merkmale:**

- FIFO-Tiefe: generisch (`DEPTH`, Standard 4096 Bytes) — passt mehrere maximale Ethernet-Frames
- Speicherformat: 9 Bit pro Eintrag (8 Bit Daten + 1 Bit EOF-Flag)
- Dual-Port: gleichzeitiges Lesen und Schreiben möglich
- `flush`: logische Leerung des FIFOs ohne Hardware-Reset
- `rd_valid`: signalisiert, ob die Leseausgänge gültige Daten enthalten
- Frame-Zähler: zählt fertige Frames (`frames_stored`) für das `frame_rdy`-Signal

**Signale:**

| Signal | Richtung | Breite | Beschreibung |
|---|---|---|---|
| `wr_en` / `wr_data` / `wr_eof` | in | 1 / 8 / 1 Bit | Schreibseite mit EOF-Markierung |
| `rd_en` / `rd_data` / `rd_eof` | in/out | 1 / 8 / 1 Bit | Leseseite synchron |
| `rd_valid` | out | 1 Bit | Gültigkeitsbit für Lesedaten |
| `frame_rdy` | out | 1 Bit | Mindestens ein kompletter Frame im FIFO |
| `flush` | in | 1 Bit | Logische Leerung (Pointer + Zähler auf 0) |
| `full` / `empty` | out | 1 Bit | Statusflags |

**Testbench:** `tb_voq_fifo.vhd` — Tests: Reset, Frame schreiben/lesen, frame_rdy nach EOF, zwei Frames hintereinander, gleichzeitiges Lesen/Schreiben, Full-Signal.

### 5.4 VOQ 4:1 (`voq_4to1.vhd`) — Fertig

**Funktion:** Bündelt 4 `voq_fifo`-Instanzen für einen gemeinsamen Ausgangsport. Jeder Eingangsport hat sein eigenes FIFO — das ist die Kerndatenstruktur der VOQ-Architektur.

**Struktur:**

```
Eingang 0 ──► FIFO 0 ──► rd_data_0
Eingang 1 ──► FIFO 1 ──► rd_data_1   (alle für denselben Zielport)
Eingang 2 ──► FIFO 2 ──► rd_data_2
Eingang 3 ──► FIFO 3 ──► rd_data_3
```

**Signale:** Schreibseite je 3 Signale pro Eingang (`wr_en`, `wr_data`, `wr_eof`), Leseseite gesteuert über `rd_en(3:0)` (One-Hot vom Round-Robin). `frame_rdy(3:0)` geht zurück an den Round-Robin-Arbiter.

### 5.5 VOQ+RR+Crossbar Top-Level (`voq_rr_crossbar_top.vhd`) — Fertig (Single-Output)

**Funktion:** Verdrahtet `voq_4to1`, `round_robin` und `crossbar_switch` zu einem funktionsfähigen Single-Output-Switch-Kern. Implementiert die vollständige Datenpfad-Pipeline für einen Ausgangsport.

**Blockdiagramm:**

```
Eingang 0..3 ──► voq_4to1 ──► rd_data_0..3 ──► crossbar_switch ──► out_data_0
                     │                               ▲
                  frame_rdy ──► round_robin ─── rr_sel_s
                     │               ▲
                  rd_eof ──► eof_mux_s
```

**Signale:**

| Signal | Richtung | Beschreibung |
|---|---|---|
| `wr_data_inX` / `wr_en_inX` / `wr_eof_inX` | in | Schreibseite der 4 VOQs |
| `flush` | in | 4-Bit Flush-Signal pro FIFO |
| `out_data_0` | out | Gemultiplextes Ausgabedatum |
| `out_valid` | out | Gültigkeitssignal des Ausgangs |
| `rr_sel` / `rr_grant` / `rr_active` | out | Debug: RR-Status |
| `frame_rdy_dbg` / `rd_eof_dbg` / `full_dbg` / `empty_dbg` | out | Debug: FIFO-Status |

**Hinweis:** Aktuell wird nur MUX 0 des Crossbar genutzt. Für den vollständigen 4-Port-Switch wird `switch_core.vhd` 4 solche Pfade instanziieren.

**Testbench:** `tb_voq_rr_crossbar.vhd`

### 5.6 FCS-Block (`fcs_check.vhd`) — Ausstehend

**Funktion:** CRC-32 Berechnung und Frame-Validierung. Enthält einen internen Puffer der den Frame zwischenspeichert während die CRC laufend berechnet wird.

**Geplanter Ablauf:**

1. Frame kommt Byte für Byte über GMII rein
2. Jedes Byte wird im internen Puffer gespeichert UND in die CRC-Berechnung eingespeist
3. Parallel liest MAC-Learning die Header-Bytes (DMAC, SMAC) aus
4. Am Frame-Ende steht das CRC-Ergebnis fest:
   - CRC OK: Frame wird aus dem Puffer in die richtige VOQ kopiert (dest_port ist durch MAC-Learning bereits bekannt)
   - CRC Fehler: Puffer-Schreibzeiger wird zurückgesetzt, Frame verworfen

**CRC-32 Polynom:** 0x04C11DB7 (IEEE 802.3 Standard)

### 5.7 MAC-Learning (`mac_table.vhd`) — Ausstehend

**Funktion:** Lernt Quell-MAC-Adressen und schlägt Ziel-MAC-Adressen in einer Tabelle nach.

**Geplante Merkmale:**

- MAC-Tabelle mit 8192 Einträgen (8k, wie gefordert)
- Hash-basierter Lookup (MAC-Adresse → Port-Nummer)
- SMAC-Learning: Eingangsport wird zur Quell-MAC gespeichert
- DMAC-Lookup: Ziel-Port wird nachgeschlagen
- Unbekannte DMAC: Frame wird an alle Ports geflutet (Broadcast)
- Aging: Veraltete Einträge werden nach Timeout gelöscht

---

## 6. Designentscheidungen

### 6.1 Warum VOQ statt Input- oder Output-Queuing?

**Input-Queuing** leidet unter Head-of-Line (HOL) Blocking: wenn der vorderste Frame in der Queue blockiert ist (Zielport besetzt), stehen alle dahinter ebenfalls, auch wenn ihre Zielports frei sind. Das begrenzt den Durchsatz auf ca. 58,6%.

**Output-Queuing** vermeidet HOL-Blocking, erfordert aber dass die Ausgangsqueues mit N-facher Geschwindigkeit beschrieben werden können (bei 4 Ports: 4× Taktrate). Das ist auf FPGAs schwer realisierbar.

**Virtual Output Queuing (VOQ)** kombiniert die Vorteile: pro Eingang gibt es separate Queues für jedes Ziel (4×4 = 16 FIFOs). Damit wird HOL-Blocking eliminiert, ohne Speedup zu benötigen. Der Scheduling-Algorithmus (Round-Robin) entscheidet fair welcher Eingang zum Zug kommt.

### 6.2 Warum Round-Robin?

Round-Robin ist einfach, fair und deterministisch. Jeder Eingang kommt garantiert dran (kein Starvation). Die Implementierung als FSM mit Frame-Lock benötigt minimal Logik auf dem FPGA. Für einen 4-Port Switch ist die Leistung von Round-Robin ausreichend.

### 6.3 Warum Store-and-Forward?

**Cut-Through** wäre schneller (geringere Latenz), hat aber Nachteile: fehlerhafte Frames werden weitergeleitet, und die Ziel-Adresse muss im laufenden Betrieb ausgewertet werden. **Store-and-Forward** erlaubt die CRC-Prüfung vor der Weiterleitung und kennt den Zielport bevor der Frame in die VOQ geschrieben wird.

### 6.4 FCS-Check vor den VOQs

Der FCS-Block puffert den Frame und prüft die CRC. Parallel läuft MAC-Learning. Erst bei CRC-OK und bekanntem Zielport wird der Frame in die korrekte VOQ geschrieben. Das spart VOQ-Speicher (keine kaputten Frames) und vereinfacht die Logik.

---

## 7. Taktung und Timing

| Parameter | Wert |
|---|---|
| Systemtakt | 125 MHz |
| Taktperiode | 8 ns |
| Datenbreite | 8 Bit (GMII) |
| Durchsatz pro Port | 1 Gbit/s |
| Gesamtdurchsatz | 4 Gbit/s (4 Ports × 1 Gbit/s) |
| Crossbar-Latenz | 1 Takt (8 ns) |
| Taktdomäne | Single-Clock (kein CDC nötig) |

---

## 8. Ressourcenschätzung

| Modul | LUTs (geschätzt) | FFs (geschätzt) | BRAM |
|---|---|---|---|
| 4× Crossbar-MUX | ~36 | ~36 | 0 |
| 4× Round-Robin | ~60 | ~20 | 0 |
| 16× voq_fifo (via voq_4to1) | ~200 | ~100 | 16 (je 4096B) |
| 4× FCS-Check | ~400 | ~200 | 4 (Puffer) |
| MAC-Tabelle | ~500 | ~200 | 4-8 (8k Einträge) |
| Gesamt | ~1200 | ~560 | ~24-28 |

Diese Schätzungen sind konservativ. Ein modernes FPGA (z.B. Zynq ZU3EG) hat ca. 70.000 LUTs und 140 BRAMs — das Design passt problemlos.

---

## 9. Dateistruktur

```
project/
├── README.md                        ← diese Datei
├── src/
│   ├── crossbar_switch.vhd          ← 4×4 Crossbar-MUX (fertig)
│   ├── round_robin.vhd              ← Round-Robin Arbiter (fertig)
│   ├── voq_fifo.vhd                 ← Generischer VOQ-FIFO, Store-and-Forward (fertig)
│   ├── voq_4to1.vhd                 ← 4 VOQ-FIFOs für einen Ausgangsport (fertig)
│   ├── voq_rr_crossbar_top.vhd      ← VOQ+RR+Crossbar Single-Output Top-Level (fertig)
│   ├── fcs_check.vhd                ← FCS/CRC-32 Block (ausstehend)
│   ├── mac_table.vhd                ← MAC-Learning (ausstehend)
│   └── switch_core.vhd              ← Vollständiges 4-Port Top-Level (ausstehend)
├── tb/
│   ├── tb_crossbar_switch.vhd       ← Testbench Crossbar (fertig)
│   ├── tb_round_robin.vhd           ← Testbench Round-Robin (fertig)
│   ├── tb_round_robin_gpt.vhd       ← Alternative RR-Testbench
│   ├── tb_round_robin_allreq_gpt.vhd← RR-Fairness-Test: alle Eingänge gleichzeitig
│   ├── tb_voq_fifo.vhd              ← Testbench VOQ-FIFO (fertig)
│   ├── tb_voq_fifo_gpt.vhd          ← Alternative VOQ-FIFO-Testbench
│   ├── tb_voq_rr_crossbar.vhd       ← Testbench VOQ+RR+Crossbar Top-Level (fertig)
│   ├── tb_fcs_check.vhd             ← Testbench FCS (ausstehend)
│   ├── tb_mac_table.vhd             ← Testbench MAC (ausstehend)
│   └── tb_switch_core.vhd           ← Testbench vollständiger Switch (ausstehend)
└── doc/
    ├── Architecture_final.pdf       ← Referenz-Paper
    ├── fpga20pp.pdf                 ← FPGA Switch Paper
    └── Gigabit_Ethernet_Switch_2.pdf← Aufgabenstellung
```

---

## 10. Simulationsanleitung

### ModelSim / Questa

```tcl
vlib work
vcom src/crossbar_switch.vhd
vcom tb/tb_crossbar_switch.vhd
vsim tb_crossbar_switch
run -all
```

VOQ-FIFO testen:
```tcl
vlib work
vcom src/voq_fifo.vhd
vcom tb/tb_voq_fifo.vhd
vsim tb_voq_fifo
run -all
```

VOQ+RR+Crossbar Top-Level testen:
```tcl
vlib work
vcom src/crossbar_switch.vhd
vcom src/round_robin.vhd
vcom src/voq_fifo.vhd
vcom src/voq_4to1.vhd
vcom src/voq_rr_crossbar_top.vhd
vcom tb/tb_voq_rr_crossbar.vhd
vsim tb_voq_rr_crossbar
run -all
```

### GHDL

```bash
ghdl -a src/crossbar_switch.vhd
ghdl -a src/round_robin.vhd
ghdl -a src/voq_fifo.vhd
ghdl -a src/voq_4to1.vhd
ghdl -a src/voq_rr_crossbar_top.vhd
ghdl -a tb/tb_voq_rr_crossbar.vhd
ghdl -e tb_voq_rr_crossbar
ghdl -r tb_voq_rr_crossbar --wave=voq_rr.ghw
gtkwave voq_rr.ghw
```

---

## 11. Offene Punkte und nächste Schritte

1. ~~**VOQ-FIFOs implementieren**~~ — Erledigt: `voq_fifo.vhd` + `voq_4to1.vhd`, Store-and-Forward mit frame_rdy, flush, rd_valid
2. ~~**RR + Crossbar verdrahten**~~ — Erledigt für einen Ausgangsport: `voq_rr_crossbar_top.vhd`
3. **4-Port Top-Level verdrahten** — 4× `voq_rr_crossbar_top` (oder äquivalente Struktur) in `switch_core.vhd` zusammenstecken
4. **FCS-Block implementieren** — CRC-32 Berechnung mit internem Frame-Puffer
5. **MAC-Learning implementieren** — Hash-Tabelle mit 8k Einträgen, SMAC/DMAC Verarbeitung
6. **Integrations-Testbench** — Komplette Frames durch alle 4 Ports schicken
7. **Broadcast/Unknown-DMAC** — Frame an alle Ausgangsports wenn DMAC unbekannt
8. **Aging-Mechanismus** — Veraltete MAC-Einträge automatisch löschen
9. **Timing-Analyse** — Synthese und Place&Route um 125 MHz Timing zu verifizieren

---

## 12. Referenzen

- IEEE 802.3 Ethernet Standard
- DTU Fotonik: Gigabit Ethernet Switch — Projektbeschreibung
- Papaphilippou, Meng, Luk: "High-Performance FPGA Network Switch Architecture" (FPGA '20)
- McKeown: "The iSLIP Scheduling Algorithm for Input-Queued Switches" (1999)
- Surf-VHDL: How to implement a digital MUX in VHDL (https://surf-vhdl.com)
