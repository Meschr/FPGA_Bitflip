-- =============================================================================
-- Top-Level Module: voq_rr_crossbar_switch_top
--
-- Purpose:
--   4x4 VOQ (Virtual Output Queuing) switch with round-robin arbitration
--   and a crossbar output stage.
--
-- Architecture overview:
--   For each of the 4 outputs there is an independent VOQ bundle:
--     - voq_4to1   : 4 FIFOs (one per input) buffering frames for that output.
--     - round_robin: Arbiter choosing which FIFO may read next. The grant is
--                    held until an entire frame is transmitted (locked to EOF).
--     - crossbar_switch: Routes the selected FIFO stream to the output
--                    (controlled by rr_sel).
--
-- Data flow example (input 2 -> output 1):
--   wr_data_in2_out1 --> VOQ(out1).FIFO(in2) --> round_robin(out1) grant
--   --> rd_en_o1(2) = '1' --> rd_data_o1_2 --> crossbar (sel_1="10") --> out_data_1
--
-- VOQ principle:
--   Each input can write to up to 4 FIFOs (one per destination output),
--   avoiding head-of-line blocking seen in shared-memory switches.
--
-- Interface convention:
--   wr_data_inX_outY : write data from input X to output Y
--   wr_en_inX_outY   : write enable (active high)
--   wr_eof_inX_outY  : end-of-frame mark on the last byte of a frame
--   out_data_Y       : output data for output Y
--   out_valid_Y      : output data valid (FIFO not empty)
--
-- Key internal signals:
--   frame_rdy_oX  : 4-bit vector, bit i = '1' if FIFO(i) of queue X has a
--                   complete frame (at least one EOF seen)
--   rr_sel_oX     : 2-bit index of the currently served FIFO (0..3)
--   rr_grant_oX   : one-hot read enable for the 4 FIFOs of queue X
--                   (e.g. "0100" = FIFO 2 may read)
--   eof_mux_oX    : EOF of the FIFO currently selected by the RR arbiter;
--                   signals end of frame to the arbiter
--   rd_en_oX      : driven directly by rr_grant_oX -> FIFO read enable
--
-- Generics:
--   DEPTH : depth of each VOQ FIFO in bytes (default: 4096)
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity voq_rr_crossbar_switch_top is
    generic (
        DEPTH : INTEGER := 4096 -- Tiefe jedes einzelnen VOQ-FIFOs in Byte
    );
    port (
        clk   : in STD_LOGIC; -- System clock (rising edge)
        reset : in STD_LOGIC; -- Synchronous reset, active high

        -- Flush signals: reset the FIFOs of an output queue.
        -- Bit i = '1' clears FIFO i of the respective queue immediately.
        flush_out0 : in STD_LOGIC_VECTOR(3 downto 0); -- Queue for output 0
        flush_out1 : in STD_LOGIC_VECTOR(3 downto 0); -- Queue for output 1
        flush_out2 : in STD_LOGIC_VECTOR(3 downto 0); -- Queue for output 2
        flush_out3 : in STD_LOGIC_VECTOR(3 downto 0); -- Queue for output 3

        -- =====================================================================
        -- Write side: 4 input ports x 4 destination ports = 16 separate channels
        -- Each channel writes bytes into the associated VOQ FIFO.
        -- =====================================================================

        -- Input 0: frames from port 0 to each of the 4 outputs
        wr_en_in0    : in STD_LOGIC_VECTOR(3 downto 0); -- Write enable
        wr_data_in0  : in STD_LOGIC_VECTOR(7 downto 0); -- Data byte
        wr_eof_in0   : in STD_LOGIC;                    -- '1' on last byte of frame
        wr_abort_in0 : in STD_LOGIC;                    -- '1' drops the current frame from input 0
        -- Input 1: frames from port 1 to each of the 4 outputs
        wr_en_in1    : in STD_LOGIC_VECTOR(3 downto 0); -- Write enable
        wr_data_in1  : in STD_LOGIC_VECTOR(7 downto 0); -- Data byte
        wr_eof_in1   : in STD_LOGIC;
        wr_abort_in1 : in STD_LOGIC; -- '1' drops the current frame from input 1
        -- Input 2: frames from port 2 to each of the 4 outputs
        wr_en_in2    : in STD_LOGIC_VECTOR(3 downto 0); -- Write enable
        wr_data_in2  : in STD_LOGIC_VECTOR(7 downto 0); -- Data byte
        wr_eof_in2   : in STD_LOGIC;
        wr_abort_in2 : in STD_LOGIC; -- '1' drops the current frame from input 2

        -- Input 3: frames from port 3 to each of the 4 outputs
        wr_en_in3    : in STD_LOGIC_VECTOR(3 downto 0); -- Write enable
        wr_data_in3  : in STD_LOGIC_VECTOR(7 downto 0); -- Data byte
        wr_eof_in3   : in STD_LOGIC;
        wr_abort_in3 : in STD_LOGIC; -- '1' drops the current frame from input 3
        -- =====================================================================
        -- Output side: payload data and valid flag per output port
        -- =====================================================================
        out_data_0 : out STD_LOGIC_VECTOR(7 downto 0); -- Output data for output 0
        out_data_1 : out STD_LOGIC_VECTOR(7 downto 0); -- Output data for output 1
        out_data_2 : out STD_LOGIC_VECTOR(7 downto 0); -- Output data for output 2
        out_data_3 : out STD_LOGIC_VECTOR(7 downto 0); -- Output data for output 3

        -- Valid = '1': output data is valid (at least one FIFO active)
        out_valid_0 : out STD_LOGIC;
        out_valid_1 : out STD_LOGIC;
        out_valid_2 : out STD_LOGIC;
        out_valid_3 : out STD_LOGIC

    );
