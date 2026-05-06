library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_voq_rr_crossbar is
end entity;

architecture sim of tb_voq_rr_crossbar is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal flush : std_logic_vector(3 downto 0) := (others => '0');

    -- Inputs
    signal wr_data_in0, wr_data_in1, wr_data_in2, wr_data_in3 : std_logic_vector(7 downto 0);
    signal wr_en_in0, wr_en_in1, wr_en_in2, wr_en_in3         : std_logic;
    signal wr_eof_in0, wr_eof_in1, wr_eof_in2, wr_eof_in3     : std_logic;

    -- Outputs
    signal out_data_0 : std_logic_vector(7 downto 0);

    signal rr_sel    : std_logic_vector(1 downto 0);
    signal rr_grant  : std_logic_vector(3 downto 0);
    signal rr_active : std_logic;

begin

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    dut : entity work.voq_rr_crossbar_top
        port map (
            clk   => clk,
            reset => reset,
            flush => flush,

            wr_data_in0 => wr_data_in0,
            wr_en_in0   => wr_en_in0,
            wr_eof_in0  => wr_eof_in0,

            wr_data_in1 => wr_data_in1,
            wr_en_in1   => wr_en_in1,
            wr_eof_in1  => wr_eof_in1,

            wr_data_in2 => wr_data_in2,
            wr_en_in2   => wr_en_in2,
            wr_eof_in2  => wr_eof_in2,

            wr_data_in3 => wr_data_in3,
            wr_en_in3   => wr_en_in3,
            wr_eof_in3  => wr_eof_in3,

            out_data_0 => out_data_0,

            rr_sel     => rr_sel,
            rr_grant   => rr_grant,
            rr_active  => rr_active,

            frame_rdy_dbg => open,
            rd_eof_dbg    => open,
            full_dbg      => open,
            empty_dbg     => open
        );

    ---------------------------------------------------------------------------
    -- Clock
    ---------------------------------------------------------------------------
    clk <= not clk after 5 ns;

    ---------------------------------------------------------------------------
    -- Stimulus
    ---------------------------------------------------------------------------
    process
    begin
        report "Start TB VOQ + RR + Crossbar" severity note;

        -- Reset
        wait for 20 ns;
        reset <= '0';

        -----------------------------------------------------------------------
        -- TEST 1: Single input stream
        -----------------------------------------------------------------------
        report "TEST 1: Input 0 only" severity note;

        for i in 0 to 3 loop
            wait until rising_edge(clk);
            wr_en_in0  <= '1';
            wr_data_in0 <= std_logic_vector(to_unsigned(i+1,8));
            wr_eof_in0 <= '0';
        end loop;

        wait until rising_edge(clk);
        wr_data_in0 <= x"AA";
        wr_eof_in0  <= '1';

        wait until rising_edge(clk);
        wr_en_in0 <= '0';
        wr_eof_in0 <= '0';

        wait for 100 ns;

        -----------------------------------------------------------------------
        -- TEST 2: Two inputs (RR switching)
        -----------------------------------------------------------------------
        report "TEST 2: Input 0 and 1" severity note;

        for i in 0 to 2 loop
            wait until rising_edge(clk);

            wr_en_in0  <= '1';
            wr_data_in0 <= x"10"; --
            wr_eof_in0 <= '0';

            wr_en_in1  <= '1';
            wr_data_in1 <= x"20";
            wr_eof_in1 <= '0';
        end loop;

        wait until rising_edge(clk);
        wr_data_in0 <= x"11";
        wr_eof_in0  <= '1';

        wr_data_in1 <= x"21";
        wr_eof_in1  <= '1';

        wait until rising_edge(clk);
        wr_en_in0 <= '0';
        wr_eof_in0 <= '0';

        wr_en_in1 <= '0';
        wr_eof_in1 <= '0';

        wait for 150 ns;

        -----------------------------------------------------------------------
        -- TEST 3: All 4 inputs
        -----------------------------------------------------------------------
        report "TEST 3: All inputs active" severity note;

        for i in 0 to 1 loop
            wait until rising_edge(clk);

            wr_en_in0 <= '1'; wr_data_in0 <= x"A0"; wr_eof_in0 <= '0';
            wr_en_in1 <= '1'; wr_data_in1 <= x"B0"; wr_eof_in1 <= '0';
            wr_en_in2 <= '1'; wr_data_in2 <= x"C0"; wr_eof_in2 <= '0';
            wr_en_in3 <= '1'; wr_data_in3 <= x"D0"; wr_eof_in3 <= '0';
        end loop;

        wait until rising_edge(clk);
        wr_eof_in0 <= '1';
        wr_eof_in1 <= '1';
        wr_eof_in2 <= '1';
        wr_eof_in3 <= '1';

        wait until rising_edge(clk);
        wr_en_in0 <= '0';
        wr_en_in1 <= '0';
        wr_en_in2 <= '0';
        wr_en_in3 <= '0';

        wr_eof_in0 <= '0';
        wr_eof_in1 <= '0';
        wr_eof_in2 <= '0';
        wr_eof_in3 <= '0';

        wait for 200 ns;

        -----------------------------------------------------------------------
        report "TB finished" severity note;
        wait;
    end process;

end architecture;