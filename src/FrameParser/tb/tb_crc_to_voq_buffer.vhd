-- =============================================================================
-- Testbench: tb_crc_to_voq_buffer
--
-- Zweck:
--   Stimuliert den crc_to_voq_buffer mit 4 aufeinanderfolgenden Frames,
--   jeweils 15 Datenbytes lang, an unterschiedliche Zielports (One-Hot).
--
-- Timing pro Frame (relativ zum 1. Schreibtakt = Takt 1):
--     Takt  1 ..  5 :  wr_en='1', wr_data = Byte 1..5, wr_eof='0'.
--     Takt  6       :  wr_en='1', wr_data = Byte 6, wr_eof='0',
--                      DAZU: dest_port_flag='1', dest_port=One-Hot.
--                      ==> "5 Takte nach Byte 1"
--     Takt  7       :  dest_port_flag, dest_port wieder '0'.
--                      Datenstrom laeuft weiter (Byte 7).
--     Takt  8 .. 14 :  Byte 8..14, wr_eof='0'.
--     Takt 15       :  Byte 15, wr_eof='1' (Frame-Ende).
--     Takt 16       :  wr_en='0' (Schreibseite aus).
--     Pause         :  Warten, bis das Frame komplett ausgelesen ist.
--
-- Ein Monitor-Prozess loggt jedes Lesebyte, wenn rd_dest_port_en aktiv ist.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_crc_to_voq_buffer IS
END ENTITY tb_crc_to_voq_buffer;

ARCHITECTURE sim OF tb_crc_to_voq_buffer IS

    ---------------------------------------------------------------------------
    -- Konstanten
    ---------------------------------------------------------------------------
    CONSTANT CLK_PERIOD : TIME := 10 ns;
    CONSTANT DEPTH : INTEGER := 64;
    CONSTANT FRAME_LEN : INTEGER := 15;
    CONSTANT FLAG_OFFSET : INTEGER := 6; -- Flag im 6. Takt (= 5 Takte NACH Byte 1)

    ---------------------------------------------------------------------------
    -- Frame-Daten
    ---------------------------------------------------------------------------
    TYPE byte_array_t IS ARRAY(1 TO FRAME_LEN) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

    CONSTANT FRAME_1 : byte_array_t := (
        x"A1", x"A2", x"A3", x"A4", x"A5",
        x"A6", x"A7", x"A8", x"A9", x"AA",
        x"AB", x"AC", x"AD", x"AE", x"AF"
    );
    CONSTANT FRAME_2 : byte_array_t := (
        x"B1", x"B2", x"B3", x"B4", x"B5",
        x"B6", x"B7", x"B8", x"B9", x"BA",
        x"BB", x"BC", x"BD", x"BE", x"BF"
    );
    CONSTANT FRAME_3 : byte_array_t := (
        x"C1", x"C2", x"C3", x"C4", x"C5",
        x"C6", x"C7", x"C8", x"C9", x"CA",
        x"CB", x"CC", x"CD", x"CE", x"CF"
    );
    CONSTANT FRAME_4 : byte_array_t := (
        x"D1", x"D2", x"D3", x"D4", x"D5",
        x"D6", x"D7", x"D8", x"D9", x"DA",
        x"DB", x"DC", x"DD", x"DE", x"DF"
    );

    ---------------------------------------------------------------------------
    -- DUT-Signale
    ---------------------------------------------------------------------------
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';
    SIGNAL flush : STD_LOGIC := '0';
    SIGNAL sim_done : BOOLEAN := false;

    -- Schreibseite
    SIGNAL wr_en : STD_LOGIC := '0';
    SIGNAL wr_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL wr_eof : STD_LOGIC := '0';

    -- Frame-Metadaten
    SIGNAL dest_port : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL dest_port_flag : STD_LOGIC := '0';

    -- Leseseite
    SIGNAL rd_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL rd_eof : STD_LOGIC;
    SIGNAL rd_dest_port_en : STD_LOGIC_VECTOR(3 DOWNTO 0);

    -- Status
    SIGNAL frame_rdy : STD_LOGIC;
    SIGNAL full : STD_LOGIC_VECTOR(3 DOWNTO 0);

