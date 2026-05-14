LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_textio.ALL;

LIBRARY std;
USE std.textio.ALL;
USE std.env.ALL;

ENTITY tb_new_frame_handler IS
END ENTITY tb_new_frame_handler;

ARCHITECTURE tb OF tb_new_frame_handler IS

    -- Clock period
    CONSTANT CLK_PERIOD : TIME := 10 ns;

    -- Signals for DUT ports
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';

    -- Inputs to frame_handler
    SIGNAL data_in : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_valid : STD_LOGIC := '0';
    SIGNAL buffer_dest_port : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL buffer_dest_port_flag : STD_LOGIC := '0';

    -- Outputs from frame_handler
    SIGNAL data_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL dst_port : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL crc_valid : STD_LOGIC;
    SIGNAL eof_handler : STD_LOGIC;
    SIGNAL frame_rdy_handler : STD_LOGIC;
    SIGNAL full_buffer : STD_LOGIC_VECTOR(3 DOWNTO 0);

    FILE stimulus_file : text OPEN read_mode IS "src/FrameParser/src/stimulus.txt";

    FUNCTION contains_str(source : STRING; needle : STRING) RETURN BOOLEAN IS
        VARIABLE match : BOOLEAN;
    BEGIN
        IF needle'length = 0 THEN
            RETURN true;
        END IF;

        IF source'length < needle'length THEN
            RETURN false;
        END IF;

        FOR start_idx IN source'low TO source'high - needle'length + 1 LOOP
            match := true;
            FOR needle_idx IN needle'RANGE LOOP
                IF source(start_idx + (needle_idx - needle'low)) /= needle(needle_idx) THEN
                    match := false;
                    EXIT;
                END IF;
            END LOOP;
            IF match THEN
                RETURN true;
            END IF;
        END LOOP;

        RETURN false;
    END FUNCTION;

    PROCEDURE send_wire_frame(
        SIGNAL clk_i : IN STD_LOGIC;
        SIGNAL din_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        SIGNAL dv_o : OUT STD_LOGIC;
        VARIABLE frame_line : INOUT line
    ) IS
        VARIABLE byte_v : STD_LOGIC_VECTOR(7 DOWNTO 0);
    BEGIN
        WHILE frame_line.ALL'length > 0 LOOP
            hread(frame_line, byte_v);
            din_o <= byte_v;
            dv_o <= '1';
            WAIT UNTIL rising_edge(clk_i);
        END LOOP;

        dv_o <= '0';
        din_o <= (OTHERS => '0');
        WAIT UNTIL rising_edge(clk_i);
    END PROCEDURE;

BEGIN

    -- ===================================================================
    -- DUT Instantiation
    -- ===================================================================
    u_dut : ENTITY work.frame_handler
        PORT MAP(
            clk => clk,
            reset => reset,
            data_in => data_in,
            data_valid => data_valid,
            buffer_dest_port => buffer_dest_port,
            buffer_dest_port_flag => buffer_dest_port_flag,
            data_out => data_out,
            dst_port => dst_port,
            crc_valid => crc_valid,
            eof_handler => eof_handler,
            frame_rdy => frame_rdy_handler,
            full_buffer => full_buffer
        );

    -- ===================================================================
    -- Clock Generator
    -- ===================================================================
    clock_proc : PROCESS
    BEGIN
        clk <= '0';
        WAIT FOR CLK_PERIOD / 2;
        clk <= '1';
        WAIT FOR CLK_PERIOD / 2;
    END PROCESS clock_proc;

    -- ===================================================================
    -- Main Test Process
    -- ===================================================================
    test_proc : PROCESS
        VARIABLE comment_line : line;
        VARIABLE frame_line : line;
        VARIABLE blank_line : line;
        VARIABLE frame_index : NATURAL := 0;
    BEGIN
        -- Reset the DUT
        reset <= '0';
        data_in <= (OTHERS => '0');
        data_valid <= '0';
        buffer_dest_port <= (OTHERS => '0');
        buffer_dest_port_flag <= '0';
        WAIT FOR 3 * CLK_PERIOD;
        reset <= '1';

        WAIT FOR 4 * CLK_PERIOD;

        WHILE NOT endfile(stimulus_file) LOOP
            readline(stimulus_file, comment_line);

            IF comment_line.ALL'length = 0 THEN
                NEXT;
            END IF;

            IF comment_line.ALL(comment_line.ALL'low) = '#' THEN
                frame_index := frame_index + 1;

                IF frame_index = 1 THEN
                    buffer_dest_port <= "0001";
                ELSIF frame_index = 2 THEN
                    buffer_dest_port <= "0010";
                ELSE
                    buffer_dest_port <= "0100";
                END IF;
                buffer_dest_port_flag <= '1';
                WAIT UNTIL rising_edge(clk);
                buffer_dest_port_flag <= '0';

                IF contains_str(comment_line.ALL, "Corrupt") THEN
                    REPORT "Stimulus corrupt frame " & INTEGER'image(frame_index) & ": " & comment_line.ALL SEVERITY note;
                ELSE
                    REPORT "Stimulus valid frame " & INTEGER'image(frame_index) & ": " & comment_line.ALL SEVERITY note;
                END IF;

                IF NOT endfile(stimulus_file) THEN
                    readline(stimulus_file, frame_line);
                    send_wire_frame(clk, data_in, data_valid, frame_line);
                END IF;

                -- Inter-frame gap: wait 20 clock cycles
                WAIT FOR 20 * CLK_PERIOD;

                IF NOT endfile(stimulus_file) THEN
                    readline(stimulus_file, blank_line);
                END IF;
            END IF;
        END LOOP;

        WAIT FOR 10 * CLK_PERIOD;
        REPORT "Finished replaying stimulus.txt" SEVERITY note;
        finish;
    END PROCESS test_proc;

END ARCHITECTURE tb;