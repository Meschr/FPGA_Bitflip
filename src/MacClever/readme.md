# CRC16-Hashing für die MAC-Table
 
## Inhaltsverzeichnis
 
1. [Überblick](#überblick)
2. [Was ist CRC?](#was-ist-crc)
3. [Mathematische Grundlage: Polynomdivision in GF(2)](#mathematische-grundlage)
4. [Das Generatorpolynom 0x8005](#das-generatorpolynom-0x8005)
5. [Der Algorithmus Schritt für Schritt](#der-algorithmus-schritt-für-schritt)
6. [Visualisiertes Beispiel](#visualisiertes-beispiel)
7. [Warum CRC gut als Hash-Funktion ist](#warum-crc-gut-als-hash-funktion-ist)
8. [Die 13-Bit-Extraktion](#die-13-bit-extraktion)
9. [Kollisionswahrscheinlichkeit](#kollisionswahrscheinlichkeit)
10. [VHDL-Implementierung](#vhdl-implementierung)

---
 
## Überblick
 
In dieser Implementierung eines 4-Port-Gigabit-Switches müssen bis zu **8000 MAC-Adressen** gespeichert werden. Dafür wird eine Hash-basierte Architektur mit Block-RAM (BRAM) verwendet. Der Hash-Algorithmus bestimmt, an welcher Stelle im Speicher eine MAC-Adresse abgelegt wird.
 
```
MAC-Adresse (48 Bit)
       │
       ▼
  CRC16-Hash
  (Polynom 0x8005, Init 0xFFFF)
       │
       ▼
  13-Bit-Index  →  Bucket 0 .. 8191
       │
       ▼
  4 Slots pro Bucket  →  bis zu 32768 Einträge möglich
```
 
---
 
## Was ist CRC?
 
CRC (*Cyclic Redundancy Check*) ist ursprünglich eine **Fehlererkennungsmethode** aus der Nachrichtentechnik. Für das Hashing wird dieselbe Mathematik genutzt, weil CRC eine sehr gute **Streuungseigenschaft** besitzt: kleine Änderungen am Eingang verändern den Ausgang stark. Das macht CRC ideal als Hash-Funktion für Switch-MAC-Tables — reale Switch-ASICs (z.B. Broadcom Trident) verwenden ebenfalls CRC-basiertes Hashing.
 
---
 
## Mathematische Grundlage
 
CRC arbeitet im **Galois-Feld GF(2)**:
 
| Operation | In GF(2) |
|-----------|----------|
| Addition  | XOR (kein Übertrag) |
| Multiplikation | AND |
 
Die MAC-Adresse wird als **Polynom** interpretiert. Beispiel für das Byte `0xAA = 1010 1010`:
 
```
= 1·x⁷ + 0·x⁶ + 1·x⁵ + 0·x⁴ + 1·x³ + 0·x² + 1·x¹ + 0·x⁰
= x⁷ + x⁵ + x³ + x¹
```
 
Eine 48-Bit-MAC ergibt ein Polynom vom Grad 47. Dieses wird durch das **Generatorpolynom** dividiert — der Rest dieser Division ist der CRC-Wert.
 
---
 
## Das Generatorpolynom 0x8005
 
```
0x8005 = 1000 0000 0000 0101
       = x¹⁶ + x¹⁵ + x² + x⁰
```
 
Dieses Polynom ist **irreduzibel** in GF(2) — es lässt sich nicht weiter faktorisieren, ähnlich wie eine Primzahl. Das garantiert maximale Streuung der Ausgangswerte.
 
---
 
## Der Algorithmus Schritt für Schritt
 
### Initialisierung
 
```
c = 0xFFFF  (alle 16 Bits auf 1)
```
 
> **Warum 0xFFFF und nicht 0x0000?**
> Damit führende Nullen in der MAC einen Unterschied machen.
> `00:00:AA:BB:CC:DD` würde sonst den gleichen CRC-Start haben
> wie `AA:BB:CC:DD:EE:FF` — das würde die Streuung verschlechtern.
 
### Hauptschleife (für jedes der 48 Bits, MSB zuerst)
 
```
Schritt 1: Feedback-Bit berechnen
           b = mac[i] XOR c[15]
 
           Das höchste Bit des Schieberegisters (c[15])
           wird mit dem aktuellen MAC-Bit verglichen.
 
Schritt 2: Schieberegister um 1 nach links schieben
           c = c << 1   (Bit 0 wird 0)
 
Schritt 3: Falls b = 1 → XOR mit Generatorpolynom
           if b = 1: c = c XOR 0x8005
```
 
Nach 48 Iterationen enthält `c` den 16-Bit-CRC-Wert. Die unteren **13 Bit** davon bilden den Hash-Index.
 
---
 
## Visualisiertes Beispiel
 
Vereinfachtes 4-Bit-Beispiel mit Polynom `10011` (= x⁴ + x + 1):
 
```
Eingabe: 1011
Register Start: 1111
 
Bit 3 (=1):  b = 1 XOR 1(MSB) = 0  →  shift: 1110,  kein XOR
Bit 2 (=0):  b = 0 XOR 1(MSB) = 1  →  shift: 1100,  XOR 0011  →  1111
Bit 1 (=1):  b = 1 XOR 1(MSB) = 0  →  shift: 1110,  kein XOR
Bit 0 (=1):  b = 1 XOR 1(MSB) = 0  →  shift: 1100,  kein XOR
 
Ergebnis CRC = 1100
```
 
Vollständiger Ablauf für eine echte MAC `AA:BB:CC:DD:EE:FF`:
 
```
c = 0xFFFF = 1111 1111 1111 1111
 
Bit 47 (=1):  b = 1 XOR 1 = 0  →  c = 1111 1111 1111 1110
Bit 46 (=0):  b = 0 XOR 1 = 1  →  c = 1111 1111 1111 1100
                                XOR   1000 0000 0000 0101
                                    = 0111 1111 1111 1001
Bit 45 (=1):  b = 1 XOR 0 = 1  →  c = 1111 1111 1111 0010
                                XOR   1000 0000 0000 0101
                                    = 0111 1111 1111 0111
... (läuft so für alle 48 Bit)
 
Endergebnis: 16-Bit-CRC  →  untere 13 Bit = Hash-Index
```
 
---
 
## Warum CRC gut als Hash-Funktion ist
 
### 1. Avalanche-Effekt
 
Ein einzelnes geändertes Bit in der MAC verbreitet sich durch das Schieberegister auf viele Ausgangsbits:
 
```
MAC 1: AA:BB:CC:DD:EE:FF  →  Hash 4721
MAC 2: AA:BB:CC:DD:EE:FE  →  Hash 1893  (nur 1 Bit Unterschied!)
```
 
### 2. Gleichmäßige Verteilung
 
Bei zufälligen MACs sind die Hashes gleichmäßig über 0..8191 verteilt — keine Häufungen an bestimmten Stellen. Das ist die wichtigste Eigenschaft für eine niedrige Kollisionsrate.
 
### 3. Deterministismus
 
Gleiche Eingabe → immer gleiche Ausgabe, keine Zufälligkeit. Essenziell für einen Switch: dieselbe MAC muss immer im gleichen Bucket landen.
 
### 4. Hardware-Effizienz
 
CRC lässt sich als reines Schieberegister mit XOR-Gattern implementieren — keine Multiplizierer, keine komplexe Arithmetik. Auf einem FPGA belegt das nur wenige LUTs und hat eine Latenz von einem Taktzyklus.
 
---
 
## Die 13-Bit-Extraktion
 
```vhdl
hash_out <= crc(12 downto 0);
```
 
```
CRC-Ergebnis (16 Bit):  1011 0110 1001 1101
                         ^^^  (ignoriert)
                              ^^^^^^^^^^^^^
                              13 Bit = Hash-Index (0 .. 8191)
 
2¹³ = 8192 mögliche Werte → passt exakt zu den 8192 Buckets
```
 
> **Warum die unteren 13 Bit?**
> Die unteren Bits des CRC-Schieberegisters akkumulieren Information
> aus allen Teilen der Eingabe-MAC. Die oberen Bits hängen stärker
> vom Ende der Eingabe ab. In der Praxis sind beide Varianten gut —
> die unteren Bits geben eine minimal bessere Streuung.
 
---
 
## Kollisionswahrscheinlichkeit
 
Mit dem **Geburtstagsparadoxon** lässt sich die erwartete Kollisionsrate berechnen:
 
```
n = Anzahl eingespeicherter MACs
m = 8192 Buckets
 
P(mind. 1 Kollision) ≈ 1 - e^(-n² / 2m)
```
 
| Einträge n | Kollisionswahrscheinlichkeit |
|-----------|------------------------------|
| 10        | ~0,6 %                       |
| 100       | ~46 %                        |
| 500       | ~99,9 %                      |
| 8000      | ~100 %                       |
 
> **Wichtig:** Eine Kollision bedeutet nur, dass **ein Bucket zwei Einträge** hat —
> nicht dass der Lookup scheitert. Dafür ist das **Bucket-System mit 4 Slots** da.
> Der Lookup prüft einfach alle Slots des Buckets sequenziell.
 
---
 
## VHDL-Implementierung
 
```vhdl
entity mac_hash is
    port (
        mac_in   : in  std_logic_vector(47 downto 0);
        hash_out : out std_logic_vector(12 downto 0)  -- 0 .. 8191
    );
end mac_hash;
 
architecture rtl of mac_hash is
begin
    process(mac_in)
        variable c : std_logic_vector(15 downto 0);
        variable b : std_logic;
    begin
        c := x"FFFF";                          -- Initialisierung
        for i in 47 downto 0 loop             -- MSB zuerst (Bit 47 .. 0)
            b := mac_in(i) xor c(15);         -- Feedback-Bit
            c := c(14 downto 0) & '0';        -- Links-Shift
            if b = '1' then
                c := c xor x"8005";           -- XOR mit Generatorpolynom
            end if;
        end loop;
        hash_out <= c(12 downto 0);           -- untere 13 Bit = Index
    end process;
end rtl;
```
 
### Eigenschaften der VHDL-Implementierung
 
| Eigenschaft | Wert |
|-------------|------|
| Eingabe | 48 Bit (MAC-Adresse) |
| Ausgabe | 13 Bit (Index 0..8191) |
| Latenz | 1 Taktzyklus (kombinatorisch) |
| FPGA-Ressourcen | ~50 LUTs (Artix-7) |
| Taktfrequenz | > 200 MHz erreichbar |
 
### Warum MSB zuerst (`47 downto 0`)?
 
Das entspricht der **Big-Endian-Konvention** bei Ethernet-Frames. MAC-Adressen werden byteweise übertragen. Die Richtung muss konsistent sein — sonst bekommt man für dieselbe MAC zwei verschiedene Hashes.
