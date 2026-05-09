-- =============================================================================
-- Testbench: tb_crc_to_voq_buffer
--
-- Zweck:
--   Stimuliert den crc_to_voq_buffer mit vier aufeinanderfolgenden Frames,
--   jeweils 15 Datenbytes lang, an unterschiedliche Zielports (One-Hot).
--
-- Timing pro Frame:
--     Takt 1..15:  wr_en='1', wr_data=Byte 1..15. Auf Byte 15 wird wr_eof='1'.
--     Takt 6    :  dest_port_flag='1' UND dest_port=One-Hot UND crc_valid='1'.
--                 (5 Takte nach dem ersten Byte)
--     Takt 7    :  Alle Trigger wieder zurueck auf '0'.
--     ...       :  Warten, bis der Frame ausgelesen wurde.
--
-- Ein Monitor-Prozess loggt jedes Lesebyte (wenn rd_dest_port_en aktiv ist).
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_crc_to_voq_buffer is
end entity tb_crc_to_voq_buffer;

architecture sim of tb_crc_to_voq_buffer is

    ---------------------------------------------------------------------------
    -- Konstanten
    ---------------------------------------------------------------------------
    constant CLK_PERIOD : time    := 10 ns;
    constant DEPTH      : integer := 2000;

    ---------------------------------------------------------------------------
    -- DUT-Signale
    ---------------------------------------------------------------------------
    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal flush    : std_logic := '0';
    signal sim_done : boolean   := false;

    -- Schreibseite
    signal wr_en   : std_logic := '0';
    signal wr_data : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof  : std_logic := '0';

    -- Frame-Metadaten (kommen am Ende des Frames)
    signal crc_valid      : std_logic := '0';
    signal dest_port      : std_logic_vector(3 downto 0) := (others => '0');
    signal dest_port_flag : std_logic := '0';

    -- Leseseite
    signal rd_data         : std_logic_vector(7 downto 0);
    signal rd_eof          : std_logic;
    signal rd_dest_port_en : std_logic_vector(3 downto 0);

    -- Status
    signal frame_rdy : std_logic;
    signal full      : std_logic_vector(3 downto 0);

    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

    constant FRAME1 : byte_array_t(0 to 14) := (
        x"A1", x"A2", x"A3", x"A4", x"A5",
        x"A6", x"A7", x"A8", x"A9", x"AA",
        x"AB", x"AC", x"AD", x"AE", x"AF"
    );

    constant FRAME2 : byte_array_t(0 to 14) := (
        x"B1", x"B2", x"B3", x"B4", x"B5",
        x"B6", x"B7", x"B8", x"B9", x"BA",
        x"BB", x"BC", x"BD", x"BE", x"BF"
    );

    constant FRAME3 : byte_array_t(0 to 14) := (
        x"C1", x"C2", x"C3", x"C4", x"C5",
        x"C6", x"C7", x"C8", x"C9", x"CA",
        x"CB", x"CC", x"CD", x"CE", x"CF"
    );

    constant FRAME4 : byte_array_t(0 to 14) := (
        x"D1", x"D2", x"D3", x"D4", x"D5",
        x"D6", x"D7", x"D8", x"D9", x"DA",
        x"DB", x"DC", x"DD", x"DE", x"DF"
    );

