-------------------------------------------------------------------------------
-- tb_voq_matrix.vhd
-- Testbench für VOQ-Matrix mit Vektor-Ports
--
-- Tests:
--   1. Reset: alle FIFOs leer
--   2. Unicast: In0 ? Out2
--   3. Broadcast: In1 ? Out0, Out2, Out3 (nicht Out1 = eigener Port)
--   4. Zwei Eingänge gleichzeitig
--   5. Frame auslesen und Daten prüfen
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_voq_matrix is
end entity tb_voq_matrix;

architecture sim of tb_voq_matrix is

    constant CLK_PERIOD : time := 8 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- Schreibseite
    signal wr_data_in0, wr_data_in1 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_data_in2, wr_data_in3 : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_eof_in0, wr_eof_in1   : std_logic := '0';
    signal wr_eof_in2, wr_eof_in3   : std_logic := '0';
    signal wr_en_in0, wr_en_in1     : std_logic_vector(3 downto 0) := "0000";
    signal wr_en_in2, wr_en_in3     : std_logic_vector(3 downto 0) := "0000";

    -- Leseseite: rd_en als Vektoren
    signal rd_en_out0, rd_en_out1   : std_logic_vector(3 downto 0) := "0000";
    signal rd_en_out2, rd_en_out3   : std_logic_vector(3 downto 0) := "0000";

    -- Leseseite: rd_data (einzeln, 8 Bit pro FIFO)
    signal rd_data_in0_out0, rd_data_in1_out0 : std_logic_vector(7 downto 0);
    signal rd_data_in2_out0, rd_data_in3_out0 : std_logic_vector(7 downto 0);
    signal rd_data_in0_out1, rd_data_in1_out1 : std_logic_vector(7 downto 0);
    signal rd_data_in2_out1, rd_data_in3_out1 : std_logic_vector(7 downto 0);
    signal rd_data_in0_out2, rd_data_in1_out2 : std_logic_vector(7 downto 0);
    signal rd_data_in2_out2, rd_data_in3_out2 : std_logic_vector(7 downto 0);
    signal rd_data_in0_out3, rd_data_in1_out3 : std_logic_vector(7 downto 0);
    signal rd_data_in2_out3, rd_data_in3_out3 : std_logic_vector(7 downto 0);

    -- EOF, frame_rdy, full als Vektoren
    signal rd_eof_out0, rd_eof_out1         : std_logic_vector(3 downto 0);
    signal rd_eof_out2, rd_eof_out3         : std_logic_vector(3 downto 0);
    signal frame_rdy_out0, frame_rdy_out1   : std_logic_vector(3 downto 0);
    signal frame_rdy_out2, frame_rdy_out3   : std_logic_vector(3 downto 0);
    signal full_in0, full_in1               : std_logic_vector(3 downto 0);
    signal full_in2, full_in3               : std_logic_vector(3 downto 0);

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.voq_matrix
        port map (
            clk => clk, reset => reset,
            -- Schreibseite
            wr_data_in0 => wr_data_in0, wr_eof_in0 => wr_eof_in0, wr_en_in0 => wr_en_in0,
            wr_data_in1 => wr_data_in1, wr_eof_in1 => wr_eof_in1, wr_en_in1 => wr_en_in1,
            wr_data_in2 => wr_data_in2, wr_eof_in2 => wr_eof_in2, wr_en_in2 => wr_en_in2,
            wr_data_in3 => wr_data_in3, wr_eof_in3 => wr_eof_in3, wr_en_in3 => wr_en_in3,
            -- Leseseite Out0
            rd_en_out0 => rd_en_out0,
            rd_data_in0_out0 => rd_data_in0_out0, rd_data_in1_out0 => rd_data_in1_out0,
            rd_data_in2_out0 => rd_data_in2_out0, rd_data_in3_out0 => rd_data_in3_out0,
            -- Leseseite Out1
            rd_en_out1 => rd_en_out1,
            rd_data_in0_out1 => rd_data_in0_out1, rd_data_in1_out1 => rd_data_in1_out1,
            rd_data_in2_out1 => rd_data_in2_out1, rd_data_in3_out1 => rd_data_in3_out1,
            -- Leseseite Out2
            rd_en_out2 => rd_en_out2,
            rd_data_in0_out2 => rd_data_in0_out2, rd_data_in1_out2 => rd_data_in1_out2,
            rd_data_in2_out2 => rd_data_in2_out2, rd_data_in3_out2 => rd_data_in3_out2,
            -- Leseseite Out3
            rd_en_out3 => rd_en_out3,
            rd_data_in0_out3 => rd_data_in0_out3, rd_data_in1_out3 => rd_data_in1_out3,
            rd_data_in2_out3 => rd_data_in2_out3, rd_data_in3_out3 => rd_data_in3_out3,
            -- EOF
            rd_eof_out0 => rd_eof_out0, rd_eof_out1 => rd_eof_out1,
            rd_eof_out2 => rd_eof_out2, rd_eof_out3 => rd_eof_out3,
            -- frame_rdy
            frame_rdy_out0 => frame_rdy_out0, frame_rdy_out1 => frame_rdy_out1,
            frame_rdy_out2 => frame_rdy_out2, frame_rdy_out3 => frame_rdy_out3,
            -- full
            full_in0 => full_in0, full_in1 => full_in1,
            full_in2 => full_in2, full_in3 => full_in3
        );

    stim : process
    begin
        -----------------------------------------------------------------------
        -- TEST 1: Reset
        -----------------------------------------------------------------------
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';
        wait for CLK_PERIOD; wait for 1 ns;

        assert frame_rdy_out0 = "0000" and frame_rdy_out1 = "0000"
           and frame_rdy_out2 = "0000" and frame_rdy_out3 = "0000"
            report "T1 FAIL: frame_rdy nicht 0000 nach Reset" severity error;
        assert full_in0 = "0000" and full_in1 = "0000"
            report "T1 FAIL: full nach Reset" severity error;
        report "TEST 1 PASSED: Reset";

        -----------------------------------------------------------------------
        -- TEST 2: Unicast ? Frame von In0 nach Out2
        -- wr_en_in0 = "0100" ? nur Bit 2 aktiv ? nur FIFO In0?Out2
        -- Frame: 0xA0, 0xA1, 0xA2+EOF
        -----------------------------------------------------------------------
        report "TEST 2: Unicast In0 -> Out2";

        wr_en_in0 <= "0100";  -- nur Out2
        wr_data_in0 <= x"A0"; wr_eof_in0 <= '0'; wait for CLK_PERIOD;
        wr_data_in0 <= x"A1"; wr_eof_in0 <= '0'; wait for CLK_PERIOD;
        wr_data_in0 <= x"A2"; wr_eof_in0 <= '1'; wait for CLK_PERIOD;
        wr_en_in0 <= "0000"; wr_eof_in0 <= '0';
        wait for CLK_PERIOD; wait for 1 ns;

        -- Nur FIFO In0?Out2 hat Frame (Bit 0 von frame_rdy_out2 = In0)
        assert frame_rdy_out2(0) = '1'
            report "T2 FAIL: frame_rdy_out2(0) nicht gesetzt" severity error;
        -- Alle anderen frame_rdy-Bits fuer In0 muessen '0' sein
        assert frame_rdy_out0(0) = '0' and frame_rdy_out1(0) = '0'
           and frame_rdy_out3(0) = '0'
            report "T2 FAIL: andere FIFOs von In0 nicht leer" severity error;
        -- Andere Eingänge für Out2 muessen leer sein
        assert frame_rdy_out2(1) = '0' and frame_rdy_out2(2) = '0'
           and frame_rdy_out2(3) = '0'
            report "T2 FAIL: andere Eingaenge fuer Out2 nicht leer" severity error;
        report "TEST 2 PASSED: Unicast korrekt";

        -----------------------------------------------------------------------
        -- TEST 3: Broadcast ? Frame von In1 nach Out0, Out2, Out3
        -- wr_en_in1 = "1101" ? Bit 0, 2, 3 aktiv (nicht Bit 1 = eigener Port)
        -- Frame: 0xBB, 0xBC+EOF
        -----------------------------------------------------------------------
        report "TEST 3: Broadcast In1 -> Out0, Out2, Out3";

        wr_en_in1 <= "1101";  -- Out0, Out2, Out3 (nicht Out1)
        wr_data_in1 <= x"BB"; wr_eof_in1 <= '0'; wait for CLK_PERIOD;
        wr_data_in1 <= x"BC"; wr_eof_in1 <= '1'; wait for CLK_PERIOD;
        wr_en_in1 <= "0000"; wr_eof_in1 <= '0';
        wait for CLK_PERIOD; wait for 1 ns;

        -- 3 FIFOs haben Frame (In1 = Bit 1 in jedem frame_rdy Vektor)
        assert frame_rdy_out0(1) = '1'
            report "T3 FAIL: frame_rdy_out0(1)" severity error;
        assert frame_rdy_out2(1) = '1'
            report "T3 FAIL: frame_rdy_out2(1)" severity error;
        assert frame_rdy_out3(1) = '1'
            report "T3 FAIL: frame_rdy_out3(1)" severity error;
        -- Out1 muss leer bleiben
        assert frame_rdy_out1(1) = '0'
            report "T3 FAIL: In1 zu Out1 sollte leer sein" severity error;
        report "TEST 3 PASSED: Broadcast korrekt";

        -----------------------------------------------------------------------
        -- TEST 4: Zwei Eingänge gleichzeitig
        -- In0zuOut1 und In2zuOut3
        -- Frame In0: 0xCC, 0xCD+EOF
        -- Frame In2: 0xDD, 0xDE+EOF
        -----------------------------------------------------------------------
        report "TEST 4: Zwei Eingaenge gleichzeitig";

        wr_en_in0 <= "0010";  -- Out1
        wr_en_in2 <= "1000";  -- Out3
        wr_data_in0 <= x"CC"; wr_eof_in0 <= '0';
        wr_data_in2 <= x"DD"; wr_eof_in2 <= '0';
        wait for CLK_PERIOD;
        wr_data_in0 <= x"CD"; wr_eof_in0 <= '1';
        wr_data_in2 <= x"DE"; wr_eof_in2 <= '1';
        wait for CLK_PERIOD;
        wr_en_in0 <= "0000"; wr_eof_in0 <= '0';
        wr_en_in2 <= "0000"; wr_eof_in2 <= '0';
        wait for CLK_PERIOD; wait for 1 ns;

        assert frame_rdy_out1(0) = '1'
            report "T4 FAIL: In0zuOut1" severity error;
        assert frame_rdy_out3(2) = '1'
            report "T4 FAIL: In2zuOut3" severity error;
        report "TEST 4 PASSED: Gleichzeitige Eingaenge";

        -----------------------------------------------------------------------
        -- TEST 5: Frame auslesen ? In0->Out2 (aus Test 2)
        -- Frame: 0xA0, 0xA1, 0xA2+EOF
        -- BRAM: Daten 1 Takt nach rd_en
        -----------------------------------------------------------------------
        report "TEST 5: Frame auslesen In0->Out2";

        -- rd_en_out2(0) = lese von In0 fuer Out2
        rd_en_out2 <= "0001";
        wait for CLK_PERIOD;       -- BRAM liest Byte 0
        --wait for CLK_PERIOD;       -- rd_reg hat Byte 0d
        
        wait for 1 ns;
        assert rd_data_in0_out2 = x"A0"
            report "T5 FAIL: Byte 0 erwartet 0xA0" severity error;
        assert rd_eof_out2(0) = '0'
            report "T5 FAIL: EOF bei Byte 0" severity error;

        wait for CLK_PERIOD; wait for 1 ns;
        assert rd_data_in0_out2 = x"A1"
            report "T5 FAIL: Byte 1 erwartet 0xA1" severity error;

        wait for CLK_PERIOD; wait for 1 ns;
        assert rd_data_in0_out2 = x"A2"
            report "T5 FAIL: Byte 2 erwartet 0xA2" severity error;
        assert rd_eof_out2(0) = '1'
            report "T5 FAIL: EOF fehlt bei Byte 2" severity error;

        rd_en_out2 <= "0000";
        wait for CLK_PERIOD * 2; wait for 1 ns;

        assert frame_rdy_out2(0) = '0'
            report "T5 FAIL: frame_rdy noch gesetzt" severity error;
        report "TEST 5 PASSED: Frame korrekt ausgelesen";

        -----------------------------------------------------------------------
        report "ALLE TESTS ABGESCHLOSSEN";
        wait;
    end process stim;

end architecture sim;