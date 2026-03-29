-------------------------------------------------------------------------------
-- voq_matrix.vhd
-- 16 VOQ-FIFOs (4 Eingänge × 4 Ziele), reine Verdrahtung
--
-- Keine Logik — nur Instanziierung und Verdrahtung der 16 FIFOs.
-- Der DEMUX sitzt im FCS-Block, nicht hier.
--
-- Vektor-Konvention:
--   wr_en_inX(Y)      = Eingangsport X schreibt in Ziel-FIFO Y
--   frame_rdy_outX(Y) = FIFO von Eingang Y nach Ausgang X hat Frame bereit
--   rd_en_outX(Y)     = MUX X liest von Eingang Y
--   rd_eof_outX(Y)    = EOF beim Lesen von FIFO InY→OutX
--   full_inX(Y)       = FIFO InX→OutY ist voll
--
-- DTU Fotonik - FPGA Design for Communications Systems
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity voq_matrix is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;

        -----------------------------------------------------------------------
        -- Schreibseite: vom FCS-Block
        -- wr_data/wr_eof pro Eingang (gleicher Frame an alle Ziel-FIFOs)
        -- wr_en_inX(Y) = '1' → schreibe in FIFO InX→OutY
        -----------------------------------------------------------------------
        wr_data_in0     : in  std_logic_vector(7 downto 0);
        wr_eof_in0      : in  std_logic;
        wr_en_in0       : in  std_logic_vector(3 downto 0);  -- (0)=Out0..(3)=Out3

        wr_data_in1     : in  std_logic_vector(7 downto 0);
        wr_eof_in1      : in  std_logic;
        wr_en_in1       : in  std_logic_vector(3 downto 0);

        wr_data_in2     : in  std_logic_vector(7 downto 0);
        wr_eof_in2      : in  std_logic;
        wr_en_in2       : in  std_logic_vector(3 downto 0);

        wr_data_in3     : in  std_logic_vector(7 downto 0);
        wr_eof_in3      : in  std_logic;
        wr_en_in3       : in  std_logic_vector(3 downto 0);

        -----------------------------------------------------------------------
        -- Leseseite: zum Crossbar-MUX
        -- rd_en_outX(Y) = RR von MUX X liest von Eingang Y
        -- rd_data bleibt einzeln (8 Bit pro FIFO, geht an MUX-Eingänge)
        -----------------------------------------------------------------------
        -- Ausgang 0
        rd_en_out0      : in  std_logic_vector(3 downto 0);  -- (0)=In0..(3)=In3
        rd_data_in0_out0: out std_logic_vector(7 downto 0);
        rd_data_in1_out0: out std_logic_vector(7 downto 0);
        rd_data_in2_out0: out std_logic_vector(7 downto 0);
        rd_data_in3_out0: out std_logic_vector(7 downto 0);

        -- Ausgang 1
        rd_en_out1      : in  std_logic_vector(3 downto 0);
        rd_data_in0_out1: out std_logic_vector(7 downto 0);
        rd_data_in1_out1: out std_logic_vector(7 downto 0);
        rd_data_in2_out1: out std_logic_vector(7 downto 0);
        rd_data_in3_out1: out std_logic_vector(7 downto 0);

        -- Ausgang 2
        rd_en_out2      : in  std_logic_vector(3 downto 0);
        rd_data_in0_out2: out std_logic_vector(7 downto 0);
        rd_data_in1_out2: out std_logic_vector(7 downto 0);
        rd_data_in2_out2: out std_logic_vector(7 downto 0);
        rd_data_in3_out2: out std_logic_vector(7 downto 0);

        -- Ausgang 3
        rd_en_out3      : in  std_logic_vector(3 downto 0);
        rd_data_in0_out3: out std_logic_vector(7 downto 0);
        rd_data_in1_out3: out std_logic_vector(7 downto 0);
        rd_data_in2_out3: out std_logic_vector(7 downto 0);
        rd_data_in3_out3: out std_logic_vector(7 downto 0);

        -----------------------------------------------------------------------
        -- EOF beim Lesen (→ Round-Robin für Frame-Lock)
        -- rd_eof_outX(Y) = EOF von FIFO InY→OutX
        -----------------------------------------------------------------------
        rd_eof_out0     : out std_logic_vector(3 downto 0);
        rd_eof_out1     : out std_logic_vector(3 downto 0);
        rd_eof_out2     : out std_logic_vector(3 downto 0);
        rd_eof_out3     : out std_logic_vector(3 downto 0);

        -----------------------------------------------------------------------
        -- frame_rdy (→ Round-Robin)
        -- frame_rdy_outX(Y) = FIFO InY→OutX hat kompletten Frame
        -----------------------------------------------------------------------
        frame_rdy_out0  : out std_logic_vector(3 downto 0);
        frame_rdy_out1  : out std_logic_vector(3 downto 0);
        frame_rdy_out2  : out std_logic_vector(3 downto 0);
        frame_rdy_out3  : out std_logic_vector(3 downto 0);

        -----------------------------------------------------------------------
        -- Full / Backpressure (→ FCS-Block)
        -- full_inX(Y) = FIFO InX→OutY ist voll
        -----------------------------------------------------------------------
        full_in0        : out std_logic_vector(3 downto 0);
        full_in1        : out std_logic_vector(3 downto 0);
        full_in2        : out std_logic_vector(3 downto 0);
        full_in3        : out std_logic_vector(3 downto 0)
    );
