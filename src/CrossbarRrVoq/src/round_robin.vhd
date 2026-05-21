-- =============================================================================
-- Module: round_robin
--
-- Description:
--   4-input round-robin arbiter for one output queue of the VOQ switch.
--   The arbiter selects the next input FIFO that contains at least one complete
--   frame. Once selected, the grant remains locked to that FIFO until the EOF
--   marker of the current frame is observed. This prevents interleaving of
--   frames at the output and preserves frame order within each flow.
--
-- Interface:
--   frame_rdy(i) = '1' indicates that FIFO i contains a complete frame.
--   eof          = '1' for one clock cycle when the selected FIFO outputs the
--                  last byte of the current frame.
--   sel          = binary index of the currently granted FIFO.
--   grant        = one-hot read enable for the four input FIFOs.
--   active       = '1' while a FIFO is granted and a frame is being transmitted.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity round_robin is
    port (
        clk       : in STD_LOGIC;
        reset     : in STD_LOGIC;                     -- Async reset, active low
        frame_rdy : in STD_LOGIC_VECTOR(3 downto 0);  -- FIFO has a full frame (one bit per input)
        eof       : in STD_LOGIC;                     -- EOF from currently granted FIFO
        sel       : out STD_LOGIC_VECTOR(1 downto 0); -- Binary index of granted FIFO (for the output mux)
        grant     : out STD_LOGIC_VECTOR(3 downto 0); -- One-hot read enable for selected FIFO
        active    : out STD_LOGIC                     -- Indicates grant is locked to a frame
    );
end entity round_robin;

architecture rtl of round_robin is

    type state_t is (IDLE, LOCKED, GAP);

    constant GAP_CYCLES : NATURAL := 11;

    signal state_reg    : state_t := IDLE;
    signal state_next   : state_t;
    signal rr_ptr_reg   : unsigned(1 downto 0) := (others => '0');
    signal rr_ptr_next  : unsigned(1 downto 0);
    signal sel_reg      : unsigned(1 downto 0) := (others => '0');
    signal sel_next     : unsigned(1 downto 0);
    signal gap_cnt_reg  : unsigned(3 downto 0) := (others => '0');
    signal gap_cnt_next : unsigned(3 downto 0);

begin
    -- -------------------------------------------------------------------------
    -- Register process. The reset is asynchronous and active low.
    seq_proc : process (all)
    begin
        if reset = '0' then
            state_reg   <= IDLE;
            rr_ptr_reg  <= (others => '0');
            sel_reg     <= (others => '0');
            gap_cnt_reg <= (others => '0');
        elsif rising_edge(clk) then
            state_reg   <= state_next;
            rr_ptr_reg  <= rr_ptr_next;
            sel_reg     <= sel_next;
            gap_cnt_reg <= gap_cnt_next;
        end if;
    end process seq_proc;

    -- -------------------------------------------------------------------------
    -- Next-state logic. In IDLE, the search starts at rr_ptr_reg and checks all
    -- four FIFOs in round-robin order. In LOCKED, the grant is held until EOF.
    comb_proc : process (all)
        variable found_v : BOOLEAN;
        variable index_v : INTEGER range 0 to 3;
        variable cand_v  : unsigned(1 downto 0);
    begin
        state_next   <= state_reg;
        rr_ptr_next  <= rr_ptr_reg;
        sel_next     <= sel_reg;
        gap_cnt_next <= gap_cnt_reg;

        case state_reg is
            when IDLE =>
                found_v := false;
                cand_v  := rr_ptr_reg;

                -- Scan all inputs in round-robin order.
                for offset in 0 to 3 loop
                    index_v := (to_integer(rr_ptr_reg) + offset) mod 4;

                    if (not found_v) and (frame_rdy(index_v) = '1') then
                        cand_v  := to_unsigned(index_v, 2);
                        found_v := true;
                    end if;
                end loop;

                if found_v then
                    sel_next   <= cand_v;
                    state_next <= LOCKED;
                end if;

            when LOCKED =>
                -- End of frame: move pointer to the next FIFO.
                if eof = '1' then
                    rr_ptr_next  <= sel_reg + 1;
                    state_next   <= GAP;
                    gap_cnt_next <= (others => '0');
                end if;

            when GAP =>
                -- Enforce end-of-frame gap before selecting the next frame.
                if gap_cnt_reg = to_unsigned(GAP_CYCLES - 1, gap_cnt_reg'length) then
                    state_next   <= IDLE;
                    gap_cnt_next <= (others => '0');
                else
                    gap_cnt_next <= gap_cnt_reg + 1;
                end if;
        end case;
    end process comb_proc;

    -- -------------------------------------------------------------------------
    -- Drive mux select and indicate when the arbiter is locked to a frame.
    sel    <= STD_LOGIC_VECTOR(sel_reg);
    active <= '1' when state_reg = LOCKED else
        '0';

    -- -------------------------------------------------------------------------
    -- Convert the selected index into one-hot read enable.
    grant_proc : process (all)
    begin
        grant <= (others => '0');

        if state_reg = LOCKED then
            case sel_reg is
                when "00"   => grant   <= "0001";
                when "01"   => grant   <= "0010";
                when "10"   => grant   <= "0100";
                when others => grant <= "1000";
            end case;
        end if;
    end process grant_proc;

end architecture rtl;
