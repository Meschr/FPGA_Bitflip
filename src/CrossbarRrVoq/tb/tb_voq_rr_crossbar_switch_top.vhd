library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_voq_rr_crossbar_switch_top is
end entity;

architecture sim of tb_voq_rr_crossbar_switch_top is

    constant CLK_PERIOD : time := 10 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- Flush je Output-Queue
    signal flush_out0 : std_logic_vector(3 downto 0) := (others => '0');
    signal flush_out1 : std_logic_vector(3 downto 0) := (others => '0');
    signal flush_out2 : std_logic_vector(3 downto 0) := (others => '0');
    signal flush_out3 : std_logic_vector(3 downto 0) := (others => '0');

    -- Schreibports: 4 Eingange x 4 Ausgaenge
    signal wr_data_in0_out0, wr_data_in0_out1, wr_data_in0_out2, wr_data_in0_out3 : std_logic_vector(7 downto 0);
    signal wr_data_in1_out0, wr_data_in1_out1, wr_data_in1_out2, wr_data_in1_out3 : std_logic_vector(7 downto 0);
    signal wr_data_in2_out0, wr_data_in2_out1, wr_data_in2_out2, wr_data_in2_out3 : std_logic_vector(7 downto 0);
    signal wr_data_in3_out0, wr_data_in3_out1, wr_data_in3_out2, wr_data_in3_out3 : std_logic_vector(7 downto 0);

    signal wr_en_in0_out0, wr_en_in0_out1, wr_en_in0_out2, wr_en_in0_out3 : std_logic := '0';
    signal wr_en_in1_out0, wr_en_in1_out1, wr_en_in1_out2, wr_en_in1_out3 : std_logic := '0';
    signal wr_en_in2_out0, wr_en_in2_out1, wr_en_in2_out2, wr_en_in2_out3 : std_logic := '0';
    signal wr_en_in3_out0, wr_en_in3_out1, wr_en_in3_out2, wr_en_in3_out3 : std_logic := '0';

    signal wr_eof_in0_out0, wr_eof_in0_out1, wr_eof_in0_out2, wr_eof_in0_out3 : std_logic := '0';
    signal wr_eof_in1_out0, wr_eof_in1_out1, wr_eof_in1_out2, wr_eof_in1_out3 : std_logic := '0';
    signal wr_eof_in2_out0, wr_eof_in2_out1, wr_eof_in2_out2, wr_eof_in2_out3 : std_logic := '0';
    signal wr_eof_in3_out0, wr_eof_in3_out1, wr_eof_in3_out2, wr_eof_in3_out3 : std_logic := '0';

    -- Ausgaenge
    signal out_data_0  : std_logic_vector(7 downto 0);
    signal out_data_1  : std_logic_vector(7 downto 0);
    signal out_data_2  : std_logic_vector(7 downto 0);
    signal out_data_3  : std_logic_vector(7 downto 0);

    signal out_valid_0 : std_logic;
    signal out_valid_1 : std_logic;
    signal out_valid_2 : std_logic;
    signal out_valid_3 : std_logic;