end entity voq_matrix;

architecture rtl of voq_matrix is
begin

    ---------------------------------------------------------------------------
    -- Eingang 0: 4 FIFOs (In0→Out0, In0→Out1, In0→Out2, In0→Out3)
    ---------------------------------------------------------------------------

    fifo_in0_out0 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in0(0),   wr_data   => wr_data_in0,
            wr_eof    => wr_eof_in0,     rd_en     => rd_en_out0(0),
            rd_data   => rd_data_in0_out0,
            rd_eof    => rd_eof_out0(0),
            frame_rdy => frame_rdy_out0(0),
            full      => full_in0(0),    empty     => open
        );

    fifo_in0_out1 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in0(1),   wr_data   => wr_data_in0,
            wr_eof    => wr_eof_in0,     rd_en     => rd_en_out1(0),
            rd_data   => rd_data_in0_out1,
            rd_eof    => rd_eof_out1(0),
            frame_rdy => frame_rdy_out1(0),
            full      => full_in0(1),    empty     => open
        );

    fifo_in0_out2 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in0(2),   wr_data   => wr_data_in0,
            wr_eof    => wr_eof_in0,     rd_en     => rd_en_out2(0),
            rd_data   => rd_data_in0_out2,
            rd_eof    => rd_eof_out2(0),
            frame_rdy => frame_rdy_out2(0),
            full      => full_in0(2),    empty     => open
        );

    fifo_in0_out3 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in0(3),   wr_data   => wr_data_in0,
            wr_eof    => wr_eof_in0,     rd_en     => rd_en_out3(0),
            rd_data   => rd_data_in0_out3,
            rd_eof    => rd_eof_out3(0),
            frame_rdy => frame_rdy_out3(0),
            full      => full_in0(3),    empty     => open
        );

    ---------------------------------------------------------------------------
    -- Eingang 1: 4 FIFOs (In1→Out0, In1→Out1, In1→Out2, In1→Out3)
    ---------------------------------------------------------------------------

    fifo_in1_out0 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in1(0),   wr_data   => wr_data_in1,
            wr_eof    => wr_eof_in1,     rd_en     => rd_en_out0(1),
            rd_data   => rd_data_in1_out0,
            rd_eof    => rd_eof_out0(1),
            frame_rdy => frame_rdy_out0(1),
            full      => full_in1(0),    empty     => open
        );

    fifo_in1_out1 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in1(1),   wr_data   => wr_data_in1,
            wr_eof    => wr_eof_in1,     rd_en     => rd_en_out1(1),
            rd_data   => rd_data_in1_out1,
            rd_eof    => rd_eof_out1(1),
            frame_rdy => frame_rdy_out1(1),
            full      => full_in1(1),    empty     => open
        );

    fifo_in1_out2 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in1(2),   wr_data   => wr_data_in1,
            wr_eof    => wr_eof_in1,     rd_en     => rd_en_out2(1),
            rd_data   => rd_data_in1_out2,
            rd_eof    => rd_eof_out2(1),
            frame_rdy => frame_rdy_out2(1),
            full      => full_in1(2),    empty     => open
        );

    fifo_in1_out3 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in1(3),   wr_data   => wr_data_in1,
            wr_eof    => wr_eof_in1,     rd_en     => rd_en_out3(1),
            rd_data   => rd_data_in1_out3,
            rd_eof    => rd_eof_out3(1),
            frame_rdy => frame_rdy_out3(1),
            full      => full_in1(3),    empty     => open
        );

    ---------------------------------------------------------------------------
    -- Eingang 2: 4 FIFOs (In2→Out0, In2→Out1, In2→Out2, In2→Out3)
    ---------------------------------------------------------------------------

    fifo_in2_out0 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in2(0),   wr_data   => wr_data_in2,
            wr_eof    => wr_eof_in2,     rd_en     => rd_en_out0(2),
            rd_data   => rd_data_in2_out0,
            rd_eof    => rd_eof_out0(2),
            frame_rdy => frame_rdy_out0(2),
            full      => full_in2(0),    empty     => open
        );

    fifo_in2_out1 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in2(1),   wr_data   => wr_data_in2,
            wr_eof    => wr_eof_in2,     rd_en     => rd_en_out1(2),
            rd_data   => rd_data_in2_out1,
            rd_eof    => rd_eof_out1(2),
            frame_rdy => frame_rdy_out1(2),
            full      => full_in2(1),    empty     => open
        );

    fifo_in2_out2 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in2(2),   wr_data   => wr_data_in2,
            wr_eof    => wr_eof_in2,     rd_en     => rd_en_out2(2),
            rd_data   => rd_data_in2_out2,
            rd_eof    => rd_eof_out2(2),
            frame_rdy => frame_rdy_out2(2),
            full      => full_in2(2),    empty     => open
        );

    fifo_in2_out3 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in2(3),   wr_data   => wr_data_in2,
            wr_eof    => wr_eof_in2,     rd_en     => rd_en_out3(2),
            rd_data   => rd_data_in2_out3,
            rd_eof    => rd_eof_out3(2),
            frame_rdy => frame_rdy_out3(2),
            full      => full_in2(3),    empty     => open
        );

    ---------------------------------------------------------------------------
    -- Eingang 3: 4 FIFOs (In3→Out0, In3→Out1, In3→Out2, In3→Out3)
    ---------------------------------------------------------------------------

    fifo_in3_out0 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in3(0),   wr_data   => wr_data_in3,
            wr_eof    => wr_eof_in3,     rd_en     => rd_en_out0(3),
            rd_data   => rd_data_in3_out0,
            rd_eof    => rd_eof_out0(3),
            frame_rdy => frame_rdy_out0(3),
            full      => full_in3(0),    empty     => open
        );

    fifo_in3_out1 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in3(1),   wr_data   => wr_data_in3,
            wr_eof    => wr_eof_in3,     rd_en     => rd_en_out1(3),
            rd_data   => rd_data_in3_out1,
            rd_eof    => rd_eof_out1(3),
            frame_rdy => frame_rdy_out1(3),
            full      => full_in3(1),    empty     => open
        );

    fifo_in3_out2 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in3(2),   wr_data   => wr_data_in3,
            wr_eof    => wr_eof_in3,     rd_en     => rd_en_out2(3),
            rd_data   => rd_data_in3_out2,
            rd_eof    => rd_eof_out2(3),
            frame_rdy => frame_rdy_out2(3),
            full      => full_in3(2),    empty     => open
        );

    fifo_in3_out3 : entity work.voq_fifo
        generic map (DEPTH => 4096)
        port map (
            clk       => clk,            reset     => reset,
            wr_en     => wr_en_in3(3),   wr_data   => wr_data_in3,
            wr_eof    => wr_eof_in3,     rd_en     => rd_en_out3(3),
            rd_data   => rd_data_in3_out3,
            rd_eof    => rd_eof_out3(3),
            frame_rdy => frame_rdy_out3(3),
            full      => full_in3(3),    empty     => open
        );

end architecture rtl;
