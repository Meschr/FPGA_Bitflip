library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_crossbar_switch_GBT is
end entity;

architecture sim of tb_crossbar_switch_GBT is

    constant CLK_PERIOD : time := 10 ns;

    type obs_mem_t is array (0 to 255) of std_logic_vector(7 downto 0);

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal wr_data_in0 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in0  : std_logic := '0';
    signal wr_en_in0   : std_logic_vector(3 downto 0) := (others => '0');

    signal wr_data_in1 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in1  : std_logic := '0';
    signal wr_en_in1   : std_logic_vector(3 downto 0) := (others => '0');

    signal wr_data_in2 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in2  : std_logic := '0';
    signal wr_en_in2   : std_logic_vector(3 downto 0) := (others => '0');

    signal wr_data_in3 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in3  : std_logic := '0';
    signal wr_en_in3   : std_logic_vector(3 downto 0) := (others => '0');

    signal full_in0 : std_logic_vector(3 downto 0);
    signal full_in1 : std_logic_vector(3 downto 0);
    signal full_in2 : std_logic_vector(3 downto 0);
    signal full_in3 : std_logic_vector(3 downto 0);

    signal out_data_0 : std_logic_vector(7 downto 0);
    signal out_data_1 : std_logic_vector(7 downto 0);
    signal out_data_2 : std_logic_vector(7 downto 0);
    signal out_data_3 : std_logic_vector(7 downto 0);

    signal obs0       : obs_mem_t := (others => (others => '0'));
    signal obs1       : obs_mem_t := (others => (others => '0'));
    signal obs2       : obs_mem_t := (others => (others => '0'));
    signal obs3       : obs_mem_t := (others => (others => '0'));
    signal obs0_count : integer := 0;
    signal obs1_count : integer := 0;
    signal obs2_count : integer := 0;
    signal obs3_count : integer := 0;

    function onehot(idx : natural) return std_logic_vector is
        variable tmp : std_logic_vector(3 downto 0) := (others => '0');
    begin
        tmp(idx) := '1';
        return tmp;
    end function;

