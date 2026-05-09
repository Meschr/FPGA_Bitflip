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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_crc_to_voq_buffer is
end entity tb_crc_to_voq_buffer;

architecture sim of tb_crc_to_voq_buffer is

    ---------------------------------------------------------------------------
    -- Konstanten
    ---------------------------------------------------------------------------
    constant CLK_PERIOD   : time    := 10 ns;
    constant DEPTH        : integer := 64;
    constant FRAME_LEN    : integer := 15;
    constant FLAG_OFFSET  : integer := 6;   -- Flag im 6. Takt (= 5 Takte NACH Byte 1)

    ---------------------------------------------------------------------------
    -- Frame-Daten
    ---------------------------------------------------------------------------
    type byte_array_t is array(1 to FRAME_LEN) of std_logic_vector(7 downto 0);

    constant FRAME_1 : byte_array_t := (
        x"A1", x"A2", x"A3", x"A4", x"A5",
        x"A6", x"A7", x"A8", x"A9", x"AA",
        x"AB", x"AC", x"AD", x"AE", x"AF"
    );
    constant FRAME_2 : byte_array_t := (
        x"B1", x"B2", x"B3", x"B4", x"B5",
        x"B6", x"B7", x"B8", x"B9", x"BA",
        x"BB", x"BC", x"BD", x"BE", x"BF"
    );
    constant FRAME_3 : byte_array_t := (
        x"C1", x"C2", x"C3", x"C4", x"C5",
        x"C6", x"C7", x"C8", x"C9", x"CA",
        x"CB", x"CC", x"CD", x"CE", x"CF"
    );
    constant FRAME_4 : byte_array_t := (
        x"D1", x"D2", x"D3", x"D4", x"D5",
        x"D6", x"D7", x"D8", x"D9", x"DA",
        x"DB", x"DC", x"DD", x"DE", x"DF"
    );

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

    -- Frame-Metadaten
    signal dest_port      : std_logic_vector(3 downto 0) := (others => '0');
    signal dest_port_flag : std_logic := '0';

    -- Leseseite
    signal rd_data         : std_logic_vector(7 downto 0);
    signal rd_eof          : std_logic;
    signal rd_dest_port_en : std_logic_vector(3 downto 0);

    -- Status
    signal frame_rdy : std_logic;
    signal full      : std_logic_vector(3 downto 0);

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

        -----------------------------------------------------------------------
        -- Sendet ein Frame: 15 Datenbytes, mit dest_port_flag im 6. Takt
        -----------------------------------------------------------------------
        procedure send_frame(
            constant data     : in byte_array_t;
            constant port_oh  : in std_logic_vector(3 downto 0);
            constant frame_id : in integer
        ) is
        begin
            report "==================================================";
            report "Sende Frame " & integer'image(frame_id)
                 & " (" & integer'image(FRAME_LEN) & " Bytes)"
                 & " -> Port (One-Hot) = " & to_string(port_oh);

            for i in 1 to FRAME_LEN loop
                wait until rising_edge(clk);

                -- Datenbyte und Schreibfreigabe
                wr_en   <= '1';
                wr_data <= data(i);

                -- EOF nur auf dem letzten Byte
                if i = FRAME_LEN then
                    wr_eof <= '1';
                else
                    wr_eof <= '0';
                end if;

                -- Im 6. Takt (= 5 Takte nach Byte 1): Port-Adresse + Flag
                if i = FLAG_OFFSET then
                    dest_port_flag <= '1';
                    dest_port      <= port_oh;
                elsif i = FLAG_OFFSET + 1 then
                    -- Flag nach 1 Takt wieder loslassen
                    dest_port_flag <= '0';
                    dest_port      <= (others => '0');
                end if;
            end loop;

            -- Schreibseite ausschalten
            wait until rising_edge(clk);
            wr_en   <= '0';
            wr_eof  <= '0';
            wr_data <= (others => '0');

            -- Warten, bis das Frame komplett ausgelesen ist
            -- (Read laeuft parallel zum Write; reichlich Margin)
            wait for 25 * CLK_PERIOD;
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
        -- 4 Frames an je einen anderen Zielport
        -----------------------------------------------------------------------
        send_frame(FRAME_1, "0001", 1);   -- Port 0
        send_frame(FRAME_2, "0010", 2);   -- Port 1
        send_frame(FRAME_3, "0100", 3);   -- Port 2
        send_frame(FRAME_4, "1000", 4);   -- Port 3

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