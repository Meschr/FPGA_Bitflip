LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_voq_rr_crossbar_switch_top IS
END ENTITY;

ARCHITECTURE sim OF tb_voq_rr_crossbar_switch_top IS

    CONSTANT CLK_PERIOD : TIME := 10 ns;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';

    -- Flush je Output-Queue
    SIGNAL flush_out0 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL flush_out1 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL flush_out2 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL flush_out3 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    -- Schreibports: 4 Eingange x 4 Ausgaenge
    SIGNAL wr_data_in0_out0, wr_data_in0_out1, wr_data_in0_out2, wr_data_in0_out3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL wr_data_in1_out0, wr_data_in1_out1, wr_data_in1_out2, wr_data_in1_out3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL wr_data_in2_out0, wr_data_in2_out1, wr_data_in2_out2, wr_data_in2_out3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL wr_data_in3_out0, wr_data_in3_out1, wr_data_in3_out2, wr_data_in3_out3 : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL wr_en_in0_out0, wr_en_in0_out1, wr_en_in0_out2, wr_en_in0_out3 : STD_LOGIC := '0';
    SIGNAL wr_en_in1_out0, wr_en_in1_out1, wr_en_in1_out2, wr_en_in1_out3 : STD_LOGIC := '0';
    SIGNAL wr_en_in2_out0, wr_en_in2_out1, wr_en_in2_out2, wr_en_in2_out3 : STD_LOGIC := '0';
    SIGNAL wr_en_in3_out0, wr_en_in3_out1, wr_en_in3_out2, wr_en_in3_out3 : STD_LOGIC := '0';

    SIGNAL wr_eof_in0_out0, wr_eof_in0_out1, wr_eof_in0_out2, wr_eof_in0_out3 : STD_LOGIC := '0';
    SIGNAL wr_eof_in1_out0, wr_eof_in1_out1, wr_eof_in1_out2, wr_eof_in1_out3 : STD_LOGIC := '0';
    SIGNAL wr_eof_in2_out0, wr_eof_in2_out1, wr_eof_in2_out2, wr_eof_in2_out3 : STD_LOGIC := '0';
    SIGNAL wr_eof_in3_out0, wr_eof_in3_out1, wr_eof_in3_out2, wr_eof_in3_out3 : STD_LOGIC := '0';

    -- Ausgaenge
    SIGNAL out_data_0 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL out_data_1 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL out_data_2 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL out_data_3 : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL out_valid_0 : STD_LOGIC;
    SIGNAL out_valid_1 : STD_LOGIC;
    SIGNAL out_valid_2 : STD_LOGIC;
    SIGNAL out_valid_3 : STD_LOGIC;