begin

    clk <= not clk after CLK_PERIOD/2;

    dut : entity work.switch_core
        port map (
            clk         => clk,
            reset       => reset,
            wr_data_in0 => wr_data_in0,
            wr_eof_in0  => wr_eof_in0,
            wr_en_in0   => wr_en_in0,
            wr_data_in1 => wr_data_in1,
            wr_eof_in1  => wr_eof_in1,
            wr_en_in1   => wr_en_in1,
            wr_data_in2 => wr_data_in2,
            wr_eof_in2  => wr_eof_in2,
            wr_en_in2   => wr_en_in2,
            wr_data_in3 => wr_data_in3,
            wr_eof_in3  => wr_eof_in3,
            wr_en_in3   => wr_en_in3,
            full_in0    => full_in0,
            full_in1    => full_in1,
            full_in2    => full_in2,
            full_in3    => full_in3,
            out_data_0  => out_data_0,
            out_data_1  => out_data_1,
            out_data_2  => out_data_2,
            out_data_3  => out_data_3
        );

    monitor_out0 : process(out_data_0, reset)
        variable last : std_logic_vector(7 downto 0) := (others => '0');
    begin
        if reset = '1' then
            last := (others => '0');
        elsif out_data_0'event then
            if out_data_0 /= last then
                obs0(obs0_count) <= out_data_0;
                obs0_count <= obs0_count + 1;
                last := out_data_0;
            end if;
        end if;
    end process;

    monitor_out1 : process(out_data_1, reset)
        variable last : std_logic_vector(7 downto 0) := (others => '0');
    begin
        if reset = '1' then
            last := (others => '0');
        elsif out_data_1'event then
            if out_data_1 /= last then
                obs1(obs1_count) <= out_data_1;
                obs1_count <= obs1_count + 1;
                last := out_data_1;
            end if;
        end if;
    end process;

    monitor_out2 : process(out_data_2, reset)
        variable last : std_logic_vector(7 downto 0) := (others => '0');
    begin
        if reset = '1' then
            last := (others => '0');
        elsif out_data_2'event then
            if out_data_2 /= last then
                obs2(obs2_count) <= out_data_2;
                obs2_count <= obs2_count + 1;
                last := out_data_2;
            end if;
        end if;
    end process;

    monitor_out3 : process(out_data_3, reset)
        variable last : std_logic_vector(7 downto 0) := (others => '0');
    begin
        if reset = '1' then
            last := (others => '0');
        elsif out_data_3'event then
            if out_data_3 /= last then
                obs3(obs3_count) <= out_data_3;
                obs3_count <= obs3_count + 1;
                last := out_data_3;
            end if;
        end if;
    end process;

    stim_proc : process
        variable s0, s1, s2, s3 : integer;

        procedure clear_all_inputs is
        begin
            wr_data_in0 <= (others => '0'); wr_eof_in0 <= '0'; wr_en_in0 <= (others => '0');
            wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0'; wr_en_in1 <= (others => '0');
            wr_data_in2 <= (others => '0'); wr_eof_in2 <= '0'; wr_en_in2 <= (others => '0');
            wr_data_in3 <= (others => '0'); wr_eof_in3 <= '0'; wr_en_in3 <= (others => '0');
        end procedure;

        procedure idle_cycles(n : natural) is
        begin
            for i in 1 to n loop
                clear_all_inputs;
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure apply_reset is
        begin
            clear_all_inputs;
            reset <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            clear_all_inputs;
            reset <= '0';
            wait until rising_edge(clk);
        end procedure;

        procedure send_frame(
            signal wr_data : out std_logic_vector(7 downto 0);
            signal wr_eof  : out std_logic;
            signal wr_en   : out std_logic_vector(3 downto 0);
            constant dest  : natural;
            constant b0    : std_logic_vector(7 downto 0);
            constant b1    : std_logic_vector(7 downto 0);
            constant b2    : std_logic_vector(7 downto 0);
            constant b3    : std_logic_vector(7 downto 0);
            constant len   : natural
        ) is
        begin
            assert len >= 1 and len <= 4 report "send_frame: invalid len" severity failure;

            wr_en   <= onehot(dest);
            wr_data <= b0;
            if len = 1 then wr_eof <= '1'; else wr_eof <= '0'; end if;
            wait until rising_edge(clk);

            if len >= 2 then
                wr_data <= b1;
                if len = 2 then wr_eof <= '1'; else wr_eof <= '0'; end if;
                wait until rising_edge(clk);
            end if;
            if len >= 3 then
                wr_data <= b2;
                if len = 3 then wr_eof <= '1'; else wr_eof <= '0'; end if;
                wait until rising_edge(clk);
            end if;
            if len >= 4 then
                wr_data <= b3;
                wr_eof  <= '1';
                wait until rising_edge(clk);
            end if;

            wr_en   <= (others => '0');
            wr_eof  <= '0';
            wr_data <= (others => '0');
        end procedure;


        procedure dump_observed_range(
            constant test_name   : in string;
            constant signal_name : in string;
            constant mem         : in obs_mem_t;
            constant start_idx   : in integer;
            constant end_idx     : in integer
        ) is
        begin
            if end_idx < start_idx then
                report test_name & ": " & signal_name & " observed no bytes in requested range"
                    severity note;
            else
                for i in start_idx to end_idx loop
                    report test_name & ": " & signal_name & " observed[" & integer'image(i - start_idx) & "] = 0x" &
                           to_hstring(mem(i)) severity note;
                end loop;
            end if;
        end procedure;

        procedure check_count(
            constant test_name   : in string;
            constant signal_name : in string;
            constant expected    : in integer;
            constant actual      : in integer;
            constant mem         : in obs_mem_t;
            constant start_idx   : in integer
        ) is
        begin
            if actual /= expected then
                report test_name & ": " & signal_name & " count mismatch. expected=" & integer'image(expected) &
                       " got=" & integer'image(actual)
                    severity error;
                dump_observed_range(test_name, signal_name, mem, start_idx, actual - 1);
                assert false report test_name & ": " & signal_name & " count mismatch" severity failure;
            end if;
        end procedure;

        procedure check_byte(
            constant test_name   : in string;
            constant signal_name : in string;
            constant idx         : in integer;
            constant expected    : in std_logic_vector(7 downto 0);
            constant actual      : in std_logic_vector(7 downto 0);
            constant mem         : in obs_mem_t;
            constant start_idx   : in integer;
            constant actual_count: in integer
        ) is
        begin
            if actual /= expected then
                report test_name & ": " & signal_name & " byte[" & integer'image(idx) & "] mismatch. expected=0x" &
                       to_hstring(expected) & " got=0x" & to_hstring(actual)
                    severity error;
                dump_observed_range(test_name, signal_name, mem, start_idx, actual_count - 1);
                assert false report test_name & ": " & signal_name & " byte mismatch" severity failure;
            end if;
        end procedure;

        procedure check_no_new_traffic(
            constant test_name   : in string;
            constant signal_name : in string;
            constant start_count : in integer;
            constant actual      : in integer;
            constant mem         : in obs_mem_t
        ) is
        begin
            if actual /= start_count then
                report test_name & ": unexpected traffic on " & signal_name & ". expected count=" &
                       integer'image(start_count) & " got=" & integer'image(actual)
                    severity error;
                dump_observed_range(test_name, signal_name, mem, start_count, actual - 1);
                assert false report test_name & ": unexpected traffic" severity failure;
            end if;
        end procedure;

    begin
        -----------------------------------------------------------------------
        -- TEST 1: Single frame, In0 -> Out0
        -----------------------------------------------------------------------
        report "Starting TEST1: single frame In0 -> Out0" severity note;
        apply_reset;
        s0 := obs0_count;
        s1 := obs1_count;
        s2 := obs2_count;
        s3 := obs3_count;

        send_frame(wr_data_in0, wr_eof_in0, wr_en_in0, 0, x"11", x"12", x"13", x"14", 4);
        idle_cycles(12);

        check_count("TEST1", "Out0", s0 + 4, obs0_count, obs0, s0);
        check_byte("TEST1", "Out0", 0, x"11", obs0(s0+0), obs0, s0, obs0_count);
        check_byte("TEST1", "Out0", 1, x"12", obs0(s0+1), obs0, s0, obs0_count);
        check_byte("TEST1", "Out0", 2, x"13", obs0(s0+2), obs0, s0, obs0_count);
        check_byte("TEST1", "Out0", 3, x"14", obs0(s0+3), obs0, s0, obs0_count);
        check_no_new_traffic("TEST1", "Out1", s1, obs1_count, obs1);
        check_no_new_traffic("TEST1", "Out2", s2, obs2_count, obs2);
        check_no_new_traffic("TEST1", "Out3", s3, obs3_count, obs3);

        -----------------------------------------------------------------------
        -- TEST 2: Parallel frames on different outputs
        -----------------------------------------------------------------------
        report "Starting TEST2: parallel frames on Out1 and Out2" severity note;
        apply_reset;
        s0 := obs0_count;
        s1 := obs1_count;
        s2 := obs2_count;
        s3 := obs3_count;

        wr_en_in1   <= onehot(1); wr_data_in1 <= x"21"; wr_eof_in1 <= '0';
        wr_en_in2   <= onehot(2); wr_data_in2 <= x"31"; wr_eof_in2 <= '0';
        wait until rising_edge(clk);

        wr_en_in1   <= onehot(1); wr_data_in1 <= x"22"; wr_eof_in1 <= '0';
        wr_en_in2   <= onehot(2); wr_data_in2 <= x"32"; wr_eof_in2 <= '0';
        wait until rising_edge(clk);

        wr_en_in1   <= onehot(1); wr_data_in1 <= x"23"; wr_eof_in1 <= '1';
        wr_en_in2   <= onehot(2); wr_data_in2 <= x"33"; wr_eof_in2 <= '0';
        wait until rising_edge(clk);

        wr_en_in1   <= (others => '0'); wr_data_in1 <= (others => '0'); wr_eof_in1 <= '0';
        wr_en_in2   <= onehot(2);       wr_data_in2 <= x"34";          wr_eof_in2 <= '1';
        wait until rising_edge(clk);

        clear_all_inputs;
        idle_cycles(12);

        check_count("TEST2", "Out1", s1 + 3, obs1_count, obs1, s1);
        check_count("TEST2", "Out2", s2 + 4, obs2_count, obs2, s2);
        check_byte("TEST2", "Out1", 0, x"21", obs1(s1+0), obs1, s1, obs1_count);
        check_byte("TEST2", "Out1", 1, x"22", obs1(s1+1), obs1, s1, obs1_count);
        check_byte("TEST2", "Out1", 2, x"23", obs1(s1+2), obs1, s1, obs1_count);
        check_byte("TEST2", "Out2", 0, x"31", obs2(s2+0), obs2, s2, obs2_count);
        check_byte("TEST2", "Out2", 1, x"32", obs2(s2+1), obs2, s2, obs2_count);
        check_byte("TEST2", "Out2", 2, x"33", obs2(s2+2), obs2, s2, obs2_count);
        check_byte("TEST2", "Out2", 3, x"34", obs2(s2+3), obs2, s2, obs2_count);
        check_no_new_traffic("TEST2", "Out0", s0, obs0_count, obs0);
        check_no_new_traffic("TEST2", "Out3", s3, obs3_count, obs3);

        -----------------------------------------------------------------------
        -- TEST 3: Contention on same output
        -----------------------------------------------------------------------
        report "Starting TEST3: contention on Out3" severity note;
        apply_reset;
        s3 := obs3_count;

        wr_en_in0   <= onehot(3); wr_data_in0 <= x"41"; wr_eof_in0 <= '0';
        wr_en_in2   <= onehot(3); wr_data_in2 <= x"51"; wr_eof_in2 <= '0';
        wait until rising_edge(clk);

        wr_en_in0   <= onehot(3); wr_data_in0 <= x"42"; wr_eof_in0 <= '1';
        wr_en_in2   <= onehot(3); wr_data_in2 <= x"52"; wr_eof_in2 <= '1';
        wait until rising_edge(clk);

        clear_all_inputs;
        idle_cycles(14);

        check_count("TEST3", "Out3", s3 + 4, obs3_count, obs3, s3);
        check_byte("TEST3", "Out3", 0, x"41", obs3(s3+0), obs3, s3, obs3_count);
        check_byte("TEST3", "Out3", 1, x"42", obs3(s3+1), obs3, s3, obs3_count);
        check_byte("TEST3", "Out3", 2, x"51", obs3(s3+2), obs3, s3, obs3_count);
        check_byte("TEST3", "Out3", 3, x"52", obs3(s3+3), obs3, s3, obs3_count);

        -----------------------------------------------------------------------
        -- TEST 4: Round-robin sweep on one output
        -----------------------------------------------------------------------
        report "Starting TEST4: round-robin sweep on Out0" severity note;
        apply_reset;
        s0 := obs0_count;

        wr_en_in0 <= onehot(0); wr_data_in0 <= x"61"; wr_eof_in0 <= '0';
        wr_en_in1 <= onehot(0); wr_data_in1 <= x"71"; wr_eof_in1 <= '0';
        wr_en_in2 <= onehot(0); wr_data_in2 <= x"81"; wr_eof_in2 <= '0';
        wr_en_in3 <= onehot(0); wr_data_in3 <= x"91"; wr_eof_in3 <= '0';
        wait until rising_edge(clk);

        wr_en_in0 <= onehot(0); wr_data_in0 <= x"62"; wr_eof_in0 <= '1';
        wr_en_in1 <= onehot(0); wr_data_in1 <= x"72"; wr_eof_in1 <= '1';
        wr_en_in2 <= onehot(0); wr_data_in2 <= x"82"; wr_eof_in2 <= '1';
        wr_en_in3 <= onehot(0); wr_data_in3 <= x"92"; wr_eof_in3 <= '1';
        wait until rising_edge(clk);

        clear_all_inputs;
        idle_cycles(20);

        check_count("TEST4", "Out0", s0 + 8, obs0_count, obs0, s0);
        check_byte("TEST4", "Out0", 0, x"61", obs0(s0+0), obs0, s0, obs0_count);
        check_byte("TEST4", "Out0", 1, x"62", obs0(s0+1), obs0, s0, obs0_count);
        check_byte("TEST4", "Out0", 2, x"71", obs0(s0+2), obs0, s0, obs0_count);
        check_byte("TEST4", "Out0", 3, x"72", obs0(s0+3), obs0, s0, obs0_count);
        check_byte("TEST4", "Out0", 4, x"81", obs0(s0+4), obs0, s0, obs0_count);
        check_byte("TEST4", "Out0", 5, x"82", obs0(s0+5), obs0, s0, obs0_count);
        check_byte("TEST4", "Out0", 6, x"91", obs0(s0+6), obs0, s0, obs0_count);
        check_byte("TEST4", "Out0", 7, x"92", obs0(s0+7), obs0, s0, obs0_count);

        -----------------------------------------------------------------------
        -- TEST 5: Two back-to-back frames in same VOQ
        -----------------------------------------------------------------------
        report "Starting TEST5: two back-to-back frames in same VOQ" severity note;
        apply_reset;
        s2 := obs2_count;

        send_frame(wr_data_in3, wr_eof_in3, wr_en_in3, 2, x"A1", x"A2", x"A3", x"00", 3);
        idle_cycles(1);
        send_frame(wr_data_in3, wr_eof_in3, wr_en_in3, 2, x"B1", x"B2", x"00", x"00", 2);
        idle_cycles(16);

        check_count("TEST5", "Out2", s2 + 5, obs2_count, obs2, s2);
        check_byte("TEST5", "Out2", 0, x"A1", obs2(s2+0), obs2, s2, obs2_count);
        check_byte("TEST5", "Out2", 1, x"A2", obs2(s2+1), obs2, s2, obs2_count);
        check_byte("TEST5", "Out2", 2, x"A3", obs2(s2+2), obs2, s2, obs2_count);
        check_byte("TEST5", "Out2", 3, x"B1", obs2(s2+3), obs2, s2, obs2_count);
        check_byte("TEST5", "Out2", 4, x"B2", obs2(s2+4), obs2, s2, obs2_count);

        assert false report "All switch_core tests passed." severity note;
        wait;
    end process;

end architecture sim;
