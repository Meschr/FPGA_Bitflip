library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_voq_rr_crossbar_switch_top is
end entity;

architecture sim of tb_voq_rr_crossbar_switch_top is

    constant CLK_PERIOD : TIME    := 10 ns;
    constant LEN_T1     : INTEGER := 24;
    constant LEN_T2     : INTEGER := 20;
    constant LEN_T3     : INTEGER := 20;
    constant LEN_T4     : INTEGER := 18;
    constant LEN_T5     : INTEGER := 16;

    signal clk   : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '0';

    -- Flush je Output-Queue
    signal flush_out0 : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal flush_out1 : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal flush_out2 : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal flush_out3 : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

    -- Schreibports: 4 Eingange
    signal wr_data_in0, wr_data_in1, wr_data_in2, wr_data_in3     : STD_LOGIC_VECTOR(7 downto 0);
    signal wr_en_in0, wr_en_in1, wr_en_in2, wr_en_in3             : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal wr_eof_in0, wr_eof_in1, wr_eof_in2, wr_eof_in3         : STD_LOGIC                    := '0';
    signal wr_abort_in0, wr_abort_in1, wr_abort_in2, wr_abort_in3 : STD_LOGIC                    := '0';

    -- Ausgaenge
    signal out_data_0 : STD_LOGIC_VECTOR(7 downto 0);
    signal out_data_1 : STD_LOGIC_VECTOR(7 downto 0);
    signal out_data_2 : STD_LOGIC_VECTOR(7 downto 0);
    signal out_data_3 : STD_LOGIC_VECTOR(7 downto 0);

    signal out_valid_0 : STD_LOGIC;
    signal out_valid_1 : STD_LOGIC;
    signal out_valid_2 : STD_LOGIC;
    signal out_valid_3 : STD_LOGIC;

