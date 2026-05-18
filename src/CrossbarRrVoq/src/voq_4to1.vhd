-- =============================================================================
-- Module: voq_4to1
-- Purpose:
--   Bundles four VOQs for a single output port in the crossbar.
--
-- Structure:
--   Input 0 -> FIFO 0 (fifo_in0_out0) -> rd_data_0
--   Input 1 -> FIFO 1 (fifo_in1_out0) -> rd_data_1
--   Input 2 -> FIFO 2 (fifo_in2_out0) -> rd_data_2
--   Input 3 -> FIFO 3 (fifo_in3_out0) -> rd_data_3
--
-- Arbitration:
--   rd_en(i) selects which FIFO is read by the round-robin arbiter.
--   frame_rdy(i) reports whether FIFO i holds a complete frame.
--
-- Generic:
--   DEPTH  Depth of each FIFO in bytes (default: 4096)
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

-- -----------------------------------------------------------------------------
-- Entity
-- -----------------------------------------------------------------------------
ENTITY voq_4to1 IS
    GENERIC (
        DEPTH : INTEGER := 32768 -- FIFO depth per input
    );
    PORT (
        clk : IN STD_LOGIC; -- System clock
        reset : IN STD_LOGIC; -- Synchronous reset (active low)
        flush : IN STD_LOGIC_VECTOR(3 DOWNTO 0); -- Logical clear per FIFO

        -- Write side: 4 independent input streams
        wr_data_in0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en_in0 : IN STD_LOGIC;
        wr_eof_in0 : IN STD_LOGIC;
        wr_abort_in0 : IN STD_LOGIC; -- '1' discards current frame for input 0

        wr_data_in1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en_in1 : IN STD_LOGIC;
        wr_eof_in1 : IN STD_LOGIC;
        wr_abort_in1 : IN STD_LOGIC; -- '1' discards current frame for input 1

        wr_data_in2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en_in2 : IN STD_LOGIC;
        wr_eof_in2 : IN STD_LOGIC;
        wr_abort_in2 : IN STD_LOGIC; -- '1' discards current frame for input 2

        wr_data_in3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en_in3 : IN STD_LOGIC;
        wr_eof_in3 : IN STD_LOGIC;
        wr_abort_in3 : IN STD_LOGIC; -- '1' discards current frame for input 3

        -- Read side: controlled by round-robin arbiter
        rd_en : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

        rd_data_0 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        rd_data_1 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        rd_data_2 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        rd_data_3 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

        rd_valid : OUT STD_LOGIC; -- '1' when any FIFO provides valid data
        rd_eof : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        frame_rdy : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        full : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        empty : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY;

-- -----------------------------------------------------------------------------
-- Architecture: four parallel voq_fifo instances
-- -----------------------------------------------------------------------------
ARCHITECTURE rtl OF voq_4to1 IS
    SIGNAL rd_valid_internal : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rd_valid_any : STD_LOGIC;
BEGIN
    -- -------------------------------------------------------------------------
    -- FIFO instances
    -- -------------------------------------------------------------------------
    -- Input 0 FIFO for this output port
    fifo_in0_out0 : ENTITY work.voq_fifo
        GENERIC MAP(DEPTH => DEPTH)
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => flush(0),
            wr_en => wr_en_in0,
            wr_data => wr_data_in0,
            wr_eof => wr_eof_in0,
            wr_abort => wr_abort_in0,
            rd_en => rd_en(0),
            rd_data => rd_data_0,
            rd_eof => rd_eof(0),
            rd_valid => rd_valid_internal(0),
            frame_rdy => frame_rdy(0),
            full => full(0),
            empty => empty(0)
        );

    -- Input 1 FIFO for this output port
    fifo_in1_out0 : ENTITY work.voq_fifo
        GENERIC MAP(DEPTH => DEPTH)
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => flush(1),
            wr_en => wr_en_in1,
            wr_data => wr_data_in1,
            wr_eof => wr_eof_in1,
            wr_abort => wr_abort_in1,
            rd_en => rd_en(1),
            rd_data => rd_data_1,
            rd_eof => rd_eof(1),
            rd_valid => rd_valid_internal(1),
            frame_rdy => frame_rdy(1),
            full => full(1),
            empty => empty(1)
        );

    -- Input 2 FIFO for this output port
    fifo_in2_out0 : ENTITY work.voq_fifo
        GENERIC MAP(DEPTH => DEPTH)
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => flush(2),
            wr_en => wr_en_in2,
            wr_data => wr_data_in2,
            wr_eof => wr_eof_in2,
            wr_abort => wr_abort_in2,
            rd_en => rd_en(2),
            rd_data => rd_data_2,
            rd_eof => rd_eof(2),
            rd_valid => rd_valid_internal(2),
            frame_rdy => frame_rdy(2),
            full => full(2),
            empty => empty(2)
        );

    -- Input 3 FIFO for this output port
    fifo_in3_out0 : ENTITY work.voq_fifo
        GENERIC MAP(DEPTH => DEPTH)
        PORT MAP(
            clk => clk,
            reset => reset,
            flush => flush(3),
            wr_en => wr_en_in3,
            wr_data => wr_data_in3,
            wr_eof => wr_eof_in3,
            wr_abort => wr_abort_in3,
            rd_en => rd_en(3),
            rd_data => rd_data_3,
            rd_eof => rd_eof(3),
            rd_valid => rd_valid_internal(3),
            frame_rdy => frame_rdy(3),
            full => full(3),
            empty => empty(3)
        );

    -- -------------------------------------------------------------------------
    -- Output aggregation
    -- -------------------------------------------------------------------------
    rd_valid_any <= '1' WHEN rd_valid_internal /= "0000" ELSE
        '0';
    rd_valid <= rd_valid_any;

END ARCHITECTURE rtl;