BEGIN

    ---------------------------------------------------------------------------
    -- Clock-Erzeugung
    ---------------------------------------------------------------------------
    clk_gen : PROCESS
    BEGIN
        WHILE NOT sim_done LOOP
            clk <= '0';
            WAIT FOR CLK_PERIOD / 2;
            clk <= '1';
            WAIT FOR CLK_PERIOD / 2;
        END LOOP;
        WAIT;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    DUT : ENTITY work.crc_to_voq_buffer
        GENERIC MAP(
            DEPTH => DEPTH,
            NUM_OUTPUTS => 4
        )
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => flush,

            wr_en => wr_en,
            wr_data => wr_data,
            wr_eof => wr_eof,

            dest_port => dest_port,
            dest_port_flag => dest_port_flag,

            rd_data => rd_data,
            rd_eof => rd_eof,
            rd_dest_port_en => rd_dest_port_en,

            frame_rdy => frame_rdy,
            full => full
        );

    ---------------------------------------------------------------------------
    -- Stimuli
    ---------------------------------------------------------------------------
    stim : PROCESS

        -----------------------------------------------------------------------
        -- Sendet ein Frame: 15 Datenbytes, mit dest_port_flag im 6. Takt
        -----------------------------------------------------------------------
        PROCEDURE send_frame(
            CONSTANT data : IN byte_array_t;
            CONSTANT port_oh : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            CONSTANT frame_id : IN INTEGER
        ) IS
        BEGIN
            REPORT "==================================================";
            REPORT "Sende Frame " & INTEGER'image(frame_id)
                & " (" & INTEGER'image(FRAME_LEN) & " Bytes)"
                & " -> Port (One-Hot) = " & to_string(port_oh);

            FOR i IN 1 TO FRAME_LEN LOOP
                WAIT UNTIL rising_edge(clk);

                -- Datenbyte und Schreibfreigabe
                wr_en <= '1';
                wr_data <= data(i);

                -- EOF nur auf dem letzten Byte
                IF i = FRAME_LEN THEN
                    wr_eof <= '1';
                ELSE
                    wr_eof <= '0';
                END IF;

                -- Im 6. Takt (= 5 Takte nach Byte 1): Port-Adresse + Flag
                IF i = FLAG_OFFSET THEN
                    dest_port_flag <= '1';
                    dest_port <= port_oh;
                ELSIF i = FLAG_OFFSET + 1 THEN
                    -- Flag nach 1 Takt wieder loslassen
                    dest_port_flag <= '0';
                    dest_port <= (OTHERS => '0');
                END IF;
            END LOOP;

            -- Schreibseite ausschalten
            WAIT UNTIL rising_edge(clk);
            wr_en <= '0';
            wr_eof <= '0';
            wr_data <= (OTHERS => '0');

            -- Warten, bis das Frame komplett ausgelesen ist
            -- (Read laeuft parallel zum Write; reichlich Margin)
            WAIT FOR 25 * CLK_PERIOD;
        END PROCEDURE;

    BEGIN
        -----------------------------------------------------------------------
        -- Reset-Phase
        -----------------------------------------------------------------------
        REPORT "Reset...";
        reset <= '0';
        WAIT FOR 4 * CLK_PERIOD;
        WAIT UNTIL rising_edge(clk);
        reset <= '1';
        WAIT FOR 2 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- 4 Frames an je einen anderen Zielport
        -----------------------------------------------------------------------
        send_frame(FRAME_1, "0001", 1); -- Port 0
        send_frame(FRAME_2, "0010", 2); -- Port 1
        send_frame(FRAME_3, "0100", 3); -- Port 2
        send_frame(FRAME_4, "1000", 4); -- Port 3

        -----------------------------------------------------------------------
        -- Auslaufen lassen, dann beenden
        -----------------------------------------------------------------------
        WAIT FOR 10 * CLK_PERIOD;
        REPORT "==================================================";
        REPORT "Simulation beendet";
        sim_done <= true;
        WAIT;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- Monitor: loggt jedes Lesebyte, wenn rd_dest_port_en /= 0
    ---------------------------------------------------------------------------
    monitor : process(all)
    BEGIN
        IF rising_edge(clk) THEN
            IF rd_dest_port_en /= "0000" THEN
                IF rd_eof = '1' THEN
                    REPORT "  READ -> dest_en=" & to_string(rd_dest_port_en)
                        & "  data=0x" & to_hstring(rd_data) & "  [EOF]";
                ELSE
                    REPORT "  READ -> dest_en=" & to_string(rd_dest_port_en)
                        & "  data=0x" & to_hstring(rd_data);
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE sim;