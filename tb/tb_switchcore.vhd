library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use STD.ENV.all;
use STD.TEXTIO.all;
use IEEE.STD_LOGIC_TEXTIO.all;

entity tb_switchcore is
end tb_switchcore;

architecture rtl of tb_switchcore is
    constant CLK_PERIOD      : TIME    := 8 ns; -- 125 MHz
    constant STIMULUS_PATH   : STRING  := "./tb/";
    constant MAX_FRAME_BYTES : NATURAL := 2048;
    constant SIM_TIMEOUT     : TIME    := 500 us;

    signal clk : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';

    -- GMII Interface signals
    signal tx_data   : STD_LOGIC_VECTOR(31 downto 0);
    signal tx_ctrl   : STD_LOGIC_VECTOR(3 downto 0);
    signal rx_data   : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal rx_ctrl   : STD_LOGIC_VECTOR(3 downto 0)  := (others => '0');
    signal link_sync : STD_LOGIC_VECTOR(3 downto 0)  := (others => '1');

    type frame_buffer_t is array (0 to MAX_FRAME_BYTES - 1) of STD_LOGIC_VECTOR(7 downto 0);

    function nibble_to_char(nibble : STD_LOGIC_VECTOR(3 downto 0)) return CHARACTER is
    begin
        case nibble is
            when "0000" => return '0';
            when "0001" => return '1';
            when "0010" => return '2';
            when "0011" => return '3';
            when "0100" => return '4';
            when "0101" => return '5';
            when "0110" => return '6';
            when "0111" => return '7';
            when "1000" => return '8';
            when "1001" => return '9';
            when "1010" => return 'A';
            when "1011" => return 'B';
            when "1100" => return 'C';
            when "1101" => return 'D';
            when "1110" => return 'E';
            when "1111" => return 'F';
            when others => return 'X';
        end case;
    end function;

    function byte_to_hex_string(byte_v : STD_LOGIC_VECTOR(7 downto 0)) return STRING is
        variable result                    : STRING(1 to 2);
    begin
        result(1) := nibble_to_char(byte_v(7 downto 4));
        result(2) := nibble_to_char(byte_v(3 downto 0));
        return result;
    end function;

    function frame_mac_string(frame : frame_buffer_t; start_idx : NATURAL) return STRING is
        variable result : STRING(1 to 17);
        variable pos    : NATURAL := 1;
    begin
        for idx in 0 to 5 loop
            result(pos to pos + 1) := byte_to_hex_string(frame(start_idx + idx));
            pos                    := pos + 2;
            if idx < 5 then
                result(pos) := ':';
                pos         := pos + 1;
            end if;
        end loop;
        return result;
    end function;

    function frame_fcs_string(frame : frame_buffer_t; frame_len : NATURAL) return STRING is
        variable result : STRING(1 to 10);
    begin
        result(1) := '0';
        result(2) := 'x';
        if frame_len >= 4 then
            result(3 to 4)  := byte_to_hex_string(frame(frame_len - 4));
            result(5 to 6)  := byte_to_hex_string(frame(frame_len - 3));
            result(7 to 8)  := byte_to_hex_string(frame(frame_len - 2));
            result(9 to 10) := byte_to_hex_string(frame(frame_len - 1));
        else
            result(3 to 10) := "00000000";
        end if;
        return result;
    end function;

    procedure parse_frame_line(
        variable frame_line : inout line;
        variable frame      : out frame_buffer_t;
        variable frame_len  : out NATURAL
    ) is
        variable byte_v : STD_LOGIC_VECTOR(7 downto 0);
    begin
        frame_len := 0;
        while frame_line.all'length > 0 loop
            hread(frame_line, byte_v);
            if frame_len <= frame'high then
                frame(frame_len) := byte_v;
            end if;
            frame_len := frame_len + 1;
        end loop;
    end procedure;

    procedure send_frame(
        signal clk_i   : in STD_LOGIC;
        signal data_o  : out STD_LOGIC_VECTOR(7 downto 0);
        signal valid_o : out STD_LOGIC;
        variable frame : in frame_buffer_t;
        frame_len      : in NATURAL
    ) is
    begin
        if frame_len > 0 then
            for idx in 0 to frame_len - 1 loop
                data_o  <= frame(idx);
                valid_o <= '1';
                wait until rising_edge(clk_i);
            end loop;
        end if;

        valid_o <= '0';
        data_o  <= (others => '0');
        wait until rising_edge(clk_i);
    end procedure;

    procedure monitor_port(
        signal clk_i           : in STD_LOGIC;
        signal data_i          : in STD_LOGIC_VECTOR(7 downto 0);
        signal valid_i         : in STD_LOGIC;
        constant port_label    : STRING;
        constant final_monitor : BOOLEAN
    ) is
        variable frame     : frame_buffer_t := (others => (others => '0'));
        variable frame_len : NATURAL        := 0;
        variable capturing : BOOLEAN        := false;
        variable dst_mac   : STRING(1 to 17);
        variable src_mac   : STRING(1 to 17);
        variable fcs       : STRING(1 to 10);
    begin
        loop
            if final_monitor and now >= SIM_TIMEOUT then
                std.env.finish;
            end if;

            wait until rising_edge(clk_i);

            if valid_i = '1' then
                if not capturing then
                    capturing := true;
                    frame_len := 0;
                end if;

                if frame_len <= frame'high then
                    frame(frame_len) := data_i;
                end if;
                frame_len := frame_len + 1;

            elsif capturing then
                if frame_len >= 12 then
                    src_mac := frame_mac_string(frame, 6);
                    dst_mac := frame_mac_string(frame, 0);
                    fcs     := frame_fcs_string(frame, frame_len);
                    report port_label &
                        " receive message" &
                        "; dst_mac: " & dst_mac &
                        "; src_mac: " & src_mac &
                        "; fcs: " & fcs
                        severity note;
                end if;

                capturing := false;
                frame_len := 0;
            end if;
        end loop;
    end procedure;