end entity;

architecture rtl of voq_rr_crossbar_switch_top is

    ---------------------------------------------------------------------------
    -- Internal signals for output queue 0
    -- Connect voq_4to1, round_robin, and crossbar for output 0.
    ---------------------------------------------------------------------------

    -- One-hot read enable: bit i = '1' -> FIFO i of queue 0 may read.
    -- Driven directly by the RR grant.
    signal rd_en_o0 : STD_LOGIC_VECTOR(3 downto 0);

    -- Output data of the four FIFOs in queue 0 (one byte per cycle)
    -- rd_data_o0_i: read data of FIFO from input i, destined for output 0
    signal rd_data_o0_0 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o0_1 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o0_2 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o0_3 : STD_LOGIC_VECTOR(7 downto 0);

    -- EOF flags of the four FIFOs (bit i = '1': current byte is end of frame)
    signal rd_eof_o0 : STD_LOGIC_VECTOR(3 downto 0);
    -- Frame-ready flags (bit i = '1': FIFO i has a complete frame)
    signal frame_rdy_o0 : STD_LOGIC_VECTOR(3 downto 0);
    -- Full/empty status of the four FIFOs
    signal full_o0  : STD_LOGIC_VECTOR(3 downto 0);
    signal empty_o0 : STD_LOGIC_VECTOR(3 downto 0);

    -- RR output signals for queue 0
    signal rr_sel_o0    : STD_LOGIC_VECTOR(1 downto 0); -- Index of granted FIFO
    signal rr_grant_o0  : STD_LOGIC_VECTOR(3 downto 0); -- One-hot grant
    signal rr_active_o0 : STD_LOGIC;                    -- Arbiter busy
    -- EOF of the FIFO currently selected by RR (via MUX from rd_eof_o0)
    signal eof_mux_o0 : STD_LOGIC;

    ---------------------------------------------------------------------------
    -- Internal signals for output queue 1 (same as queue 0)
    ---------------------------------------------------------------------------
    signal rd_en_o1 : STD_LOGIC_VECTOR(3 downto 0);

    signal rd_data_o1_0 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o1_1 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o1_2 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o1_3 : STD_LOGIC_VECTOR(7 downto 0);

    signal rd_eof_o1    : STD_LOGIC_VECTOR(3 downto 0);
    signal frame_rdy_o1 : STD_LOGIC_VECTOR(3 downto 0);
    signal full_o1      : STD_LOGIC_VECTOR(3 downto 0);
    signal empty_o1     : STD_LOGIC_VECTOR(3 downto 0);

    signal rr_sel_o1    : STD_LOGIC_VECTOR(1 downto 0);
    signal rr_grant_o1  : STD_LOGIC_VECTOR(3 downto 0);
    signal rr_active_o1 : STD_LOGIC;
    signal eof_mux_o1   : STD_LOGIC;

    ---------------------------------------------------------------------------
    -- Internal signals for output queue 2 (same as queue 0)
    ---------------------------------------------------------------------------
    signal rd_en_o2 : STD_LOGIC_VECTOR(3 downto 0);

    signal rd_data_o2_0 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o2_1 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o2_2 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o2_3 : STD_LOGIC_VECTOR(7 downto 0);

    signal rd_eof_o2    : STD_LOGIC_VECTOR(3 downto 0);
    signal frame_rdy_o2 : STD_LOGIC_VECTOR(3 downto 0);
    signal full_o2      : STD_LOGIC_VECTOR(3 downto 0);
    signal empty_o2     : STD_LOGIC_VECTOR(3 downto 0);

    signal rr_sel_o2    : STD_LOGIC_VECTOR(1 downto 0);
    signal rr_grant_o2  : STD_LOGIC_VECTOR(3 downto 0);
    signal rr_active_o2 : STD_LOGIC;
    signal eof_mux_o2   : STD_LOGIC;

    ---------------------------------------------------------------------------
    -- Internal signals for output queue 3 (same as queue 0)
    ---------------------------------------------------------------------------
    signal rd_en_o3 : STD_LOGIC_VECTOR(3 downto 0);

    signal rd_data_o3_0 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o3_1 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o3_2 : STD_LOGIC_VECTOR(7 downto 0);
    signal rd_data_o3_3 : STD_LOGIC_VECTOR(7 downto 0);

    signal rd_eof_o3    : STD_LOGIC_VECTOR(3 downto 0);
    signal frame_rdy_o3 : STD_LOGIC_VECTOR(3 downto 0);
    signal full_o3      : STD_LOGIC_VECTOR(3 downto 0);
    signal empty_o3     : STD_LOGIC_VECTOR(3 downto 0);

    signal rr_sel_o3    : STD_LOGIC_VECTOR(1 downto 0);
    signal rr_grant_o3  : STD_LOGIC_VECTOR(3 downto 0);
    signal rr_active_o3 : STD_LOGIC;
    signal eof_mux_o3   : STD_LOGIC;

