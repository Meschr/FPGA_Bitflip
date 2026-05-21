library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;
use std.env.all;

entity tb_new_frame_handler is
end entity tb_new_frame_handler;

architecture tb of tb_new_frame_handler is

    -- Clock period
    constant CLK_PERIOD : TIME := 10 ns;
    constant FLAG_DELAY_CYCLES : NATURAL := 5;

    -- Signals for DUT ports
    signal clk : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '0';

    -- Inputs to frame_handler
    signal data_in : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal data_valid : STD_LOGIC := '0';
    signal buffer_dest_port : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal buffer_dest_port_flag : STD_LOGIC := '0';

    -- Outputs from frame_handler
    signal data_out : STD_LOGIC_VECTOR(7 downto 0);
    signal dst_port : STD_LOGIC_VECTOR(3 downto 0);
    signal dst_valid : STD_LOGIC;
    signal crc_valid : STD_LOGIC;
    signal eof_handler : STD_LOGIC;
    signal fcs_error : STD_LOGIC;
    signal frame_rdy_handler : STD_LOGIC;
    signal full_buffer : STD_LOGIC_VECTOR(3 downto 0);

    file stimulus_file : text open read_mode is "src/stimulus.txt";

    function contains_str(source : STRING; needle : STRING) return BOOLEAN is
        variable match : BOOLEAN;
    begin
        if needle'length = 0 then
            return true;
        end if;

        if source'length < needle'length then
            return false;
        end if;

        for start_idx in source'low to source'high - needle'length + 1 loop
            match := true;
            for needle_idx in needle'range loop
                if source(start_idx + (needle_idx - needle'low)) /= needle(needle_idx) then
                    match := false;
                    exit;
                end if;
            end loop;
            if match then
                return true;
            end if;
        end loop;

        return false;
    end function;

    procedure send_wire_frame(
        signal clk_i        : in STD_LOGIC;
        signal din_o        : out STD_LOGIC_VECTOR(7 downto 0);
        signal dv_o         : out STD_LOGIC;
        signal dst_valid_i  : in STD_LOGIC;
        signal flag_o       : out STD_LOGIC;
        variable frame_line : inout line
    ) is
        variable byte_v : STD_LOGIC_VECTOR(7 downto 0);
        variable flag_delay : INTEGER := -1;
        variable flag_sent   : BOOLEAN := false;
    begin
        while frame_line.all'length > 0 loop
            hread(frame_line, byte_v);
            din_o <= byte_v;
            dv_o <= '1';
            if dst_valid_i = '1' and flag_delay < 0 then
                flag_delay := INTEGER(FLAG_DELAY_CYCLES);
            end if;

            if flag_delay = 0 and not flag_sent then
                flag_o <= '1';
                flag_sent := true;
            else
                flag_o <= '0';
            end if;

            if flag_delay >= 0 then
                flag_delay := flag_delay - 1;
            end if;

            wait until rising_edge(clk_i);
        end loop;

        dv_o <= '0';
        flag_o <= '0';
        din_o <= (others => '0');
        wait until rising_edge(clk_i);
    end procedure;

begin

    -- ===================================================================
    -- DUT Instantiation
    -- ===================================================================
    u_dut : entity work.frame_handler
        port map(
            clk                   => clk,
            reset                 => reset,
            data_in               => data_in,
            data_valid            => data_valid,
            buffer_dest_port      => buffer_dest_port,
            buffer_dest_port_flag => buffer_dest_port_flag,
            data_out              => data_out,
            dst_port              => dst_port,
            dst_valid             => dst_valid,
            crc_valid             => crc_valid,
            eof_handler           => eof_handler,
            fcs_error             => fcs_error
        );

    -- ===================================================================
    -- Clock Generator
    -- ===================================================================
    clock_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clock_proc;

    -- ===================================================================
    -- Main Test Process
    -- ===================================================================
    test_proc : process
        variable comment_line : line;
        variable frame_line : line;
        variable blank_line : line;
        variable frame_index : NATURAL := 0;
    begin
        -- Reset the DUT
        reset <= '0';
        data_in <= (others => '0');
        data_valid <= '0';
        buffer_dest_port <= (others => '0');
        buffer_dest_port_flag <= '0';
        wait for 3 * CLK_PERIOD;
        reset <= '1';

        wait for 4 * CLK_PERIOD;

        while not endfile(stimulus_file) loop
            readline(stimulus_file, comment_line);

            if comment_line.all'length = 0 then
                next;
            end if;

            if comment_line.all(comment_line.all'low) = '#' then
                frame_index := frame_index + 1;

                if frame_index = 1 then
                    buffer_dest_port <= "0001";
                elsif frame_index = 2 then
                    buffer_dest_port <= "0010";
                else
                    buffer_dest_port <= "0100";
                end if;
                buffer_dest_port_flag <= '0';

                if contains_str(comment_line.all, "Corrupt") then
                    report "Stimulus corrupt frame " & INTEGER'image(frame_index) & ": " & comment_line.all severity note;
                else
                    report "Stimulus valid frame " & INTEGER'image(frame_index) & ": " & comment_line.all severity note;
                end if;

                if not endfile(stimulus_file) then
                    readline(stimulus_file, frame_line);
                    send_wire_frame(
                        clk,
                        data_in,
                        data_valid,
                        dst_valid,
                        buffer_dest_port_flag,
                        frame_line
                    );
                end if;

                -- Inter-frame gap: wait 20 clock cycles
                wait for 20 * CLK_PERIOD;

                if not endfile(stimulus_file) then
                    readline(stimulus_file, blank_line);
                end if;
            end if;
        end loop;

        wait for 10 * CLK_PERIOD;
        report "Finished replaying stimulus.txt" severity note;
        finish;
    end process test_proc;

end architecture tb;