begin

    -- Instantiate the switchcore
    DUT : entity work.switchcore
        port map(
            clk       => clk,
            reset     => rst,
            link_sync => link_sync,
            tx_data   => tx_data,
            tx_ctrl   => tx_ctrl,
            rx_data   => rx_data,
            rx_ctrl   => rx_ctrl
        );

    -- Clock generation
    clk_gen : process
    begin
        loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- Reset process
    reset_proc : process
    begin
        rst <= '0';
        wait for 100 ns;
        rst <= '1';
        wait;
    end process;

    port0_stimulus : process
        file stim_file        : text open read_mode is STIMULUS_PATH & "stimulus_port0.txt";
        variable comment_line : line;
        variable frame_line   : line;
        variable frame        : frame_buffer_t;
        variable frame_len    : NATURAL;
        variable src_mac      : STRING(1 to 17);
        variable dst_mac      : STRING(1 to 17);
        variable fcs          : STRING(1 to 10);
    begin
        wait until rst = '1';
        wait for 500 ns;

        while not endfile(stim_file) loop
            readline(stim_file, comment_line);

            if comment_line.all'length = 0 then
                next;
            end if;

            if comment_line.all(comment_line.all'low) = '#' then
                if endfile(stim_file) then
                    exit;
                end if;

                readline(stim_file, frame_line);
                while frame_line.all'length = 0 and not endfile(stim_file) loop
                    readline(stim_file, frame_line);
                end loop;

                if frame_line.all'length = 0 then
                    exit;
                end if;

                parse_frame_line(frame_line, frame, frame_len);
                dst_mac := frame_mac_string(frame, 8);
                src_mac := frame_mac_string(frame, 14);
                fcs     := frame_fcs_string(frame, frame_len);
                report "Port 0 sending message; dst_mac: " & dst_mac & "; src_mac: " & src_mac & "; fcs: " & fcs severity note;

                send_frame(clk, rx_data(7 downto 0), rx_ctrl(0), frame, frame_len);

                for gap in 1 to 20 loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;

        wait;
    end process;

    port1_stimulus : process
        file stim_file        : text open read_mode is STIMULUS_PATH & "stimulus_port1.txt";
        variable comment_line : line;
        variable frame_line   : line;
        variable frame        : frame_buffer_t;
        variable frame_len    : NATURAL;
        variable src_mac      : STRING(1 to 17);
        variable dst_mac      : STRING(1 to 17);
        variable fcs          : STRING(1 to 10);
    begin
        wait until rst = '1';
        wait for 1 us;

        while not endfile(stim_file) loop
            readline(stim_file, comment_line);

            if comment_line.all'length = 0 then
                next;
            end if;

            if comment_line.all(comment_line.all'low) = '#' then
                if endfile(stim_file) then
                    exit;
                end if;

                readline(stim_file, frame_line);
                while frame_line.all'length = 0 and not endfile(stim_file) loop
                    readline(stim_file, frame_line);
                end loop;

                if frame_line.all'length = 0 then
                    exit;
                end if;

                parse_frame_line(frame_line, frame, frame_len);
                dst_mac := frame_mac_string(frame, 8);
                src_mac := frame_mac_string(frame, 14);
                fcs     := frame_fcs_string(frame, frame_len);
                report "Port 1 sending message; dst_mac: " & dst_mac & "; src_mac: " & src_mac & "; fcs: " & fcs severity note;

                send_frame(clk, rx_data(15 downto 8), rx_ctrl(1), frame, frame_len);

                for gap in 1 to 20 loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;

        wait;
    end process;

    port2_stimulus : process
        file stim_file        : text open read_mode is STIMULUS_PATH & "stimulus_port2.txt";
        variable comment_line : line;
        variable frame_line   : line;
        variable frame        : frame_buffer_t;
        variable frame_len    : NATURAL;
        variable src_mac      : STRING(1 to 17);
        variable dst_mac      : STRING(1 to 17);
        variable fcs          : STRING(1 to 10);
    begin
        wait until rst = '1';
        wait for 1.5 us;

        while not endfile(stim_file) loop
            readline(stim_file, comment_line);

            if comment_line.all'length = 0 then
                next;
            end if;

            if comment_line.all(comment_line.all'low) = '#' then
                if endfile(stim_file) then
                    exit;
                end if;

                readline(stim_file, frame_line);
                while frame_line.all'length = 0 and not endfile(stim_file) loop
                    readline(stim_file, frame_line);
                end loop;

                if frame_line.all'length = 0 then
                    exit;
                end if;

                parse_frame_line(frame_line, frame, frame_len);
                dst_mac := frame_mac_string(frame, 8);
                src_mac := frame_mac_string(frame, 14);
                fcs     := frame_fcs_string(frame, frame_len);
                report "Port 2 sending message; dst_mac: " & dst_mac & "; src_mac: " & src_mac & "; fcs: " & fcs severity note;

                send_frame(clk, rx_data(23 downto 16), rx_ctrl(2), frame, frame_len);

                for gap in 1 to 20 loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;

        wait;
    end process;

    port3_stimulus : process
        file stim_file        : text open read_mode is STIMULUS_PATH & "stimulus_port3.txt";
        variable comment_line : line;
        variable frame_line   : line;
        variable frame        : frame_buffer_t;
        variable frame_len    : NATURAL;
        variable src_mac      : STRING(1 to 17);
        variable dst_mac      : STRING(1 to 17);
        variable fcs          : STRING(1 to 10);
    begin
        wait until rst = '1';
        wait for 2 us;

        while not endfile(stim_file) loop
            readline(stim_file, comment_line);

            if comment_line.all'length = 0 then
                next;
            end if;

            if comment_line.all(comment_line.all'low) = '#' then
                if endfile(stim_file) then
                    exit;
                end if;

                readline(stim_file, frame_line);
                while frame_line.all'length = 0 and not endfile(stim_file) loop
                    readline(stim_file, frame_line);
                end loop;

                if frame_line.all'length = 0 then
                    exit;
                end if;

                parse_frame_line(frame_line, frame, frame_len);
                dst_mac := frame_mac_string(frame, 8);
                src_mac := frame_mac_string(frame, 14);
                fcs     := frame_fcs_string(frame, frame_len);
                report "Port 3 sending message; dst_mac: " & dst_mac & "; src_mac: " & src_mac & "; fcs: " & fcs severity note;

                send_frame(clk, rx_data(31 downto 24), rx_ctrl(3), frame, frame_len);

                for gap in 1 to 20 loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;

        wait;
    end process;

    port0_monitor : process
    begin
        wait until rst = '1';
        monitor_port(clk, tx_data(7 downto 0), tx_ctrl(0), "Port 0", false);
    end process;

    port1_monitor : process
    begin
        wait until rst = '1';
        monitor_port(clk, tx_data(15 downto 8), tx_ctrl(1), "Port 1", false);
    end process;

    port2_monitor : process
    begin
        wait until rst = '1';
        monitor_port(clk, tx_data(23 downto 16), tx_ctrl(2), "Port 2", false);
    end process;

    port3_monitor : process
    begin
        wait until rst = '1';
        monitor_port(clk, tx_data(31 downto 24), tx_ctrl(3), "Port 3", true);
    end process;

end architecture rtl;