begin

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    dut : entity work.voq_rr_crossbar_switch_top
        port map (
            clk   => clk,
            reset => reset,

            flush_out0 => flush_out0,
            flush_out1 => flush_out1,
            flush_out2 => flush_out2,
            flush_out3 => flush_out3,

            wr_data_in0_out0 => wr_data_in0_out0,
            wr_en_in0_out0   => wr_en_in0_out0,
            wr_eof_in0_out0  => wr_eof_in0_out0,

            wr_data_in0_out1 => wr_data_in0_out1,
            wr_en_in0_out1   => wr_en_in0_out1,
            wr_eof_in0_out1  => wr_eof_in0_out1,

            wr_data_in0_out2 => wr_data_in0_out2,
            wr_en_in0_out2   => wr_en_in0_out2,
            wr_eof_in0_out2  => wr_eof_in0_out2,

            wr_data_in0_out3 => wr_data_in0_out3,
            wr_en_in0_out3   => wr_en_in0_out3,
            wr_eof_in0_out3  => wr_eof_in0_out3,

            wr_data_in1_out0 => wr_data_in1_out0,
            wr_en_in1_out0   => wr_en_in1_out0,
            wr_eof_in1_out0  => wr_eof_in1_out0,

            wr_data_in1_out1 => wr_data_in1_out1,
            wr_en_in1_out1   => wr_en_in1_out1,
            wr_eof_in1_out1  => wr_eof_in1_out1,

            wr_data_in1_out2 => wr_data_in1_out2,
            wr_en_in1_out2   => wr_en_in1_out2,
            wr_eof_in1_out2  => wr_eof_in1_out2,

            wr_data_in1_out3 => wr_data_in1_out3,
            wr_en_in1_out3   => wr_en_in1_out3,
            wr_eof_in1_out3  => wr_eof_in1_out3,

            wr_data_in2_out0 => wr_data_in2_out0,
            wr_en_in2_out0   => wr_en_in2_out0,
            wr_eof_in2_out0  => wr_eof_in2_out0,

            wr_data_in2_out1 => wr_data_in2_out1,
            wr_en_in2_out1   => wr_en_in2_out1,
            wr_eof_in2_out1  => wr_eof_in2_out1,

            wr_data_in2_out2 => wr_data_in2_out2,
            wr_en_in2_out2   => wr_en_in2_out2,
            wr_eof_in2_out2  => wr_eof_in2_out2,

            wr_data_in2_out3 => wr_data_in2_out3,
            wr_en_in2_out3   => wr_en_in2_out3,
            wr_eof_in2_out3  => wr_eof_in2_out3,

            wr_data_in3_out0 => wr_data_in3_out0,
            wr_en_in3_out0   => wr_en_in3_out0,
            wr_eof_in3_out0  => wr_eof_in3_out0,

            wr_data_in3_out1 => wr_data_in3_out1,
            wr_en_in3_out1   => wr_en_in3_out1,
            wr_eof_in3_out1  => wr_eof_in3_out1,

            wr_data_in3_out2 => wr_data_in3_out2,
            wr_en_in3_out2   => wr_en_in3_out2,
            wr_eof_in3_out2  => wr_eof_in3_out2,

            wr_data_in3_out3 => wr_data_in3_out3,
            wr_en_in3_out3   => wr_en_in3_out3,
            wr_eof_in3_out3  => wr_eof_in3_out3,

            out_data_0  => out_data_0,
            out_data_1  => out_data_1,
            out_data_2  => out_data_2,
            out_data_3  => out_data_3,

            out_valid_0 => out_valid_0,
            out_valid_1 => out_valid_1,
            out_valid_2 => out_valid_2,
            out_valid_3 => out_valid_3,

            rr_sel_0    => open,
            rr_sel_1    => open,
            rr_sel_2    => open,
            rr_sel_3    => open,

            rr_grant_0  => open,
            rr_grant_1  => open,
            rr_grant_2  => open,
            rr_grant_3  => open,

            rr_active_0 => open,
            rr_active_1 => open,
            rr_active_2 => open,
            rr_active_3 => open,

            frame_rdy_dbg_0 => open,
            frame_rdy_dbg_1 => open,
            frame_rdy_dbg_2 => open,
            frame_rdy_dbg_3 => open,

            rd_eof_dbg_0 => open,
            rd_eof_dbg_1 => open,
            rd_eof_dbg_2 => open,
            rd_eof_dbg_3 => open,

            full_dbg_0 => open,
            full_dbg_1 => open,
            full_dbg_2 => open,
            full_dbg_3 => open,

            empty_dbg_0 => open,
            empty_dbg_1 => open,
            empty_dbg_2 => open,
            empty_dbg_3 => open
        );

    ---------------------------------------------------------------------------
    -- Clock
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Output Monitor: zeigt ausgehende Daten je Ausgang im Transcript
    ---------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if out_valid_0 = '1' then
                report "OUT0 data=" & integer'image(to_integer(unsigned(out_data_0))) severity note;
            end if;
            if out_valid_1 = '1' then
                report "OUT1 data=" & integer'image(to_integer(unsigned(out_data_1))) severity note;
            end if;
            if out_valid_2 = '1' then
                report "OUT2 data=" & integer'image(to_integer(unsigned(out_data_2))) severity note;
            end if;
            if out_valid_3 = '1' then
                report "OUT3 data=" & integer'image(to_integer(unsigned(out_data_3))) severity note;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Stimulus
    ---------------------------------------------------------------------------
    process
    begin
        -- Initialwerte
        wr_data_in0_out0 <= (others => '0'); wr_data_in0_out1 <= (others => '0');
        wr_data_in0_out2 <= (others => '0'); wr_data_in0_out3 <= (others => '0');
        wr_data_in1_out0 <= (others => '0'); wr_data_in1_out1 <= (others => '0');
        wr_data_in1_out2 <= (others => '0'); wr_data_in1_out3 <= (others => '0');
        wr_data_in2_out0 <= (others => '0'); wr_data_in2_out1 <= (others => '0');
        wr_data_in2_out2 <= (others => '0'); wr_data_in2_out3 <= (others => '0');
        wr_data_in3_out0 <= (others => '0'); wr_data_in3_out1 <= (others => '0');
        wr_data_in3_out2 <= (others => '0'); wr_data_in3_out3 <= (others => '0');

        -- Reset
        wait for 3 * CLK_PERIOD;
        reset <= '0';
        wait for CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 1: Output 0 bekommt vier unterschiedliche Streams (alle Inputs)
        -- Datenmuster: 0x10.., 0x20.., 0x30.., 0x40..
        -----------------------------------------------------------------------
        report "TEST 1: Output 0, alle Inputs" severity note;
        for i in 0 to 3 loop
            wait until rising_edge(clk);

            wr_en_in0_out0 <= '1';
            wr_data_in0_out0 <= std_logic_vector(to_unsigned(16 + i, 8));
            wr_eof_in0_out0 <= '0';

            wr_en_in1_out0 <= '1';
            wr_data_in1_out0 <= std_logic_vector(to_unsigned(32 + i, 8));
            wr_eof_in1_out0 <= '0';

            wr_en_in2_out0 <= '1';
            wr_data_in2_out0 <= std_logic_vector(to_unsigned(48 + i, 8));
            wr_eof_in2_out0 <= '0';

            wr_en_in3_out0 <= '1';
            wr_data_in3_out0 <= std_logic_vector(to_unsigned(64 + i, 8));
            wr_eof_in3_out0 <= '0';
        end loop;

        wait until rising_edge(clk);
        wr_data_in0_out0 <= std_logic_vector(to_unsigned(16 + 4, 8));
        wr_data_in1_out0 <= std_logic_vector(to_unsigned(32 + 4, 8));
        wr_data_in2_out0 <= std_logic_vector(to_unsigned(48 + 4, 8));
        wr_data_in3_out0 <= std_logic_vector(to_unsigned(64 + 4, 8));
        wr_eof_in0_out0  <= '1';
        wr_eof_in1_out0  <= '1';
        wr_eof_in2_out0  <= '1';
        wr_eof_in3_out0  <= '1';

        wait until rising_edge(clk);
        wr_en_in0_out0 <= '0'; wr_eof_in0_out0 <= '0';
        wr_en_in1_out0 <= '0'; wr_eof_in1_out0 <= '0';
        wr_en_in2_out0 <= '0'; wr_eof_in2_out0 <= '0';
        wr_en_in3_out0 <= '0'; wr_eof_in3_out0 <= '0';

        wait for 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 2: Output 1 bekommt zwei Streams (Input 0 und 2)
        -- Datenmuster: 0x50.. und 0x70..
        -----------------------------------------------------------------------
        report "TEST 2: Output 1, Inputs 0 und 2" severity note;
        for i in 0 to 2 loop
            wait until rising_edge(clk);

            wr_en_in0_out1 <= '1';
            wr_data_in0_out1 <= std_logic_vector(to_unsigned(80 + i, 8));
            wr_eof_in0_out1 <= '0';

            wr_en_in2_out1 <= '1';
            wr_data_in2_out1 <= std_logic_vector(to_unsigned(112 + i, 8));
            wr_eof_in2_out1 <= '0';
        end loop;

        wait until rising_edge(clk);
        wr_data_in0_out1 <= std_logic_vector(to_unsigned(80 + 3, 8));
        wr_data_in2_out1 <= std_logic_vector(to_unsigned(112 + 3, 8));
        wr_eof_in0_out1  <= '1';
        wr_eof_in2_out1  <= '1';

        wait until rising_edge(clk);
        wr_en_in0_out1 <= '0'; wr_eof_in0_out1 <= '0';
        wr_en_in2_out1 <= '0'; wr_eof_in2_out1 <= '0';

        wait for 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 3: Output 2 bekommt nur Input 3
        -- Datenmuster: 0x90..
        -----------------------------------------------------------------------
        report "TEST 3: Output 2, Input 3" severity note;
        for i in 0 to 2 loop
            wait until rising_edge(clk);
            wr_en_in3_out2 <= '1';
            wr_data_in3_out2 <= std_logic_vector(to_unsigned(144 + i, 8));
            wr_eof_in3_out2 <= '0';
        end loop;

        wait until rising_edge(clk);
        wr_data_in3_out2 <= std_logic_vector(to_unsigned(144 + 3, 8));
        wr_eof_in3_out2  <= '1';

        wait until rising_edge(clk);
        wr_en_in3_out2 <= '0'; wr_eof_in3_out2 <= '0';

        wait for 30 * CLK_PERIOD;

        -----------------------------------------------------------------------
        -- TEST 4: Output 3 bekommt Input 1 und 2
        -- Datenmuster: 0xA0.. und 0xB0..
        -----------------------------------------------------------------------
        report "TEST 4: Output 3, Inputs 1 und 2" severity note;
        for i in 0 to 1 loop
            wait until rising_edge(clk);
            wr_en_in1_out3 <= '1';
            wr_data_in1_out3 <= std_logic_vector(to_unsigned(160 + i, 8));
            wr_eof_in1_out3 <= '0';

            wr_en_in2_out3 <= '1';
            wr_data_in2_out3 <= std_logic_vector(to_unsigned(176 + i, 8));
            wr_eof_in2_out3 <= '0';
        end loop;

        wait until rising_edge(clk);
        wr_data_in1_out3 <= std_logic_vector(to_unsigned(160 + 2, 8));
        wr_data_in2_out3 <= std_logic_vector(to_unsigned(176 + 2, 8));
        wr_eof_in1_out3  <= '1';
        wr_eof_in2_out3  <= '1';

        wait until rising_edge(clk);
        wr_en_in1_out3 <= '0'; wr_eof_in1_out3 <= '0';
        wr_en_in2_out3 <= '0'; wr_eof_in2_out3 <= '0';

        wait for 50 * CLK_PERIOD;

        report "TB finished" severity note;
        wait;
    end process;

end architecture;
