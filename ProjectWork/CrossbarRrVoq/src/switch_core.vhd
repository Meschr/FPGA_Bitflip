-------------------------------------------------------------------------------
-- switch_core.vhd
-- Top-Level: VOQ-Matrix + 4× Round-Robin + Crossbar-Switch
--
-- Verdrahtung:
--   voq_matrix  ←→  round_robin (frame_rdy, rd_en/grant)
--   round_robin  →  crossbar_switch (sel)
--   voq_matrix   →  crossbar_switch (rd_data)
--   EOF-MUX pro Ausgang: wählt rd_eof_outX(sel) → round_robin eof
--
-- Schreibseite der VOQ-Matrix bleibt als externer Port (für Testbench/FCS).
-- Full-Signale ebenfalls nach außen (Backpressure an FCS-Block).
--
-- DTU Fotonik - FPGA Design for Communications Systems
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity switch_core is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;

        -----------------------------------------------------------------------
        -- Schreibseite VOQ-Matrix (vom FCS-Block / Testbench)
        -----------------------------------------------------------------------
        wr_data_in0 : in  std_logic_vector(7 downto 0);
        wr_eof_in0  : in  std_logic;
        wr_en_in0   : in  std_logic_vector(3 downto 0);  -- (0)=Out0..(3)=Out3

        wr_data_in1 : in  std_logic_vector(7 downto 0);
        wr_eof_in1  : in  std_logic;
        wr_en_in1   : in  std_logic_vector(3 downto 0);

        wr_data_in2 : in  std_logic_vector(7 downto 0);
        wr_eof_in2  : in  std_logic;
        wr_en_in2   : in  std_logic_vector(3 downto 0);

        wr_data_in3 : in  std_logic_vector(7 downto 0);
        wr_eof_in3  : in  std_logic;
        wr_en_in3   : in  std_logic_vector(3 downto 0);

        -----------------------------------------------------------------------
        -- Backpressure (zum FCS-Block / Testbench)
        -- full_inX(Y) = FIFO InX→OutY ist voll
        -----------------------------------------------------------------------
        full_in0    : out std_logic_vector(3 downto 0);
        full_in1    : out std_logic_vector(3 downto 0);
        full_in2    : out std_logic_vector(3 downto 0);
        full_in3    : out std_logic_vector(3 downto 0);

        -----------------------------------------------------------------------
        -- Switch-Ausgänge (8-Bit GMII Daten)
        -----------------------------------------------------------------------
        out_data_0  : out std_logic_vector(7 downto 0);
        out_data_1  : out std_logic_vector(7 downto 0);
        out_data_2  : out std_logic_vector(7 downto 0);
        out_data_3  : out std_logic_vector(7 downto 0)
    );
end entity switch_core;