begin

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    dut : entity work.voq_rr_crossbar_switch_top
        port map(
            clk   => clk,
            reset => reset,

            flush_out0 => flush_out0,
            flush_out1 => flush_out1,
            flush_out2 => flush_out2,
            flush_out3 => flush_out3,

            wr_en_in0    => wr_en_in0,
            wr_data_in0  => wr_data_in0,
            wr_eof_in0   => wr_eof_in0,
            wr_abort_in0 => wr_abort_in0,

            wr_en_in1    => wr_en_in1,
            wr_data_in1  => wr_data_in1,
            wr_eof_in1   => wr_eof_in1,
            wr_abort_in1 => wr_abort_in1,

            wr_en_in2    => wr_en_in2,
            wr_data_in2  => wr_data_in2,
            wr_eof_in2   => wr_eof_in2,
            wr_abort_in2 => wr_abort_in2,

            wr_en_in3    => wr_en_in3,
            wr_data_in3  => wr_data_in3,
            wr_eof_in3   => wr_eof_in3,
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
    clk <= not clk after CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Output Monitor: zeigt ausgehende Daten je Ausgang im Transcript
    ---------------------------------------------------------------------------
    process (all)
    begin
        if rising_edge(clk) then
            if out_valid_0 = '1' then
                report "OUT0 data=" & INTEGER'image(to_integer(unsigned(out_data_0))) severity note;
            end if;
            if out_valid_1 = '1' then
                report "OUT1 data=" & INTEGER'image(to_integer(unsigned(out_data_1))) severity note;
            end if;
            if out_valid_2 = '1' then
                report "OUT2 data=" & INTEGER'image(to_integer(unsigned(out_data_2))) severity note;
            end if;
            if out_valid_3 = '1' then
                report "OUT3 data=" & INTEGER'image(to_integer(unsigned(out_data_3))) severity note;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Stimulus
    ---------------------------------------------------------------------------
    process
        variable abort0_sent   : BOOLEAN := false;
        variable abort1_sent   : BOOLEAN := false;
        variable abort2_sent   : BOOLEAN := false;
        variable abort3_sent   : BOOLEAN := false;
        variable abort0_enable : BOOLEAN := false;
        variable abort1_enable : BOOLEAN := false;
        variable abort2_enable : BOOLEAN := false;
        variable abort3_enable : BOOLEAN := false;
    begin
        -- Initialwerte
        wr_data_in0 <= (others => '0');
        wr_data_in1 <= (others => '0');
        wr_data_in2 <= (others => '0');
        wr_data_in3 <= (others => '0');

        -- Reset (active low)
        wait for 3 * CLK_PERIOD;
        reset <= '0';
        WAIT FOR CLK_PERIOD;
        reset <= '1';
        wait for CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 1: Output 0 bekommt vier unterschiedliche Streams (alle Inputs)
        -- Datenmuster: 0x10.., 0x20.., 0x30.., 0x40..
        -----------------------------------------------------------------------
        report "TEST 1: Output 0, alle Inputs" severity note;
        abort0_sent   := false;
        abort1_sent   := false;
        abort2_sent   := false;
        abort3_sent   := false;
        abort0_enable := true;
        abort1_enable := false;
        abort2_enable := false;
        abort3_enable := false;

        for i in 0 to LEN_T1 - 1 loop
            wait until rising_edge(clk);

            if abort0_sent then
                wr_en_in0    <= (others => '0');
                wr_data_in0  <= (others => '0');
                wr_eof_in0   <= '0';
                wr_abort_in0 <= '0';
            else
                wr_en_in0   <= "0001";
                wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + i, 8));
                wr_eof_in0  <= '0';
                if abort0_enable and i = LEN_T1 - 2 then
                    wr_abort_in0 <= '1';
                    abort0_sent := true;
                else
                    wr_abort_in0 <= '0';
                end if;
            end if;

            wr_en_in1   <= "0001";
            wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + i, 8));
            wr_eof_in1  <= '0';

            wr_en_in2   <= "0001";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + i, 8));
            wr_eof_in2  <= '0';

            wr_en_in3   <= "0001";
            wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + i, 8));
            wr_eof_in3  <= '0';
        end loop;

        wait until rising_edge(clk);
        if abort0_sent then
            wr_en_in0   <= (others => '0');
            wr_data_in0 <= (others => '0');
            wr_eof_in0  <= '0';
        else
            wr_en_in0   <= "0001";
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + 16, 8));
            wr_eof_in0  <= '1';
        end if;
        wr_en_in1    <= "0001";
        wr_en_in2    <= "0001";
        wr_en_in3    <= "0001";
        wr_data_in1  <= STD_LOGIC_VECTOR(to_unsigned(32 + LEN_T1, 8));
        wr_data_in2  <= STD_LOGIC_VECTOR(to_unsigned(48 + LEN_T1, 8));
        wr_data_in3  <= STD_LOGIC_VECTOR(to_unsigned(64 + LEN_T1, 8));
        wr_eof_in1   <= '1';
        wr_eof_in2   <= '1';
        wr_eof_in3   <= '1';
        wr_abort_in0 <= '0';

        wait until rising_edge(clk);
        wr_en_in0    <= (others => '0');
        wr_eof_in0   <= '0';
        wr_abort_in0 <= '0';
        wr_en_in1    <= (others => '0');
        wr_eof_in1   <= '0';
        wr_en_in2    <= (others => '0');
        wr_eof_in2   <= '0';
        wr_en_in3    <= (others => '0');
        wr_eof_in3   <= '0';

        wait for 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 2: Output 1 bekommt zwei Streams (Input 0 und 2)
        -- Datenmuster: 0x50.. und 0x70..
        -----------------------------------------------------------------------
        report "TEST 2: Output 1, Inputs 0 und 2" severity note;
        abort0_sent   := false;
        abort2_sent   := false;
        abort0_enable := false;
        abort2_enable := true;

        for i in 0 to LEN_T2 - 1 loop
            wait until rising_edge(clk);

            if abort0_sent then
                wr_en_in0   <= (others => '0');
                wr_data_in0 <= (others => '0');
                wr_eof_in0  <= '0';
            else
                wr_en_in0   <= "0010";
                wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(80 + i, 8));
                wr_eof_in0  <= '0';
            end if;

            if abort2_sent then
                wr_en_in2    <= (others => '0');
                wr_data_in2  <= (others => '0');
                wr_eof_in2   <= '0';
                wr_abort_in2 <= '0';
            else
                wr_en_in2   <= "0010";
                wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(112 + i, 8));
                wr_eof_in2  <= '0';
                if abort2_enable and i = LEN_T2 - 2 then
                    wr_abort_in2 <= '1';
                    abort2_sent := true;
                else
                    wr_abort_in2 <= '0';
                end if;
            end if;
        end loop;

        wait until rising_edge(clk);
        if abort0_sent then
            wr_en_in0   <= (others => '0');
            wr_data_in0 <= (others => '0');
            wr_eof_in0  <= '0';
        else
            wr_en_in0   <= "0010";
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(80 + LEN_T2, 8));
            wr_eof_in0  <= '1';
        end if;

        if abort2_sent then
            wr_en_in2   <= (others => '0');
            wr_data_in2 <= (others => '0');
            wr_eof_in2  <= '0';
        else
            wr_en_in2   <= "0010";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(112 + LEN_T2, 8));
            wr_eof_in2  <= '1';
        end if;
        wr_abort_in2 <= '0';

        wait until rising_edge(clk);
        wr_en_in0  <= (others => '0');
        wr_eof_in0 <= '0';
        wr_en_in2  <= (others => '0');
        wr_eof_in2 <= '0';

        wait for 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 3: Output 2 bekommt nur Input 3
        -- Datenmuster: 0x90..
        -----------------------------------------------------------------------
        report "TEST 3: Output 2, Input 3" severity note;
        abort3_sent   := false;
        abort3_enable := true;

        for i in 0 to LEN_T3 - 1 loop
            wait until rising_edge(clk);
            if abort3_sent then
                wr_en_in3   <= (others => '0');
                wr_data_in3 <= (others => '0');
                wr_eof_in3  <= '0';
            else
                wr_en_in3   <= "0100";
                wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(144 + i, 8));
                wr_eof_in3  <= '0';
                if abort3_enable and i = LEN_T3 - 2 then
                    wr_abort_in3 <= '1';
                    abort3_sent := true;
                else
                    wr_abort_in3 <= '0';
                end if;
            end if;
        end loop;

        wait until rising_edge(clk);
        if abort3_sent then
            wr_en_in3   <= (others => '0');
            wr_data_in3 <= (others => '0');
            wr_eof_in3  <= '0';
        else
            wr_en_in3   <= "0100";
            wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(144 + LEN_T3, 8));
            wr_eof_in3  <= '1';
        end if;
        wr_abort_in3 <= '0';

        wait until rising_edge(clk);
        wr_en_in3  <= (others => '0');
        wr_eof_in3 <= '0';

        wait for 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 4: Output 3 bekommt Input 1 und 2
        -- Datenmuster: 0xA0.. und 0xB0..
        -----------------------------------------------------------------------
        report "TEST 4: Output 3, Inputs 1 und 2" severity note;
        abort1_sent   := false;
        abort1_enable := true;

        for i in 0 to LEN_T4 - 1 loop
            wait until rising_edge(clk);
            if abort1_sent then
                wr_en_in1   <= (others => '0');
                wr_data_in1 <= (others => '0');
                wr_eof_in1  <= '0';
            else
                wr_en_in1   <= "1000";
                wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(160 + i, 8));
                wr_eof_in1  <= '0';
                if abort1_enable and i = LEN_T4 - 2 then
                    wr_abort_in1 <= '1';
                    abort1_sent := true;
                else
                    wr_abort_in1 <= '0';
                end if;
            end if;

            wr_en_in2   <= "1000";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(176 + i, 8));
            wr_eof_in2  <= '0';
        end loop;

        wait until rising_edge(clk);
        if abort1_sent then
            wr_en_in1   <= (others => '0');
            wr_data_in1 <= (others => '0');
            wr_eof_in1  <= '0';
        else
            wr_en_in1   <= "1000";
            wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(160 + LEN_T4, 8));
            wr_eof_in1  <= '1';
        end if;

        wr_en_in2    <= "1000";
        wr_data_in2  <= STD_LOGIC_VECTOR(to_unsigned(176 + LEN_T4, 8));
        wr_eof_in2   <= '1';
        wr_abort_in1 <= '0';

        wait until rising_edge(clk);
        wr_en_in1  <= (others => '0');
        wr_eof_in1 <= '0';
        wr_en_in2  <= (others => '0');
        wr_eof_in2 <= '0';

        wait for 50 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 5: Output 0, gemischte Frames im Wechsel (Abort/OK)
        -----------------------------------------------------------------------
        report "TEST 5: Output 0, alternating abort/ok" severity note;

        abort0_sent   := false;
        abort1_sent   := false;
        abort2_sent   := false;
        abort3_sent   := false;
        abort0_enable := true;
        abort1_enable := false;
        abort2_enable := true;
        abort3_enable := false;

        for i in 0 to LEN_T5 - 1 loop
            wait until rising_edge(clk);

            if abort0_sent then
                wr_en_in0    <= (others => '0');
                wr_data_in0  <= (others => '0');
                wr_eof_in0   <= '0';
                wr_abort_in0 <= '0';
            else
                wr_en_in0   <= "0001";
                wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + i, 8));
                wr_eof_in0  <= '0';
                if abort0_enable and i = LEN_T5 - 2 then
                    wr_abort_in0 <= '1';
                    abort0_sent := true;
                else
                    wr_abort_in0 <= '0';
                end if;
            end if;

            if abort1_sent then
                wr_en_in1    <= (others => '0');
                wr_data_in1  <= (others => '0');
                wr_eof_in1   <= '0';
                wr_abort_in1 <= '0';
            else
                wr_en_in1   <= "0001";
                wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + i, 8));
                wr_eof_in1  <= '0';
                if abort1_enable and i = LEN_T5 - 2 then
                    wr_abort_in1 <= '1';
                    abort1_sent := true;
                else
                    wr_abort_in1 <= '0';
                end if;
            end if;

            if abort2_sent then
                wr_en_in2    <= (others => '0');
                wr_data_in2  <= (others => '0');
                wr_eof_in2   <= '0';
                wr_abort_in2 <= '0';
            else
                wr_en_in2   <= "0001";
                wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + i, 8));
                wr_eof_in2  <= '0';
                if abort2_enable and i = LEN_T5 - 2 then
                    wr_abort_in2 <= '1';
                    abort2_sent := true;
                else
                    wr_abort_in2 <= '0';
                end if;
            end if;

            if abort3_sent then
                wr_en_in3    <= (others => '0');
                wr_data_in3  <= (others => '0');
                wr_eof_in3   <= '0';
                wr_abort_in3 <= '0';
            else
                wr_en_in3   <= "0001";
                wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + i, 8));
                wr_eof_in3  <= '0';
                if abort3_enable and i = LEN_T5 - 2 then
                    wr_abort_in3 <= '1';
                    abort3_sent := true;
                else
                    wr_abort_in3 <= '0';
                end if;
            end if;
        end loop;

        wait until rising_edge(clk);
        if abort0_sent then
            wr_en_in0   <= (others => '0');
            wr_data_in0 <= (others => '0');
            wr_eof_in0  <= '0';
        else
            wr_en_in0   <= "0001";
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + LEN_T5, 8));
            wr_eof_in0  <= '1';
        end if;

        if abort1_sent then
            wr_en_in1   <= (others => '0');
            wr_data_in1 <= (others => '0');
            wr_eof_in1  <= '0';
        else
            wr_en_in1   <= "0001";
            wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + LEN_T5, 8));
            wr_eof_in1  <= '1';
        end if;

        if abort2_sent then
            wr_en_in2   <= (others => '0');
            wr_data_in2 <= (others => '0');
            wr_eof_in2  <= '0';
        else
            wr_en_in2   <= "0001";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + LEN_T5, 8));
            wr_eof_in2  <= '1';
        end if;

        if abort3_sent then
            wr_en_in3   <= (others => '0');
            wr_data_in3 <= (others => '0');
            wr_eof_in3  <= '0';
        else
            wr_en_in3   <= "0001";
            wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + LEN_T5, 8));
            wr_eof_in3  <= '1';
        end if;

        wait until rising_edge(clk);
        wr_en_in0    <= (others => '0');
        wr_eof_in0   <= '0';
        wr_abort_in0 <= '0';
        wr_en_in1    <= (others => '0');
        wr_eof_in1   <= '0';
        wr_abort_in1 <= '0';
        wr_en_in2    <= (others => '0');
        wr_eof_in2   <= '0';
        wr_abort_in2 <= '0';
        wr_en_in3    <= (others => '0');
        wr_eof_in3   <= '0';
        wr_abort_in3 <= '0';

        wait for 20 * CLK_PERIOD;

        abort0_sent   := false;
        abort1_sent   := false;
        abort2_sent   := false;
        abort3_sent   := false;
        abort0_enable := false;
        abort1_enable := true;
        abort2_enable := false;
        abort3_enable := true;

        for i in 0 to LEN_T5 - 1 loop
            wait until rising_edge(clk);

            if abort0_sent then
                wr_en_in0    <= (others => '0');
                wr_data_in0  <= (others => '0');
                wr_eof_in0   <= '0';
                wr_abort_in0 <= '0';
            else
                wr_en_in0   <= "0001";
                wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + i, 8));
                wr_eof_in0  <= '0';
                if abort0_enable and i = LEN_T5 - 2 then
                    wr_abort_in0 <= '1';
                    abort0_sent := true;
                else
                    wr_abort_in0 <= '0';
                end if;
            end if;

            if abort1_sent then
                wr_en_in1    <= (others => '0');
                wr_data_in1  <= (others => '0');
                wr_eof_in1   <= '0';
                wr_abort_in1 <= '0';
            else
                wr_en_in1   <= "0001";
                wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + i, 8));
                wr_eof_in1  <= '0';
                if abort1_enable and i = LEN_T5 - 2 then
                    wr_abort_in1 <= '1';
                    abort1_sent := true;
                else
                    wr_abort_in1 <= '0';
                end if;
            end if;

            if abort2_sent then
                wr_en_in2    <= (others => '0');
                wr_data_in2  <= (others => '0');
                wr_eof_in2   <= '0';
                wr_abort_in2 <= '0';
            else
                wr_en_in2   <= "0001";
                wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + i, 8));
                wr_eof_in2  <= '0';
                if abort2_enable and i = LEN_T5 - 2 then
                    wr_abort_in2 <= '1';
                    abort2_sent := true;
                else
                    wr_abort_in2 <= '0';
                end if;
            end if;

            if abort3_sent then
                wr_en_in3    <= (others => '0');
                wr_data_in3  <= (others => '0');
                wr_eof_in3   <= '0';
                wr_abort_in3 <= '0';
            else
                wr_en_in3   <= "0001";
                wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + i, 8));
                wr_eof_in3  <= '0';
                if abort3_enable and i = LEN_T5 - 2 then
                    wr_abort_in3 <= '1';
                    abort3_sent := true;
                else
                    wr_abort_in3 <= '0';
                end if;
            end if;
        end loop;

        wait until rising_edge(clk);
        if abort0_sent then
            wr_en_in0   <= (others => '0');
            wr_data_in0 <= (others => '0');
            wr_eof_in0  <= '0';
        else
            wr_en_in0   <= "0001";
            wr_data_in0 <= STD_LOGIC_VECTOR(to_unsigned(16 + LEN_T5, 8));
            wr_eof_in0  <= '1';
        end if;

        if abort1_sent then
            wr_en_in1   <= (others => '0');
            wr_data_in1 <= (others => '0');
            wr_eof_in1  <= '0';
        else
            wr_en_in1   <= "0001";
            wr_data_in1 <= STD_LOGIC_VECTOR(to_unsigned(32 + LEN_T5, 8));
            wr_eof_in1  <= '1';
        end if;

        if abort2_sent then
            wr_en_in2   <= (others => '0');
            wr_data_in2 <= (others => '0');
            wr_eof_in2  <= '0';
        else
            wr_en_in2   <= "0001";
            wr_data_in2 <= STD_LOGIC_VECTOR(to_unsigned(48 + LEN_T5, 8));
            wr_eof_in2  <= '1';
        end if;

        if abort3_sent then
            wr_en_in3   <= (others => '0');
            wr_data_in3 <= (others => '0');
            wr_eof_in3  <= '0';
        else
            wr_en_in3   <= "0001";
            wr_data_in3 <= STD_LOGIC_VECTOR(to_unsigned(64 + LEN_T5, 8));
            wr_eof_in3  <= '1';
        end if;

        wait until rising_edge(clk);
        wr_en_in0    <= (others => '0');
        wr_eof_in0   <= '0';
        wr_abort_in0 <= '0';
        wr_en_in1    <= (others => '0');
        wr_eof_in1   <= '0';
        wr_abort_in1 <= '0';
        wr_en_in2    <= (others => '0');
        wr_eof_in2   <= '0';
        wr_abort_in2 <= '0';
        wr_en_in3    <= (others => '0');
        wr_eof_in3   <= '0';
        wr_abort_in3 <= '0';

        report "TB finished" severity note;
        wait;
    end process;

end architecture;
