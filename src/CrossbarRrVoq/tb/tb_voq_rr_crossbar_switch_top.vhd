LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_voq_rr_crossbar_switch_top IS
END ENTITY;

ARCHITECTURE sim OF tb_voq_rr_crossbar_switch_top IS

    CONSTANT CLK_PERIOD : TIME := 10 ns;
    CONSTANT LEN_T1 : INTEGER := 24;
    CONSTANT LEN_T2 : INTEGER := 20;
    CONSTANT LEN_T3 : INTEGER := 20;
    CONSTANT LEN_T4 : INTEGER := 18;
    CONSTANT LEN_T5 : INTEGER := 16;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';

    -- Flush je Output-Queue
    SIGNAL flush_out0 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL flush_out1 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL flush_out2 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL flush_out3 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    -- Schreibports: 4 Eingange
    SIGNAL wr_data_in0, wr_data_in1, wr_data_in2, wr_data_in3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL wr_en_in0, wr_en_in1, wr_en_in2, wr_en_in3 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL wr_eof_in0, wr_eof_in1, wr_eof_in2, wr_eof_in3 : STD_LOGIC := '0';
    SIGNAL wr_abort_in0, wr_abort_in1, wr_abort_in2, wr_abort_in3 : STD_LOGIC := '0';

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

            wr_en_in0 => wr_en_in0,
            wr_data_in0 => wr_data_in0,
            wr_eof_in0 => wr_eof_in0,
            wr_abort_in0 => wr_abort_in0,

            wr_en_in1 => wr_en_in1,
            wr_data_in1 => wr_data_in1,
            wr_eof_in1 => wr_eof_in1,
            wr_abort_in1 => wr_abort_in1,

            wr_en_in2 => wr_en_in2,
            wr_data_in2 => wr_data_in2,
            wr_eof_in2 => wr_eof_in2,
            wr_abort_in2 => wr_abort_in2,

            wr_en_in3 => wr_en_in3,
            wr_data_in3 => wr_data_in3,
            wr_eof_in3 => wr_eof_in3,
            wr_abort_in3 => wr_abort_in3,

            out_data_0 => out_data_0,
            out_data_1 => out_data_1,
            out_data_2 => out_data_2,
            out_data_3 => out_data_3,

            out_valid_0 => out_valid_0,
            out_valid_1 => out_valid_1,
            out_valid_2 => out_valid_2,
            out_valid_3 => out_valid_3
        );

    ---------------------------------------------------------------------------
    -- Clock
    ---------------------------------------------------------------------------
    clk <= NOT clk AFTER CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Output Monitor: zeigt ausgehende Daten je Ausgang im Transcript
    ---------------------------------------------------------------------------
    process(all)
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
        variable abort0_sent : boolean := false;
        variable abort1_sent : boolean := false;
        variable abort2_sent : boolean := false;
        variable abort3_sent : boolean := false;
        variable abort0_enable : boolean := false;
        variable abort1_enable : boolean := false;
        variable abort2_enable : boolean := false;
        variable abort3_enable : boolean := false;
    BEGIN
        -- Initialwerte
        wr_data_in0 <= (OTHERS => '0');
        wr_data_in1 <= (OTHERS => '0');
        wr_data_in2 <= (OTHERS => '0');
        wr_data_in3 <= (OTHERS => '0');

        -- Reset (active low)
        WAIT FOR 3 * CLK_PERIOD;
        reset <= '0';
        WAIT FOR CLK_PERIOD;
        reset <= '1';
        WAIT FOR CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 1: Output 0 bekommt vier unterschiedliche Streams (alle Inputs)
        -- Datenmuster: 0x10.., 0x20.., 0x30.., 0x40..
        -----------------------------------------------------------------------
        REPORT "TEST 1: Output 0, alle Inputs" SEVERITY note;
        abort0_sent := false;
        abort1_sent := false;
        abort2_sent := false;
        abort3_sent := false;
        abort0_enable := true;
        abort1_enable := false;
        abort2_enable := false;
        abort3_enable := false;

        FOR i IN 0 TO LEN_T1 - 1 LOOP
            WAIT UNTIL rising_edge(clk);

            if abort0_sent then
                wr_en_in0 <= (OTHERS => '0');
                wr_data_in0 <= (OTHERS => '0');
                wr_eof_in0 <= '0';
                wr_abort_in0 <= '0';
            else
                wr_en_in0 <= "0001";
                wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + i, 8));
                wr_eof_in0 <= '0';
                if abort0_enable and i = LEN_T1 - 2 then
                    wr_abort_in0 <= '1';
                    abort0_sent := true;
                else
                    wr_abort_in0 <= '0';
                end if;
            end if;

            wr_en_in1 <= "0001";
            wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + i, 8));
            wr_eof_in1 <= '0';

            wr_en_in2 <= "0001";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + i, 8));
            wr_eof_in2 <= '0';

            wr_en_in3 <= "0001";
            wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + i, 8));
            wr_eof_in3 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        if abort0_sent then
            wr_en_in0 <= (OTHERS => '0');
            wr_data_in0 <= (OTHERS => '0');
            wr_eof_in0 <= '0';
        else
            wr_en_in0 <= "0001";
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + 16, 8));
            wr_eof_in0 <= '1';
        end if;
        wr_en_in1 <= "0001";
        wr_en_in2 <= "0001";
        wr_en_in3 <= "0001";
        wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + LEN_T1, 8));
        wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + LEN_T1, 8));
        wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + LEN_T1, 8));
        wr_eof_in1 <= '1';
        wr_eof_in2 <= '1';
        wr_eof_in3 <= '1';
        wr_abort_in0 <= '0';

        WAIT UNTIL rising_edge(clk);
        wr_en_in0 <= (OTHERS => '0');
        wr_eof_in0 <= '0';
        wr_abort_in0 <= '0';
        wr_en_in1 <= (OTHERS => '0');
        wr_eof_in1 <= '0';
        wr_en_in2 <= (OTHERS => '0');
        wr_eof_in2 <= '0';
        wr_en_in3 <= (OTHERS => '0');
        wr_eof_in3 <= '0';

        WAIT FOR 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 2: Output 1 bekommt zwei Streams (Input 0 und 2)
        -- Datenmuster: 0x50.. und 0x70..
        -----------------------------------------------------------------------
        REPORT "TEST 2: Output 1, Inputs 0 und 2" SEVERITY note;
        abort0_sent := false;
        abort2_sent := false;
        abort0_enable := false;
        abort2_enable := true;

        FOR i IN 0 TO LEN_T2 - 1 LOOP
            WAIT UNTIL rising_edge(clk);

            if abort0_sent then
                wr_en_in0 <= (OTHERS => '0');
                wr_data_in0 <= (OTHERS => '0');
                wr_eof_in0 <= '0';
            else
                wr_en_in0 <= "0010";
                wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(80 + i, 8));
                wr_eof_in0 <= '0';
            end if;

            if abort2_sent then
                wr_en_in2 <= (OTHERS => '0');
                wr_data_in2 <= (OTHERS => '0');
                wr_eof_in2 <= '0';
                wr_abort_in2 <= '0';
            else
                wr_en_in2 <= "0010";
                wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(112 + i, 8));
                wr_eof_in2 <= '0';
                if abort2_enable and i = LEN_T2 - 2 then
                    wr_abort_in2 <= '1';
                    abort2_sent := true;
                else
                    wr_abort_in2 <= '0';
                end if;
            end if;
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        if abort0_sent then
            wr_en_in0 <= (OTHERS => '0');
            wr_data_in0 <= (OTHERS => '0');
            wr_eof_in0 <= '0';
        else
            wr_en_in0 <= "0010";
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(80 + LEN_T2, 8));
            wr_eof_in0 <= '1';
        end if;

        if abort2_sent then
            wr_en_in2 <= (OTHERS => '0');
            wr_data_in2 <= (OTHERS => '0');
            wr_eof_in2 <= '0';
        else
            wr_en_in2 <= "0010";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(112 + LEN_T2, 8));
            wr_eof_in2 <= '1';
        end if;
        wr_abort_in2 <= '0';

        WAIT UNTIL rising_edge(clk);
        wr_en_in0 <= (OTHERS => '0');
        wr_eof_in0 <= '0';
        wr_en_in2 <= (OTHERS => '0');
        wr_eof_in2 <= '0';

        WAIT FOR 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 3: Output 2 bekommt nur Input 3
        -- Datenmuster: 0x90..
        -----------------------------------------------------------------------
        REPORT "TEST 3: Output 2, Input 3" SEVERITY note;
        abort3_sent := false;
        abort3_enable := true;

        FOR i IN 0 TO LEN_T3 - 1 LOOP
            WAIT UNTIL rising_edge(clk);
            if abort3_sent then
                wr_en_in3 <= (OTHERS => '0');
                wr_data_in3 <= (OTHERS => '0');
                wr_eof_in3 <= '0';
            else
                wr_en_in3 <= "0100";
                wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(144 + i, 8));
                wr_eof_in3 <= '0';
                if abort3_enable and i = LEN_T3 - 2 then
                    wr_abort_in3 <= '1';
                    abort3_sent := true;
                else
                    wr_abort_in3 <= '0';
                end if;
            end if;
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        if abort3_sent then
            wr_en_in3 <= (OTHERS => '0');
            wr_data_in3 <= (OTHERS => '0');
            wr_eof_in3 <= '0';
        else
            wr_en_in3 <= "0100";
            wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(144 + LEN_T3, 8));
            wr_eof_in3 <= '1';
        end if;
        wr_abort_in3 <= '0';

        WAIT UNTIL rising_edge(clk);
        wr_en_in3 <= (OTHERS => '0');
        wr_eof_in3 <= '0';

        WAIT FOR 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 4: Output 3 bekommt Input 1 und 2
        -- Datenmuster: 0xA0.. und 0xB0..
        -----------------------------------------------------------------------
        REPORT "TEST 4: Output 3, Inputs 1 und 2" SEVERITY note;
        abort1_sent := false;
        abort1_enable := true;

        FOR i IN 0 TO LEN_T4 - 1 LOOP
            WAIT UNTIL rising_edge(clk);
            if abort1_sent then
                wr_en_in1 <= (OTHERS => '0');
                wr_data_in1 <= (OTHERS => '0');
                wr_eof_in1 <= '0';
            else
                wr_en_in1 <= "1000";
                wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(160 + i, 8));
                wr_eof_in1 <= '0';
                if abort1_enable and i = LEN_T4 - 2 then
                    wr_abort_in1 <= '1';
                    abort1_sent := true;
                else
                    wr_abort_in1 <= '0';
                end if;
            end if;

            wr_en_in2 <= "1000";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(176 + i, 8));
            wr_eof_in2 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        if abort1_sent then
            wr_en_in1 <= (OTHERS => '0');
            wr_data_in1 <= (OTHERS => '0');
            wr_eof_in1 <= '0';
        else
            wr_en_in1 <= "1000";
            wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(160 + LEN_T4, 8));
            wr_eof_in1 <= '1';
        end if;

        wr_en_in2 <= "1000";
        wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(176 + LEN_T4, 8));
        wr_eof_in2 <= '1';
        wr_abort_in1 <= '0';

        WAIT UNTIL rising_edge(clk);
        wr_en_in1 <= (OTHERS => '0');
        wr_eof_in1 <= '0';
        wr_en_in2 <= (OTHERS => '0');
        wr_eof_in2 <= '0';

        WAIT FOR 50 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 5: Output 0, gemischte Frames im Wechsel (Abort/OK)
        -----------------------------------------------------------------------
        REPORT "TEST 5: Output 0, alternating abort/ok" SEVERITY note;

        abort0_sent := false;
        abort1_sent := false;
        abort2_sent := false;
        abort3_sent := false;
        abort0_enable := true;
        abort1_enable := false;
        abort2_enable := true;
        abort3_enable := false;

        FOR i IN 0 TO LEN_T5 - 1 LOOP
            WAIT UNTIL rising_edge(clk);

            if abort0_sent then
                wr_en_in0 <= (OTHERS => '0');
                wr_data_in0 <= (OTHERS => '0');
                wr_eof_in0 <= '0';
                wr_abort_in0 <= '0';
            else
                wr_en_in0 <= "0001";
                wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + i, 8));
                wr_eof_in0 <= '0';
                if abort0_enable and i = LEN_T5 - 2 then
                    wr_abort_in0 <= '1';
                    abort0_sent := true;
                else
                    wr_abort_in0 <= '0';
                end if;
            end if;

            if abort1_sent then
                wr_en_in1 <= (OTHERS => '0');
                wr_data_in1 <= (OTHERS => '0');
                wr_eof_in1 <= '0';
                wr_abort_in1 <= '0';
            else
                wr_en_in1 <= "0001";
                wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + i, 8));
                wr_eof_in1 <= '0';
                if abort1_enable and i = LEN_T5 - 2 then
                    wr_abort_in1 <= '1';
                    abort1_sent := true;
                else
                    wr_abort_in1 <= '0';
                end if;
            end if;

            if abort2_sent then
                wr_en_in2 <= (OTHERS => '0');
                wr_data_in2 <= (OTHERS => '0');
                wr_eof_in2 <= '0';
                wr_abort_in2 <= '0';
            else
                wr_en_in2 <= "0001";
                wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + i, 8));
                wr_eof_in2 <= '0';
                if abort2_enable and i = LEN_T5 - 2 then
                    wr_abort_in2 <= '1';
                    abort2_sent := true;
                else
                    wr_abort_in2 <= '0';
                end if;
            end if;

            if abort3_sent then
                wr_en_in3 <= (OTHERS => '0');
                wr_data_in3 <= (OTHERS => '0');
                wr_eof_in3 <= '0';
                wr_abort_in3 <= '0';
            else
                wr_en_in3 <= "0001";
                wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + i, 8));
                wr_eof_in3 <= '0';
                if abort3_enable and i = LEN_T5 - 2 then
                    wr_abort_in3 <= '1';
                    abort3_sent := true;
                else
                    wr_abort_in3 <= '0';
                end if;
            end if;
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        if abort0_sent then
            wr_en_in0 <= (OTHERS => '0');
            wr_data_in0 <= (OTHERS => '0');
            wr_eof_in0 <= '0';
        else
            wr_en_in0 <= "0001";
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + LEN_T5, 8));
            wr_eof_in0 <= '1';
        end if;

        if abort1_sent then
            wr_en_in1 <= (OTHERS => '0');
            wr_data_in1 <= (OTHERS => '0');
            wr_eof_in1 <= '0';
        else
            wr_en_in1 <= "0001";
            wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + LEN_T5, 8));
            wr_eof_in1 <= '1';
        end if;

        if abort2_sent then
            wr_en_in2 <= (OTHERS => '0');
            wr_data_in2 <= (OTHERS => '0');
            wr_eof_in2 <= '0';
        else
            wr_en_in2 <= "0001";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + LEN_T5, 8));
            wr_eof_in2 <= '1';
        end if;

        if abort3_sent then
            wr_en_in3 <= (OTHERS => '0');
            wr_data_in3 <= (OTHERS => '0');
            wr_eof_in3 <= '0';
        else
            wr_en_in3 <= "0001";
            wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + LEN_T5, 8));
            wr_eof_in3 <= '1';
        end if;

        WAIT UNTIL rising_edge(clk);
        wr_en_in0 <= (OTHERS => '0');
        wr_eof_in0 <= '0';
        wr_abort_in0 <= '0';
        wr_en_in1 <= (OTHERS => '0');
        wr_eof_in1 <= '0';
        wr_abort_in1 <= '0';
        wr_en_in2 <= (OTHERS => '0');
        wr_eof_in2 <= '0';
        wr_abort_in2 <= '0';
        wr_en_in3 <= (OTHERS => '0');
        wr_eof_in3 <= '0';
        wr_abort_in3 <= '0';

        WAIT FOR 20 * CLK_PERIOD;

        abort0_sent := false;
        abort1_sent := false;
        abort2_sent := false;
        abort3_sent := false;
        abort0_enable := false;
        abort1_enable := true;
        abort2_enable := false;
        abort3_enable := true;

        FOR i IN 0 TO LEN_T5 - 1 LOOP
            WAIT UNTIL rising_edge(clk);

            if abort0_sent then
                wr_en_in0 <= (OTHERS => '0');
                wr_data_in0 <= (OTHERS => '0');
                wr_eof_in0 <= '0';
                wr_abort_in0 <= '0';
            else
                wr_en_in0 <= "0001";
                wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + i, 8));
                wr_eof_in0 <= '0';
                if abort0_enable and i = LEN_T5 - 2 then
                    wr_abort_in0 <= '1';
                    abort0_sent := true;
                else
                    wr_abort_in0 <= '0';
                end if;
            end if;

            if abort1_sent then
                wr_en_in1 <= (OTHERS => '0');
                wr_data_in1 <= (OTHERS => '0');
                wr_eof_in1 <= '0';
                wr_abort_in1 <= '0';
            else
                wr_en_in1 <= "0001";
                wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + i, 8));
                wr_eof_in1 <= '0';
                if abort1_enable and i = LEN_T5 - 2 then
                    wr_abort_in1 <= '1';
                    abort1_sent := true;
                else
                    wr_abort_in1 <= '0';
                end if;
            end if;

            if abort2_sent then
                wr_en_in2 <= (OTHERS => '0');
                wr_data_in2 <= (OTHERS => '0');
                wr_eof_in2 <= '0';
                wr_abort_in2 <= '0';
            else
                wr_en_in2 <= "0001";
                wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + i, 8));
                wr_eof_in2 <= '0';
                if abort2_enable and i = LEN_T5 - 2 then
                    wr_abort_in2 <= '1';
                    abort2_sent := true;
                else
                    wr_abort_in2 <= '0';
                end if;
            end if;

            if abort3_sent then
                wr_en_in3 <= (OTHERS => '0');
                wr_data_in3 <= (OTHERS => '0');
                wr_eof_in3 <= '0';
                wr_abort_in3 <= '0';
            else
                wr_en_in3 <= "0001";
                wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + i, 8));
                wr_eof_in3 <= '0';
                if abort3_enable and i = LEN_T5 - 2 then
                    wr_abort_in3 <= '1';
                    abort3_sent := true;
                else
                    wr_abort_in3 <= '0';
                end if;
            end if;
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        if abort0_sent then
            wr_en_in0 <= (OTHERS => '0');
            wr_data_in0 <= (OTHERS => '0');
            wr_eof_in0 <= '0';
        else
            wr_en_in0 <= "0001";
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + LEN_T5, 8));
            wr_eof_in0 <= '1';
        end if;

        if abort1_sent then
            wr_en_in1 <= (OTHERS => '0');
            wr_data_in1 <= (OTHERS => '0');
            wr_eof_in1 <= '0';
        else
            wr_en_in1 <= "0001";
            wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + LEN_T5, 8));
            wr_eof_in1 <= '1';
        end if;

        if abort2_sent then
            wr_en_in2 <= (OTHERS => '0');
            wr_data_in2 <= (OTHERS => '0');
            wr_eof_in2 <= '0';
        else
            wr_en_in2 <= "0001";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + LEN_T5, 8));
            wr_eof_in2 <= '1';
        end if;

        if abort3_sent then
            wr_en_in3 <= (OTHERS => '0');
            wr_data_in3 <= (OTHERS => '0');
            wr_eof_in3 <= '0';
        else
            wr_en_in3 <= "0001";
            wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + LEN_T5, 8));
            wr_eof_in3 <= '1';
        end if;

        WAIT UNTIL rising_edge(clk);
        wr_en_in0 <= (OTHERS => '0');
        wr_eof_in0 <= '0';
        wr_abort_in0 <= '0';
        wr_en_in1 <= (OTHERS => '0');
        wr_eof_in1 <= '0';
        wr_abort_in1 <= '0';
        wr_en_in2 <= (OTHERS => '0');
        wr_eof_in2 <= '0';
        wr_abort_in2 <= '0';
        wr_en_in3 <= (OTHERS => '0');
        wr_eof_in3 <= '0';
        wr_abort_in3 <= '0';

        REPORT "TB finished" SEVERITY note;
        WAIT;
    END PROCESS;

END ARCHITECTURE;