architecture rtl of switch_core is

    ---------------------------------------------------------------------------
    -- Interne Signale: VOQ-Matrix Leseseite
    ---------------------------------------------------------------------------

    -- rd_en pro Ausgang (von Round-Robin grant)
    signal rd_en_out0 : std_logic_vector(3 downto 0);
    signal rd_en_out1 : std_logic_vector(3 downto 0);
    signal rd_en_out2 : std_logic_vector(3 downto 0);
    signal rd_en_out3 : std_logic_vector(3 downto 0);

    -- rd_data: 4 Eingänge × 4 Ausgänge = 16 Datenleitungen
    signal rd_data_in0_out0 : std_logic_vector(7 downto 0);
    signal rd_data_in1_out0 : std_logic_vector(7 downto 0);
    signal rd_data_in2_out0 : std_logic_vector(7 downto 0);
    signal rd_data_in3_out0 : std_logic_vector(7 downto 0);

    signal rd_data_in0_out1 : std_logic_vector(7 downto 0);
    signal rd_data_in1_out1 : std_logic_vector(7 downto 0);
    signal rd_data_in2_out1 : std_logic_vector(7 downto 0);
    signal rd_data_in3_out1 : std_logic_vector(7 downto 0);

    signal rd_data_in0_out2 : std_logic_vector(7 downto 0);
    signal rd_data_in1_out2 : std_logic_vector(7 downto 0);
    signal rd_data_in2_out2 : std_logic_vector(7 downto 0);
    signal rd_data_in3_out2 : std_logic_vector(7 downto 0);

    signal rd_data_in0_out3 : std_logic_vector(7 downto 0);
    signal rd_data_in1_out3 : std_logic_vector(7 downto 0);
    signal rd_data_in2_out3 : std_logic_vector(7 downto 0);
    signal rd_data_in3_out3 : std_logic_vector(7 downto 0);

    -- rd_eof: 4-Bit-Vektor pro Ausgang (je ein Bit pro Eingang)
    signal rd_eof_out0 : std_logic_vector(3 downto 0);
    signal rd_eof_out1 : std_logic_vector(3 downto 0);
    signal rd_eof_out2 : std_logic_vector(3 downto 0);
    signal rd_eof_out3 : std_logic_vector(3 downto 0);

    -- frame_rdy: 4-Bit-Vektor pro Ausgang
    signal frame_rdy_out0 : std_logic_vector(3 downto 0);
    signal frame_rdy_out1 : std_logic_vector(3 downto 0);
    signal frame_rdy_out2 : std_logic_vector(3 downto 0);
    signal frame_rdy_out3 : std_logic_vector(3 downto 0);

    ---------------------------------------------------------------------------
    -- Interne Signale: Round-Robin Ausgänge
    ---------------------------------------------------------------------------
    signal rr0_sel    : std_logic_vector(1 downto 0);
    signal rr0_grant  : std_logic_vector(3 downto 0);

    signal rr1_sel    : std_logic_vector(1 downto 0);
    signal rr1_grant  : std_logic_vector(3 downto 0);

    signal rr2_sel    : std_logic_vector(1 downto 0);
    signal rr2_grant  : std_logic_vector(3 downto 0);

    signal rr3_sel    : std_logic_vector(1 downto 0);
    signal rr3_grant  : std_logic_vector(3 downto 0);

    ---------------------------------------------------------------------------
    -- EOF-MUX Ausgänge: jeweils ein Bit → Round-Robin eof Eingang
    ---------------------------------------------------------------------------
    signal eof_mux0 : std_logic;
    signal eof_mux1 : std_logic;
    signal eof_mux2 : std_logic;
    signal eof_mux3 : std_logic;