begin

    ---------------------------------------------------------------------------
    -- Output queue 0: VOQ bundle + round-robin arbitration
    --
    -- voq_4to1 bundles the 4 FIFOs (one per input) for output 0.
    -- The round-robin selects which FIFO may read.
    -- Control flow: frame_rdy -> RR -> grant -> rd_en -> FIFO read
    ---------------------------------------------------------------------------
    u_voq_out0 : entity work.voq_4to1
        generic map(DEPTH => DEPTH)
        port map(
            clk   => clk,
            reset => reset,
            flush => flush_out0,

            -- Write ports: inputs 0..3, all destined for output 0
            wr_data_in0  => wr_data_in0,
            wr_en_in0    => wr_en_in0(0),
            wr_eof_in0   => wr_eof_in0,
            wr_abort_in0 => wr_abort_in0,

            wr_data_in1  => wr_data_in1,
            wr_en_in1    => wr_en_in1(0),
            wr_eof_in1   => wr_eof_in1,
            wr_abort_in1 => wr_abort_in1,

            wr_data_in2  => wr_data_in2,
            wr_en_in2    => wr_en_in2(0),
            wr_eof_in2   => wr_eof_in2,
            wr_abort_in2 => wr_abort_in2,

            wr_data_in3  => wr_data_in3,
            wr_en_in3    => wr_en_in3(0),
            wr_eof_in3   => wr_eof_in3,
            wr_abort_in3 => wr_abort_in3,

            -- One-hot read enable: from RR arbiter (via rd_en_o0)
            rd_en => rd_en_o0,

            -- Output data of the 4 FIFOs (available in parallel, crossbar selects)
            rd_data_0 => rd_data_o0_0,
            rd_data_1 => rd_data_o0_1,
            rd_data_2 => rd_data_o0_2,
            rd_data_3 => rd_data_o0_3,

            rd_valid  => out_valid_0,  -- '1': at least one FIFO provides valid data
            rd_eof    => rd_eof_o0,    -- EOF flags of all 4 FIFOs
            frame_rdy => frame_rdy_o0, -- Frame-ready flags for RR input
            full      => full_o0,
            empty     => empty_o0
        );

    -- EOF MUX for queue 0:
    -- The RR arbiter needs the EOF of the currently served FIFO to
    -- detect end of frame and move to the next grant. rr_sel_o0 is the index (0..3).
    with rr_sel_o0 select
        eof_mux_o0 <= rd_eof_o0(0) when "00",
        rd_eof_o0(1) when "01",
        rd_eof_o0(2) when "10",
        rd_eof_o0(3) when others;

    -- Round-robin arbiter for queue 0:
    -- Waits for frame_rdy, issues a grant, holds it until EOF ('1'),
    -- then advances to the next ready FIFO in round-robin order.
    u_rr_o0 : entity work.round_robin
        port map(
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_o0, -- Which FIFOs have a frame ready?
            eof       => eof_mux_o0,   -- End of current frame -> advance grant
            sel       => rr_sel_o0,    -- Current FIFO index (to crossbar)
            grant     => rr_grant_o0,  -- One-hot grant (to FIFO rd_en)
            active    => rr_active_o0  -- Arbiter is serving a frame
        );

    -- Use the grant directly as FIFO read enable
    rd_en_o0 <= rr_grant_o0;

    ---------------------------------------------------------------------------
    -- Output queue 1: VOQ bundle + round-robin arbitration (same as queue 0)
    ---------------------------------------------------------------------------
    u_voq_out1 : entity work.voq_4to1
        generic map(DEPTH => DEPTH)
        port map(
            clk   => clk,
            reset => reset,
            flush => flush_out1,

            wr_data_in0  => wr_data_in0,
            wr_en_in0    => wr_en_in0(1),
            wr_eof_in0   => wr_eof_in0,
            wr_abort_in0 => wr_abort_in0,

            wr_data_in1  => wr_data_in1,
            wr_en_in1    => wr_en_in1(1),
            wr_eof_in1   => wr_eof_in1,
            wr_abort_in1 => wr_abort_in1,

            wr_data_in2  => wr_data_in2,
            wr_en_in2    => wr_en_in2(1),
            wr_eof_in2   => wr_eof_in2,
            wr_abort_in2 => wr_abort_in2,

            wr_data_in3  => wr_data_in3,
            wr_en_in3    => wr_en_in3(1),
            wr_eof_in3   => wr_eof_in3,
            wr_abort_in3 => wr_abort_in3,

            rd_en => rd_en_o1,

            rd_data_0 => rd_data_o1_0,
            rd_data_1 => rd_data_o1_1,
            rd_data_2 => rd_data_o1_2,
            rd_data_3 => rd_data_o1_3,

            rd_valid  => out_valid_1,
            rd_eof    => rd_eof_o1,
            frame_rdy => frame_rdy_o1,
            full      => full_o1,
            empty     => empty_o1
        );

    -- EOF MUX for queue 1: select EOF of the currently granted FIFO
    with rr_sel_o1 select
        eof_mux_o1 <= rd_eof_o1(0) when "00",
        rd_eof_o1(1) when "01",
        rd_eof_o1(2) when "10",
        rd_eof_o1(3) when others;

    -- Round-robin arbiter for queue 1
    u_rr_o1 : entity work.round_robin
        port map(
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_o1,
            eof       => eof_mux_o1,
            sel       => rr_sel_o1,
            grant     => rr_grant_o1,
            active    => rr_active_o1
        );

    rd_en_o1 <= rr_grant_o1;

    ---------------------------------------------------------------------------
    -- Output queue 2: VOQ bundle + round-robin arbitration (same as queue 0)
    ---------------------------------------------------------------------------
    u_voq_out2 : entity work.voq_4to1
        generic map(DEPTH => DEPTH)
        port map(
            clk   => clk,
            reset => reset,
            flush => flush_out2,

            wr_data_in0  => wr_data_in0,
            wr_en_in0    => wr_en_in0(2),
            wr_eof_in0   => wr_eof_in0,
            wr_abort_in0 => wr_abort_in0,

            wr_data_in1  => wr_data_in1,
            wr_en_in1    => wr_en_in1(2),
            wr_eof_in1   => wr_eof_in1,
            wr_abort_in1 => wr_abort_in1,

            wr_data_in2  => wr_data_in2,
            wr_en_in2    => wr_en_in2(2),
            wr_eof_in2   => wr_eof_in2,
            wr_abort_in2 => wr_abort_in2,

            wr_data_in3  => wr_data_in3,
            wr_en_in3    => wr_en_in3(2),
            wr_eof_in3   => wr_eof_in3,
            wr_abort_in3 => wr_abort_in3,

            rd_en => rd_en_o2,

            rd_data_0 => rd_data_o2_0,
            rd_data_1 => rd_data_o2_1,
            rd_data_2 => rd_data_o2_2,
            rd_data_3 => rd_data_o2_3,

            rd_valid => out_valid_2,

            rd_eof    => rd_eof_o2,
            frame_rdy => frame_rdy_o2,
            full      => full_o2,
            empty     => empty_o2
        );

    -- EOF MUX for queue 2: select EOF of the currently granted FIFO
    with rr_sel_o2 select
        eof_mux_o2 <= rd_eof_o2(0) when "00",
        rd_eof_o2(1) when "01",
        rd_eof_o2(2) when "10",
        rd_eof_o2(3) when others;

    -- Round-robin arbiter for queue 2
    u_rr_o2 : entity work.round_robin
        port map(
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_o2,
            eof       => eof_mux_o2,
            sel       => rr_sel_o2,
            grant     => rr_grant_o2,
            active    => rr_active_o2
        );

    rd_en_o2 <= rr_grant_o2;

    ---------------------------------------------------------------------------
    -- Output queue 3: VOQ bundle + round-robin arbitration (same as queue 0)
    ---------------------------------------------------------------------------
    u_voq_out3 : entity work.voq_4to1
        generic map(DEPTH => DEPTH)
        port map(
            clk   => clk,
            reset => reset,
            flush => flush_out3,

            wr_data_in0  => wr_data_in0,
            wr_en_in0    => wr_en_in0(3),
            wr_eof_in0   => wr_eof_in0,
            wr_abort_in0 => wr_abort_in0,

            wr_data_in1  => wr_data_in1,
            wr_en_in1    => wr_en_in1(3),
            wr_eof_in1   => wr_eof_in1,
            wr_abort_in1 => wr_abort_in1,

            wr_data_in2  => wr_data_in2,
            wr_en_in2    => wr_en_in2(3),
            wr_eof_in2   => wr_eof_in2,
            wr_abort_in2 => wr_abort_in2,

            wr_data_in3  => wr_data_in3,
            wr_en_in3    => wr_en_in3(3),
            wr_eof_in3   => wr_eof_in3,
            wr_abort_in3 => wr_abort_in3,

            rd_en => rd_en_o3,

            rd_data_0 => rd_data_o3_0,
            rd_data_1 => rd_data_o3_1,
            rd_data_2 => rd_data_o3_2,
            rd_data_3 => rd_data_o3_3,

            rd_valid => out_valid_3,

            rd_eof    => rd_eof_o3,
            frame_rdy => frame_rdy_o3,
            full      => full_o3,
            empty     => empty_o3
        );

    -- EOF MUX for queue 3: select EOF of the currently granted FIFO
    with rr_sel_o3 select
        eof_mux_o3 <= rd_eof_o3(0) when "00",
        rd_eof_o3(1) when "01",
        rd_eof_o3(2) when "10",
        rd_eof_o3(3) when others;

    -- Round-robin arbiter for queue 3
    u_rr_o3 : entity work.round_robin
        port map(
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_o3,
            eof       => eof_mux_o3,
            sel       => rr_sel_o3,
            grant     => rr_grant_o3,
            active    => rr_active_o3
        );

    rd_en_o3 <= rr_grant_o3;

    ---------------------------------------------------------------------------
    -- Crossbar switch: output multiplexers
    --
    -- The crossbar takes all 16 FIFO output streams and routes exactly one
    -- stream to each output port (0..3). Selection is driven by rr_sel_oX
    -- (2-bit index of the granted FIFO).
    --
    -- Port naming: data_mX_iY
    --   mX = output queue X (which output these data belong to)
    --   iY = FIFO of input Y within that queue
    --
    -- Example: data_m2_i1 = data from queue 2, FIFO of input 1
    --          -> bytes from input 1 destined for output 2
    ---------------------------------------------------------------------------
    u_xbar : entity work.crossbar_switch
        port map(

            -- Input data for output port 0 (all 4 FIFOs from queue 0)
            data_m0_i0 => rd_data_o0_0, -- Queue 0, FIFO from input 0
            data_m0_i1 => rd_data_o0_1, -- Queue 0, FIFO from input 1
            data_m0_i2 => rd_data_o0_2, -- Queue 0, FIFO from input 2
            data_m0_i3 => rd_data_o0_3, -- Queue 0, FIFO from input 3

            -- Input data for output port 1 (all 4 FIFOs from queue 1)
            data_m1_i0 => rd_data_o1_0,
            data_m1_i1 => rd_data_o1_1,
            data_m1_i2 => rd_data_o1_2,
            data_m1_i3 => rd_data_o1_3,

            -- Input data for output port 2 (all 4 FIFOs from queue 2)
            data_m2_i0 => rd_data_o2_0,
            data_m2_i1 => rd_data_o2_1,
            data_m2_i2 => rd_data_o2_2,
            data_m2_i3 => rd_data_o2_3,

            -- Input data for output port 3 (all 4 FIFOs from queue 3)
            data_m3_i0 => rd_data_o3_0,
            data_m3_i1 => rd_data_o3_1,
            data_m3_i2 => rd_data_o3_2,
            data_m3_i3 => rd_data_o3_3,

            -- Select signals: index of the granted FIFO per queue
            -- (driven directly by the respective round-robin arbiter)
            sel_0 => rr_sel_o0, -- Controls MUX for out_data_0
            sel_1 => rr_sel_o1, -- Controls MUX for out_data_1
            sel_2 => rr_sel_o2, -- Controls MUX for out_data_2
            sel_3 => rr_sel_o3, -- Controls MUX for out_data_3

            -- Output data for the four output ports
            out_data_0 => out_data_0,
            out_data_1 => out_data_1,
            out_data_2 => out_data_2,
            out_data_3 => out_data_3
        );

end architecture rtl;