begin

    ---------------------------------------------------------------------------
    -- Clock-Erzeugung
    ---------------------------------------------------------------------------
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    DUT : entity work.crc_to_voq_buffer
        generic map (
            DEPTH       => DEPTH,
            NUM_OUTPUTS => 4
        )
        port map (
            clk             => clk,
            reset           => reset,
            flush           => flush,

            wr_en           => wr_en,
            wr_data         => wr_data,
            wr_eof          => wr_eof,

            crc_valid       => crc_valid,
            dest_port       => dest_port,
            dest_port_flag  => dest_port_flag,

            rd_data         => rd_data,
            rd_eof          => rd_eof,
            rd_dest_port_en => rd_dest_port_en,

            frame_rdy       => frame_rdy,
            full            => full
        );

    ---------------------------------------------------------------------------
    -- Stimuli
    ---------------------------------------------------------------------------
    stim : process

        -- ---------------------------------------------------------------------
        -- Sendet ein Frame: 15 Datenbytes, dest_port_flag + dest_port
        -- 5 Takte nach dem ersten Byte
        -- ---------------------------------------------------------------------
        procedure send_frame(
            constant payload        : in byte_array_t;
            constant port_oh        : in std_logic_vector(3 downto 0);
            constant frame_id       : in integer
        ) is
            constant FLAG_CYCLE : integer := 5;
        begin
            report "==================================================";
            report "Sende Frame " & integer'image(frame_id)
                 & " -> dest_port (One-Hot) = " & to_string(port_oh);
            report "Daten: 15 Bytes (EOF auf letztem Byte)";

            ----- 15 Datenbytes, EOF auf dem letzten Byte -----
            for i in payload'range loop
                wait until rising_edge(clk);
                wr_en   <= '1';
                wr_data <= payload(i);
                if i = payload'high then
                    wr_eof <= '1';
                else
                    wr_eof <= '0';
                end if;

                if i = FLAG_CYCLE then
                    dest_port_flag <= '1';
                    dest_port      <= port_oh;
                    crc_valid      <= '1';
                else
                    dest_port_flag <= '0';
                    dest_port      <= (others => '0');
                    crc_valid      <= '0';
                end if;
            end loop;

            ----- Schreibseite freigeben -----
            wait until rising_edge(clk);
            wr_en          <= '0';
            wr_eof         <= '0';
            wr_data        <= (others => '0');
            dest_port_flag <= '0';
            dest_port      <= (others => '0');
            crc_valid      <= '0';

            ----- Warten, bis das Frame komplett ausgelesen ist -----
            wait for 12 * CLK_PERIOD;
        end procedure;

    begin
        -----------------------------------------------------------------------
        -- Reset-Phase
        -----------------------------------------------------------------------
        report "Reset...";
        reset <= '1';
        wait for 4 * CLK_PERIOD;
        wait until rising_edge(clk);
        reset <= '0';
        wait for 2 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- Frame 1: an Port 0 (One-Hot "0001")
        -----------------------------------------------------------------------
        send_frame(FRAME1, "0001", 1);

        -----------------------------------------------------------------------
        -- Frame 2: an Port 1 (One-Hot "0010")
        -----------------------------------------------------------------------
        send_frame(FRAME2, "0010", 2);

        -----------------------------------------------------------------------
        -- Frame 3: an Port 3 (One-Hot "1000")
        -----------------------------------------------------------------------
        send_frame(FRAME3, "1000", 3);

        -----------------------------------------------------------------------
        -- Frame 4: an Port 2 (One-Hot "0100")
        -----------------------------------------------------------------------
        send_frame(FRAME4, "0100", 4);

        -----------------------------------------------------------------------
        -- Auslaufen lassen, dann beenden
        -----------------------------------------------------------------------
        wait for 10 * CLK_PERIOD;
        report "==================================================";
        report "Simulation beendet";
        sim_done <= true;
        wait;
    end process;

    ---------------------------------------------------------------------------
    -- Monitor: loggt jedes Lesebyte, wenn rd_dest_port_en /= 0
    -- (also wenn der Buffer einen Frame aktiv an einen VOQ schiebt)
    ---------------------------------------------------------------------------
    monitor : process(clk)
    begin
        if rising_edge(clk) then
            if rd_dest_port_en /= "0000" then
                if rd_eof = '1' then
                    report "  READ -> dest_en=" & to_string(rd_dest_port_en)
                         & "  data=0x" & to_hstring(rd_data) & "  [EOF]";
                else
                    report "  READ -> dest_en=" & to_string(rd_dest_port_en)
                         & "  data=0x" & to_hstring(rd_data);
                end if;
            end if;
        end if;
    end process;

end architecture sim;