begin

    ---------------------------------------------------------------------------
    -- VOQ-Matrix Instanz
    ---------------------------------------------------------------------------
    u_voq_matrix : entity work.voq_matrix
        port map (
            clk             => clk,
            reset           => reset,
            -- Schreibseite (extern)
            wr_data_in0     => wr_data_in0,
            wr_eof_in0      => wr_eof_in0,
            wr_en_in0       => wr_en_in0,
            wr_data_in1     => wr_data_in1,
            wr_eof_in1      => wr_eof_in1,
            wr_en_in1       => wr_en_in1,
            wr_data_in2     => wr_data_in2,
            wr_eof_in2      => wr_eof_in2,
            wr_en_in2       => wr_en_in2,
            wr_data_in3     => wr_data_in3,
            wr_eof_in3      => wr_eof_in3,
            wr_en_in3       => wr_en_in3,
            -- Leseseite (intern)
            rd_en_out0      => rd_en_out0,
            rd_data_in0_out0 => rd_data_in0_out0,
            rd_data_in1_out0 => rd_data_in1_out0,
            rd_data_in2_out0 => rd_data_in2_out0,
            rd_data_in3_out0 => rd_data_in3_out0,
            rd_en_out1      => rd_en_out1,
            rd_data_in0_out1 => rd_data_in0_out1,
            rd_data_in1_out1 => rd_data_in1_out1,
            rd_data_in2_out1 => rd_data_in2_out1,
            rd_data_in3_out1 => rd_data_in3_out1,
            rd_en_out2      => rd_en_out2,
            rd_data_in0_out2 => rd_data_in0_out2,
            rd_data_in1_out2 => rd_data_in1_out2,
            rd_data_in2_out2 => rd_data_in2_out2,
            rd_data_in3_out2 => rd_data_in3_out2,
            rd_en_out3      => rd_en_out3,
            rd_data_in0_out3 => rd_data_in0_out3,
            rd_data_in1_out3 => rd_data_in1_out3,
            rd_data_in2_out3 => rd_data_in2_out3,
            rd_data_in3_out3 => rd_data_in3_out3,
            -- EOF beim Lesen
            rd_eof_out0     => rd_eof_out0,
            rd_eof_out1     => rd_eof_out1,
            rd_eof_out2     => rd_eof_out2,
            rd_eof_out3     => rd_eof_out3,
            -- Frame-Ready
            frame_rdy_out0  => frame_rdy_out0,
            frame_rdy_out1  => frame_rdy_out1,
            frame_rdy_out2  => frame_rdy_out2,
            frame_rdy_out3  => frame_rdy_out3,
            -- Backpressure (extern)
            full_in0        => full_in0,
            full_in1        => full_in1,
            full_in2        => full_in2,
            full_in3        => full_in3
        );

    ---------------------------------------------------------------------------
    -- EOF-MUX pro Ausgang (with...select)
    -- Wählt das EOF-Bit des aktuell vom RR gewählten Eingangs
    ---------------------------------------------------------------------------

    -- Ausgang 0: rd_eof_out0 hat 4 Bits, rr0_sel wählt welches
    with rr0_sel select
        eof_mux0 <= rd_eof_out0(0) when "00",
                    rd_eof_out0(1) when "01",
                    rd_eof_out0(2) when "10",
                    rd_eof_out0(3) when others;

    -- Ausgang 1
    with rr1_sel select
        eof_mux1 <= rd_eof_out1(0) when "00",
                    rd_eof_out1(1) when "01",
                    rd_eof_out1(2) when "10",
                    rd_eof_out1(3) when others;

    -- Ausgang 2
    with rr2_sel select
        eof_mux2 <= rd_eof_out2(0) when "00",
                    rd_eof_out2(1) when "01",
                    rd_eof_out2(2) when "10",
                    rd_eof_out2(3) when others;

    -- Ausgang 3
    with rr3_sel select
        eof_mux3 <= rd_eof_out3(0) when "00",
                    rd_eof_out3(1) when "01",
                    rd_eof_out3(2) when "10",
                    rd_eof_out3(3) when others;

    ---------------------------------------------------------------------------
    -- Round-Robin Instanzen (je eine pro Ausgangsport)
    -- grant → rd_en der VOQ-Matrix (one-hot = welches FIFO lesen)
    ---------------------------------------------------------------------------

    u_rr0 : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_out0,
            eof       => eof_mux0,
            sel       => rr0_sel,
            grant     => rr0_grant,
            active    => open
        );
    rd_en_out0 <= rr0_grant when eof_mux0 = '0' else "0000";

    u_rr1 : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_out1,
            eof       => eof_mux1,
            sel       => rr1_sel,
            grant     => rr1_grant,
            active    => open
        );
    rd_en_out1 <= rr1_grant when eof_mux1 = '0' else "0000";

    u_rr2 : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_out2,
            eof       => eof_mux2,
            sel       => rr2_sel,
            grant     => rr2_grant,
            active    => open
        );
    rd_en_out2 <= rr2_grant when eof_mux2 = '0' else "0000";

    u_rr3 : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_out3,
            eof       => eof_mux3,
            sel       => rr3_sel,
            grant     => rr3_grant,
            active    => open
        );
    rd_en_out3 <= rr3_grant when eof_mux3 = '0' else "0000";

    ---------------------------------------------------------------------------
    -- Crossbar-Switch Instanz
    -- data_mX_iY = rd_data von FIFO InY→OutX
    ---------------------------------------------------------------------------
    u_crossbar : entity work.crossbar_switch
        port map (
            clk         => clk,
            reset       => reset,
            -- MUX 0 (Destination 0)
            data_m0_i0  => rd_data_in0_out0,
            data_m0_i1  => rd_data_in1_out0,
            data_m0_i2  => rd_data_in2_out0,
            data_m0_i3  => rd_data_in3_out0,
            -- MUX 1 (Destination 1)
            data_m1_i0  => rd_data_in0_out1,
            data_m1_i1  => rd_data_in1_out1,
            data_m1_i2  => rd_data_in2_out1,
            data_m1_i3  => rd_data_in3_out1,
            -- MUX 2 (Destination 2)
            data_m2_i0  => rd_data_in0_out2,
            data_m2_i1  => rd_data_in1_out2,
            data_m2_i2  => rd_data_in2_out2,
            data_m2_i3  => rd_data_in3_out2,
            -- MUX 3 (Destination 3)
            data_m3_i0  => rd_data_in0_out3,
            data_m3_i1  => rd_data_in1_out3,
            data_m3_i2  => rd_data_in2_out3,
            data_m3_i3  => rd_data_in3_out3,
            -- Select von Round-Robin
            sel_0       => rr0_sel,
            sel_1       => rr1_sel,
            sel_2       => rr2_sel,
            sel_3       => rr3_sel,
            -- Ausgänge
            out_data_0  => out_data_0,
            out_data_1  => out_data_1,
            out_data_2  => out_data_2,
            out_data_3  => out_data_3
        );

end architecture rtl;
