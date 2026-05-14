LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_voq_rr_crossbar IS
END ENTITY;

ARCHITECTURE sim OF tb_voq_rr_crossbar IS

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';

    SIGNAL flush : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    -- Inputs
    SIGNAL wr_data_in0, wr_data_in1, wr_data_in2, wr_data_in3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL wr_en_in0, wr_en_in1, wr_en_in2, wr_en_in3 : STD_LOGIC;
    SIGNAL wr_eof_in0, wr_eof_in1, wr_eof_in2, wr_eof_in3 : STD_LOGIC;

    -- Outputs
    SIGNAL out_data_0 : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL rr_sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL rr_grant : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL rr_active : STD_LOGIC;

BEGIN

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    dut : ENTITY work.voq_rr_crossbar_top
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => flush,

            wr_data_in0 => wr_data_in0,
            wr_en_in0 => wr_en_in0,
            wr_eof_in0 => wr_eof_in0,

            wr_data_in1 => wr_data_in1,
            wr_en_in1 => wr_en_in1,
            wr_eof_in1 => wr_eof_in1,

            wr_data_in2 => wr_data_in2,
            wr_en_in2 => wr_en_in2,
            wr_eof_in2 => wr_eof_in2,

            wr_data_in3 => wr_data_in3,
            wr_en_in3 => wr_en_in3,
            wr_eof_in3 => wr_eof_in3,

            out_data_0 => out_data_0,

            rr_sel => rr_sel,
            rr_grant => rr_grant,
            rr_active => rr_active,

            frame_rdy_dbg => OPEN,
            rd_eof_dbg => OPEN,
            full_dbg => OPEN,
            empty_dbg => OPEN
        );

    ---------------------------------------------------------------------------
    -- Clock
    ---------------------------------------------------------------------------
    clk <= NOT clk AFTER 5 ns;

    ---------------------------------------------------------------------------
    -- Stimulus
    ---------------------------------------------------------------------------
    PROCESS
    BEGIN
        REPORT "Start TB VOQ + RR + Crossbar" SEVERITY note;

        -- Reset
        WAIT FOR 20 ns;
        reset <= '0';

        -----------------------------------------------------------------------
        -- TEST 1: Single input stream
        -----------------------------------------------------------------------
        REPORT "TEST 1: Input 0 only" SEVERITY note;

        FOR i IN 0 TO 3 LOOP
            WAIT UNTIL rising_edge(clk);
            wr_en_in0 <= '1';
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(i + 1, 8));
            wr_eof_in0 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        wr_data_in0 <= x"AA";
        wr_eof_in0 <= '1';

        WAIT UNTIL rising_edge(clk);
        wr_en_in0 <= '0';
        wr_eof_in0 <= '0';

        WAIT FOR 100 ns;

        -----------------------------------------------------------------------
        -- TEST 2: Two inputs (RR switching)
        -----------------------------------------------------------------------
        REPORT "TEST 2: Input 0 and 1" SEVERITY note;

        FOR i IN 0 TO 2 LOOP
            WAIT UNTIL rising_edge(clk);

            wr_en_in0 <= '1';
            wr_data_in0 <= x"10"; --
            wr_eof_in0 <= '0';

            wr_en_in1 <= '1';
            wr_data_in1 <= x"20";
            wr_eof_in1 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        wr_data_in0 <= x"11";
        wr_eof_in0 <= '1';

        wr_data_in1 <= x"21";
        wr_eof_in1 <= '1';

        WAIT UNTIL rising_edge(clk);
        wr_en_in0 <= '0';
        wr_eof_in0 <= '0';

        wr_en_in1 <= '0';
        wr_eof_in1 <= '0';

        WAIT FOR 150 ns;

        -----------------------------------------------------------------------
        -- TEST 3: All 4 inputs
        -----------------------------------------------------------------------
        REPORT "TEST 3: All inputs active" SEVERITY note;

        FOR i IN 0 TO 1 LOOP
            WAIT UNTIL rising_edge(clk);

            wr_en_in0 <= '1';
            wr_data_in0 <= x"A0";
            wr_eof_in0 <= '0';
            wr_en_in1 <= '1';
            wr_data_in1 <= x"B0";
            wr_eof_in1 <= '0';
            wr_en_in2 <= '1';
            wr_data_in2 <= x"C0";
            wr_eof_in2 <= '0';
            wr_en_in3 <= '1';
            wr_data_in3 <= x"D0";
            wr_eof_in3 <= '0';
        END LOOP;

        WAIT UNTIL rising_edge(clk);
        wr_eof_in0 <= '1';
        wr_eof_in1 <= '1';
        wr_eof_in2 <= '1';
        wr_eof_in3 <= '1';

        WAIT UNTIL rising_edge(clk);
        wr_en_in0 <= '0';
        wr_en_in1 <= '0';
        wr_en_in2 <= '0';
        wr_en_in3 <= '0';

        wr_eof_in0 <= '0';
        wr_eof_in1 <= '0';
        wr_eof_in2 <= '0';
        wr_eof_in3 <= '0';

        WAIT FOR 200 ns;

        -----------------------------------------------------------------------
        REPORT "TB finished" SEVERITY note;
        WAIT;
    END PROCESS;

END ARCHITECTURE;