BEGIN

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    dut : ENTITY work.voq_rr_crossbar_switch_top
        PORT MAP(
            clk => clk,
            reset => reset,

            flush_out0 => flush_out0,
            flush_out1 => flush_out1,
            flush_out2 => flush_out2,
            flush_out3 => flush_out3,

            wr_data_in0_out0 => wr_data_in0_out0,
            wr_en_in0_out0 => wr_en_in0_out0,
            wr_eof_in0_out0 => wr_eof_in0_out0,

            wr_data_in0_out1 => wr_data_in0_out1,
            wr_en_in0_out1 => wr_en_in0_out1,
            wr_eof_in0_out1 => wr_eof_in0_out1,

            wr_data_in0_out2 => wr_data_in0_out2,
            wr_en_in0_out2 => wr_en_in0_out2,
            wr_eof_in0_out2 => wr_eof_in0_out2,

            wr_data_in0_out3 => wr_data_in0_out3,
            wr_en_in0_out3 => wr_en_in0_out3,
            wr_eof_in0_out3 => wr_eof_in0_out3,

            wr_data_in1_out0 => wr_data_in1_out0,
            wr_en_in1_out0 => wr_en_in1_out0,
            wr_eof_in1_out0 => wr_eof_in1_out0,

            wr_data_in1_out1 => wr_data_in1_out1,
            wr_en_in1_out1 => wr_en_in1_out1,
            wr_eof_in1_out1 => wr_eof_in1_out1,

            wr_data_in1_out2 => wr_data_in1_out2,
            wr_en_in1_out2 => wr_en_in1_out2,
            wr_eof_in1_out2 => wr_eof_in1_out2,

            wr_data_in1_out3 => wr_data_in1_out3,
            wr_en_in1_out3 => wr_en_in1_out3,
            wr_eof_in1_out3 => wr_eof_in1_out3,

            wr_data_in2_out0 => wr_data_in2_out0,
            wr_en_in2_out0 => wr_en_in2_out0,
            wr_eof_in2_out0 => wr_eof_in2_out0,

            wr_data_in2_out1 => wr_data_in2_out1,
            wr_en_in2_out1 => wr_en_in2_out1,
            wr_eof_in2_out1 => wr_eof_in2_out1,

            wr_data_in2_out2 => wr_data_in2_out2,
            wr_en_in2_out2 => wr_en_in2_out2,
            wr_eof_in2_out2 => wr_eof_in2_out2,

            wr_data_in2_out3 => wr_data_in2_out3,
            wr_en_in2_out3 => wr_en_in2_out3,
            wr_eof_in2_out3 => wr_eof_in2_out3,

            wr_data_in3_out0 => wr_data_in3_out0,
            wr_en_in3_out0 => wr_en_in3_out0,
            wr_eof_in3_out0 => wr_eof_in3_out0,

            wr_data_in3_out1 => wr_data_in3_out1,
            wr_en_in3_out1 => wr_en_in3_out1,
            wr_eof_in3_out1 => wr_eof_in3_out1,

            wr_data_in3_out2 => wr_data_in3_out2,
            wr_en_in3_out2 => wr_en_in3_out2,
            wr_eof_in3_out2 => wr_eof_in3_out2,

            wr_data_in3_out3 => wr_data_in3_out3,
            wr_en_in3_out3 => wr_en_in3_out3,
            wr_eof_in3_out3 => wr_eof_in3_out3,

            out_data_0 => out_data_0,
            out_data_1 => out_data_1,
            out_data_2 => out_data_2,
            out_data_3 => out_data_3,

            out_valid_0 => out_valid_0,
            out_valid_1 => out_valid_1,
            out_valid_2 => out_valid_2,
            out_valid_3 => out_valid_3,

            rr_sel_0 => OPEN,
            rr_sel_1 => OPEN,
            rr_sel_2 => OPEN,
            rr_sel_3 => OPEN,

            rr_grant_0 => OPEN,
            rr_grant_1 => OPEN,
            rr_grant_2 => OPEN,
            rr_grant_3 => OPEN,

            rr_active_0 => OPEN,
            rr_active_1 => OPEN,
            rr_active_2 => OPEN,
            rr_active_3 => OPEN,

            frame_rdy_dbg_0 => OPEN,
            frame_rdy_dbg_1 => OPEN,
            frame_rdy_dbg_2 => OPEN,
            frame_rdy_dbg_3 => OPEN,

            rd_eof_dbg_0 => OPEN,
            rd_eof_dbg_1 => OPEN,
            rd_eof_dbg_2 => OPEN,
            rd_eof_dbg_3 => OPEN,

            full_dbg_0 => OPEN,
            full_dbg_1 => OPEN,
            full_dbg_2 => OPEN,
            full_dbg_3 => OPEN,

            empty_dbg_0 => OPEN,
            empty_dbg_1 => OPEN,
            empty_dbg_2 => OPEN,
            empty_dbg_3 => OPEN
        );

    ---------------------------------------------------------------------------
    -- Clock
    ---------------------------------------------------------------------------
    clk <= NOT clk AFTER CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Output Monitor: zeigt ausgehende Daten je Ausgang im Transcript
    ---------------------------------------------------------------------------
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF out_valid_0 = '1' THEN
                REPORT "OUT0 data=" & INTEGER'image(to_integer(unsigned(out_data_0))) SEVERITY note;
            END IF;
            IF out_valid_1 = '1' THEN
                REPORT "OUT1 data=" & INTEGER'image(to_integer(unsigned(out_data_1))) SEVERITY note;
            END IF;
            IF out_valid_2 = '1' THEN
                REPORT "OUT2 data=" & INTEGER'image(to_integer(unsigned(out_data_2))) SEVERITY note;
            END IF;
            IF out_valid_3 = '1' THEN
                REPORT "OUT3 data=" & INTEGER'image(to_integer(unsigned(out_data_3))) SEVERITY note;
            END IF;
        END IF;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- Stimulus
    ---------------------------------------------------------------------------
    PROCESS
    BEGIN
        -- Initialwerte
        wr_data_in0_out0 <= (OTHERS => '0');
        wr_data_in0_out1 <= (OTHERS => '0');
        wr_data_in0_out2 <= (OTHERS => '0');
        wr_data_in0_out3 <= (OTHERS => '0');
        wr_data_in1_out0 <= (OTHERS => '0');
        wr_data_in1_out1 <= (OTHERS => '0');
        wr_data_in1_out2 <= (OTHERS => '0');
        wr_data_in1_out3 <= (OTHERS => '0');
        wr_data_in2_out0 <= (OTHERS => '0');
        wr_data_in2_out1 <= (OTHERS => '0');
        wr_data_in2_out2 <= (OTHERS => '0');
        wr_data_in2_out3 <= (OTHERS => '0');
        wr_data_in3_out0 <= (OTHERS => '0');
        wr_data_in3_out1 <= (OTHERS => '0');
        wr_data_in3_out2 <= (OTHERS => '0');
        wr_data_in3_out3 <= (OTHERS => '0');

        -- Reset
        WAIT FOR 3 * CLK_PERIOD;
        reset <= '0';
        WAIT FOR CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 1: Output 0 bekommt vier unterschiedliche Streams (alle Inputs)
        -- Datenmuster: 0x10.., 0x20.., 0x30.., 0x40..
        -----------------------------------------------------------------------
        REPORT "TEST 1: Output 0, alle Inputs" SEVERITY note;
        FOR i IN 0 TO 3 LOOP
            WAIT UNTIL rising_edge(clk);

            wr_en_in0_out0 <= '1';
            wr_data_in0_out0 <= STD_LOGIC_VECTOR(to_unsigned(16 + i, 8));
            wr_eof_in0_out0 <= '0';

            wr_en_in1_out0 <= '1';
            wr_data_in1_out0 <= STD_LOGIC_VECTOR(to_unsigned(32 + i, 8));
            wr_eof_in1_out0 <= '0';

            wr_en_in2_out0 <= '1';
            wr_data_in2_out0 <= STD_LOGIC_VECTOR(to_unsigned(48 + i, 8));
            wr_eof_in2_out0 <= '0';

            wr_en_in3_out0 <= '1';
            wr_data_in3_out0 <= STD_LOGIC_VECTOR(to_unsigned(64 + i, 8));
            wr_eof_in3_out0 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        wr_data_in0_out0 <= STD_LOGIC_VECTOR(to_unsigned(16 + 4, 8));
        wr_data_in1_out0 <= STD_LOGIC_VECTOR(to_unsigned(32 + 4, 8));
        wr_data_in2_out0 <= STD_LOGIC_VECTOR(to_unsigned(48 + 4, 8));
        wr_data_in3_out0 <= STD_LOGIC_VECTOR(to_unsigned(64 + 4, 8));
        wr_eof_in0_out0 <= '1';
        wr_eof_in1_out0 <= '1';
        wr_eof_in2_out0 <= '1';
        wr_eof_in3_out0 <= '1';

        WAIT UNTIL rising_edge(clk);
        wr_en_in0_out0 <= '0';
        wr_eof_in0_out0 <= '0';
        wr_en_in1_out0 <= '0';
        wr_eof_in1_out0 <= '0';
        wr_en_in2_out0 <= '0';
        wr_eof_in2_out0 <= '0';
        wr_en_in3_out0 <= '0';
        wr_eof_in3_out0 <= '0';

        WAIT FOR 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 2: Output 1 bekommt zwei Streams (Input 0 und 2)
        -- Datenmuster: 0x50.. und 0x70..
        -----------------------------------------------------------------------
        REPORT "TEST 2: Output 1, Inputs 0 und 2" SEVERITY note;
        FOR i IN 0 TO 2 LOOP
            WAIT UNTIL rising_edge(clk);

            wr_en_in0_out1 <= '1';
            wr_data_in0_out1 <= STD_LOGIC_VECTOR(to_unsigned(80 + i, 8));
            wr_eof_in0_out1 <= '0';

            wr_en_in2_out1 <= '1';
            wr_data_in2_out1 <= STD_LOGIC_VECTOR(to_unsigned(112 + i, 8));
            wr_eof_in2_out1 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        wr_data_in0_out1 <= STD_LOGIC_VECTOR(to_unsigned(80 + 3, 8));
        wr_data_in2_out1 <= STD_LOGIC_VECTOR(to_unsigned(112 + 3, 8));
        wr_eof_in0_out1 <= '1';
        wr_eof_in2_out1 <= '1';

        WAIT UNTIL rising_edge(clk);
        wr_en_in0_out1 <= '0';
        wr_eof_in0_out1 <= '0';
        wr_en_in2_out1 <= '0';
        wr_eof_in2_out1 <= '0';

        WAIT FOR 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 3: Output 2 bekommt nur Input 3
        -- Datenmuster: 0x90..
        -----------------------------------------------------------------------
        REPORT "TEST 3: Output 2, Input 3" SEVERITY note;
        FOR i IN 0 TO 2 LOOP
            WAIT UNTIL rising_edge(clk);
            wr_en_in3_out2 <= '1';
            wr_data_in3_out2 <= STD_LOGIC_VECTOR(to_unsigned(144 + i, 8));
            wr_eof_in3_out2 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        wr_data_in3_out2 <= STD_LOGIC_VECTOR(to_unsigned(144 + 3, 8));
        wr_eof_in3_out2 <= '1';

        WAIT UNTIL rising_edge(clk);
        wr_en_in3_out2 <= '0';
        wr_eof_in3_out2 <= '0';

        WAIT FOR 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 4: Output 3 bekommt Input 1 und 2
        -- Datenmuster: 0xA0.. und 0xB0..
        -----------------------------------------------------------------------
        REPORT "TEST 4: Output 3, Inputs 1 und 2" SEVERITY note;
        FOR i IN 0 TO 1 LOOP
            WAIT UNTIL rising_edge(clk);
            wr_en_in1_out3 <= '1';
            wr_data_in1_out3 <= STD_LOGIC_VECTOR(to_unsigned(160 + i, 8));
            wr_eof_in1_out3 <= '0';

            wr_en_in2_out3 <= '1';
            wr_data_in2_out3 <= STD_LOGIC_VECTOR(to_unsigned(176 + i, 8));
            wr_eof_in2_out3 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        wr_data_in1_out3 <= STD_LOGIC_VECTOR(to_unsigned(160 + 2, 8));
        wr_data_in2_out3 <= STD_LOGIC_VECTOR(to_unsigned(176 + 2, 8));
        wr_eof_in1_out3 <= '1';
        wr_eof_in2_out3 <= '1';

        WAIT UNTIL rising_edge(clk);
        wr_en_in1_out3 <= '0';
        wr_eof_in1_out3 <= '0';
        wr_en_in2_out3 <= '0';
        wr_eof_in2_out3 <= '0';

        WAIT FOR 50 * CLK_PERIOD;

        REPORT "TB finished" SEVERITY note;
        WAIT;
    END PROCESS;

END ARCHITECTURE;