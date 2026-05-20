-- =============================================================================
-- Module: crossbar_switch
--
-- Description:
--   4x4 crossbar switch using a pure MUX architecture.
--   Four independent 4:1 multiplexers (one per output port).
--   Each MUX selects its input via a 2-bit select signal.
--
-- Topology example:
--   Input 0 ----+
--   Input 1 ----+--> MUX 0 --> Output 0 (controlled by sel_0)
--   Input 2 ----+
--   Input 3 ----+
--
-- Implementation: concurrent "with...select" statements (no sequential logic)
-- Timing: combinational, no registers inside the MUXes
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity crossbar_switch is
    port (
        -- -----------------------------------------------------------------
        -- MUX 0 input ports (VOQ column for destination port 0)
        -- -----------------------------------------------------------------
        data_m0_i0 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 0 to MUX 0
        data_m0_i1 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 1 to MUX 0
        data_m0_i2 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 2 to MUX 0
        data_m0_i3 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 3 to MUX 0

        -- -----------------------------------------------------------------
        -- MUX 1 input ports (VOQ column for destination port 1)
        -- -----------------------------------------------------------------
        data_m1_i0 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 0 to MUX 1
        data_m1_i1 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 1 to MUX 1
        data_m1_i2 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 2 to MUX 1
        data_m1_i3 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 3 to MUX 1

        -- -----------------------------------------------------------------
        -- MUX 2 input ports (VOQ column for destination port 2)
        -- -----------------------------------------------------------------
        data_m2_i0 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 0 to MUX 2
        data_m2_i1 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 1 to MUX 2
        data_m2_i2 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 2 to MUX 2
        data_m2_i3 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 3 to MUX 2

        -- -----------------------------------------------------------------
        -- MUX 3 input ports (VOQ column for destination port 3)
        -- -----------------------------------------------------------------
        data_m3_i0 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 0 to MUX 3
        data_m3_i1 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 1 to MUX 3
        data_m3_i2 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 2 to MUX 3
        data_m3_i3 : in STD_LOGIC_VECTOR(7 downto 0); -- Input 3 to MUX 3

        -- -----------------------------------------------------------------
        -- Select signals (control which input is routed to the output port)
        -- sel_0..sel_3: 2 bits each, select input 0..3
        -- -----------------------------------------------------------------
        sel_0 : in STD_LOGIC_VECTOR(1 downto 0); -- MUX 0 select for output 0
        sel_1 : in STD_LOGIC_VECTOR(1 downto 0); -- MUX 1 select for output 1
        sel_2 : in STD_LOGIC_VECTOR(1 downto 0); -- MUX 2 select for output 2
        sel_3 : in STD_LOGIC_VECTOR(1 downto 0); -- MUX 3 select for output 3

        -- -----------------------------------------------------------------
        -- Output ports (8-bit data word per destination port)
        -- -----------------------------------------------------------------
        out_data_0 : out STD_LOGIC_VECTOR(7 downto 0); -- Output destination port 0
        out_data_1 : out STD_LOGIC_VECTOR(7 downto 0); -- Output destination port 1
        out_data_2 : out STD_LOGIC_VECTOR(7 downto 0); -- Output destination port 2
        out_data_3 : out STD_LOGIC_VECTOR(7 downto 0)  -- Output destination port 3
    );
end entity crossbar_switch;

architecture rtl of crossbar_switch is

    -- Internal signals for the MUX outputs (before optional output registration)
    signal mux0_out : STD_LOGIC_VECTOR(7 downto 0);
    signal mux1_out : STD_LOGIC_VECTOR(7 downto 0);
    signal mux2_out : STD_LOGIC_VECTOR(7 downto 0);
    signal mux3_out : STD_LOGIC_VECTOR(7 downto 0);

begin

    ---------------------------------------------------------------------------
    -- Four 4:1 multiplexers using the "with...select" construct
    -- Purely combinational (no clock) and mapped to FPGA MUX fabric
    ---------------------------------------------------------------------------

    -- MUX 0: selects one of four inputs controlled by sel_0
    with sel_0 select
        mux0_out <= data_m0_i0 when "00",
        data_m0_i1 when "01",
        data_m0_i2 when "10",
        data_m0_i3 when others;

    -- MUX 1: selects one of four inputs controlled by sel_1
    with sel_1 select
        mux1_out <= data_m1_i0 when "00",
        data_m1_i1 when "01",
        data_m1_i2 when "10",
        data_m1_i3 when others;

    -- MUX 2: selects one of four inputs controlled by sel_2
    with sel_2 select
        mux2_out <= data_m2_i0 when "00",
        data_m2_i1 when "01",
        data_m2_i2 when "10",
        data_m2_i3 when others;

    -- MUX 3: selects one of four inputs controlled by sel_3
    with sel_3 select
        mux3_out <= data_m3_i0 when "00",
        data_m3_i1 when "01",
        data_m3_i2 when "10",
        data_m3_i3 when others;

    ---------------------------------------------------------------------------
    -- Output connection (combinational)
    -- The MUX outputs are passed directly to the output ports.
    -- Optional output registers could be inserted for tighter timing.
    ---------------------------------------------------------------------------

    out_data_0 <= mux0_out;
    out_data_1 <= mux1_out;
    out_data_2 <= mux2_out;
    out_data_3 <= mux3_out;

end architecture rtl;
