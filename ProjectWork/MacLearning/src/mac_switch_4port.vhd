library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.mac_table_pkg.ALL;

-- ============================================================================
-- mac_switch_4port
--
-- Scaffold for a 4-port MAC learning / forwarding controller.
--
-- Intended structure:
--   - per-port ingress decode
--   - request arbitration
--   - shared MAC table engine
--   - lookup result distribution
--   - learn/update path
--   - optional aging service
--
-- This file wraps the existing single-stream MAC table core with per-port
-- request FIFOs and a simple 4-port scheduler. Only one lookup or learn
-- request is issued to the core at a time; the selected port gets the
-- response routed back.
-- ============================================================================
entity mac_switch_4port is
    generic (
        NUM_PORTS  : integer := 4;
        MAC_W      : integer := MAC_WIDTH;
        PORT_W     : integer := PORT_WIDTH;
        TABLE_SIZE  : integer := NUM_BUCKETS * BUCKET_SIZE
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- Lookup request path, one lane per port
        lookup_req_valid : in  std_logic_vector(NUM_PORTS-1 downto 0);
        lookup_req_mac   : in  std_logic_vector(NUM_PORTS*MAC_W-1 downto 0);
        lookup_req_port   : in  std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);

        -- Learn request path, one lane per port
        learn_req_valid   : in  std_logic_vector(NUM_PORTS-1 downto 0);
        learn_req_mac     : in  std_logic_vector(NUM_PORTS*MAC_W-1 downto 0);
        learn_req_port    : in  std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);

        -- Forwarding results back to the ports
        lookup_hit        : out std_logic_vector(NUM_PORTS-1 downto 0);
        lookup_dst_port   : out std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);
        lookup_done       : out std_logic_vector(NUM_PORTS-1 downto 0);

        -- Learn completion back to the ports
        learn_done        : out std_logic_vector(NUM_PORTS-1 downto 0);

        -- Background maintenance
        age_tick          : in  std_logic
    );
end mac_switch_4port;

architecture rtl of mac_switch_4port is

    constant REQ_W : integer := MAC_W + PORT_W;

    type request_class_t is (REQ_NONE, REQ_LOOKUP, REQ_LEARN);
    type scheduler_state_t is (ST_IDLE, ST_ISSUE_LOOKUP, ST_WAIT_LOOKUP, ST_ISSUE_LEARN, ST_WAIT_LEARN);

    function lane_slice(
        vec        : std_logic_vector;
        lane       : natural;
        lane_width : natural
    ) return std_logic_vector is
        variable result : std_logic_vector(lane_width-1 downto 0);
        variable hi     : integer;
        variable lo     : integer;
    begin
        hi := integer(lane + 1) * integer(lane_width) - 1;
        lo := integer(lane) * integer(lane_width);
        result := vec(hi downto lo);
        return result;
    end function;

    function find_first_active(
        valids : std_logic_vector
    ) return integer is
    begin
        for i in 0 to valids'length - 1 loop
            if valids(valids'low + i) = '1' then
                return valids'low + i;
            end if;
        end loop;

        return -1;
    end function;

    type req_bus_array_t is array (natural range <>) of std_logic_vector(REQ_W-1 downto 0);

    -- Per-port FIFO outputs.
    signal lookup_fifo_dout  : req_bus_array_t(0 to NUM_PORTS-1);
    signal learn_fifo_dout   : req_bus_array_t(0 to NUM_PORTS-1);
    signal lookup_fifo_empty  : std_logic_vector(NUM_PORTS-1 downto 0);
    signal learn_fifo_empty   : std_logic_vector(NUM_PORTS-1 downto 0);
    signal lookup_fifo_rd_en  : std_logic_vector(NUM_PORTS-1 downto 0);
    signal learn_fifo_rd_en   : std_logic_vector(NUM_PORTS-1 downto 0);

    -- The shell keeps a single request active while the core processes it.
    signal state : scheduler_state_t := ST_IDLE;
    signal active_kind : request_class_t := REQ_NONE;
    signal active_port_idx : integer range 0 to NUM_PORTS-1 := 0;

    signal core_lookup_mac  : std_logic_vector(MAC_W-1 downto 0) := (others => '0');
    signal core_lookup_req  : std_logic := '0';
    signal core_lookup_hit   : std_logic;
    signal core_lookup_port  : std_logic_vector(PORT_W-1 downto 0);
    signal core_lookup_done  : std_logic;

    signal core_learn_mac   : std_logic_vector(MAC_W-1 downto 0) := (others => '0');
    signal core_learn_port  : std_logic_vector(PORT_W-1 downto 0) := (others => '0');
    signal core_learn_req   : std_logic := '0';
    signal core_learn_done  : std_logic;

begin

    -- Per-port request FIFOs.
    gen_port_fifos: for port_idx in 0 to NUM_PORTS-1 generate
        lookup_fifo_inst: entity work.request_fifo
            generic map (
                DATA_WIDTH => REQ_W,
                DEPTH      => 4
            )
            port map (
                clk     => clk,
                rst     => rst,
                wr_en   => lookup_req_valid(port_idx),
                wr_data => lane_slice(lookup_req_mac, port_idx, MAC_W) &
                           lane_slice(lookup_req_port, port_idx, PORT_W),
                rd_en   => lookup_fifo_rd_en(port_idx),
                rd_data => lookup_fifo_dout(port_idx),
                empty   => lookup_fifo_empty(port_idx),
                full    => open
            );

        learn_fifo_inst: entity work.request_fifo
            generic map (
                DATA_WIDTH => REQ_W,
                DEPTH      => 4
            )
            port map (
                clk     => clk,
                rst     => rst,
                wr_en   => learn_req_valid(port_idx),
                wr_data => lane_slice(learn_req_mac, port_idx, MAC_W) &
                           lane_slice(learn_req_port, port_idx, PORT_W),
                rd_en   => learn_fifo_rd_en(port_idx),
                rd_data => learn_fifo_dout(port_idx),
                empty   => learn_fifo_empty(port_idx),
                full    => open
            );
    end generate;

    core_inst: entity work.mac_table_8k
        port map (
            clk         => clk,
            rst         => rst,
            lookup_mac  => core_lookup_mac,
            lookup_req  => core_lookup_req,
            lookup_hit  => core_lookup_hit,
            lookup_port => core_lookup_port,
            lookup_done  => core_lookup_done,
            learn_mac   => core_learn_mac,
            learn_port  => core_learn_port,
            learn_req   => core_learn_req,
            learn_done  => core_learn_done,
            age_tick    => age_tick
        );

    -- 4-port scheduler:
    --   - lookup requests have priority over learn requests
    --   - one request is forwarded to the core at a time
    --   - the completion pulse is routed back to the selected port
    process(clk)
        variable chosen_port : integer;
        variable chosen_word  : std_logic_vector(REQ_W-1 downto 0);
    begin
        if rising_edge(clk) then
            -- Default outputs: no pulses unless the core finishes an active request.
            lookup_hit      <= (others => '0');
            lookup_dst_port <= (others => '0');
            lookup_done     <= (others => '0');
            learn_done      <= (others => '0');

            -- Default core request strobes are one-cycle pulses.
            core_lookup_req <= '0';
            core_learn_req  <= '0';
            lookup_fifo_rd_en <= (others => '0');
            learn_fifo_rd_en  <= (others => '0');

            if rst = '1' then
                state            <= ST_IDLE;
                active_kind      <= REQ_NONE;
                active_port_idx  <= 0;
                core_lookup_mac  <= (others => '0');
                core_learn_mac   <= (others => '0');
                core_learn_port  <= (others => '0');

            else
                case state is

                    when ST_IDLE =>
                        chosen_port := find_first_active(not lookup_fifo_empty);

                        if chosen_port >= 0 and chosen_port < NUM_PORTS then
                            active_kind     <= REQ_LOOKUP;
                            active_port_idx <= chosen_port;
                            chosen_word     := lookup_fifo_dout(chosen_port);
                            core_lookup_mac <= chosen_word(REQ_W-1 downto PORT_W);
                            state           <= ST_ISSUE_LOOKUP;
                        else
                            chosen_port := find_first_active(not learn_fifo_empty);

                            if chosen_port >= 0 and chosen_port < NUM_PORTS then
                                active_kind     <= REQ_LEARN;
                                active_port_idx <= chosen_port;
                                chosen_word     := learn_fifo_dout(chosen_port);
                                core_learn_mac  <= chosen_word(REQ_W-1 downto PORT_W);
                                core_learn_port <= chosen_word(PORT_W-1 downto 0);
                                state           <= ST_ISSUE_LEARN;
                            end if;
                        end if;

                    when ST_ISSUE_LOOKUP =>
                        lookup_fifo_rd_en(active_port_idx) <= '1';
                        core_lookup_req <= '1';
                        state           <= ST_WAIT_LOOKUP;

                    when ST_WAIT_LOOKUP =>
                        if core_lookup_done = '1' then
                            lookup_hit(active_port_idx) <= core_lookup_hit;
                            lookup_done(active_port_idx) <= '1';
                            lookup_dst_port(
                                (active_port_idx + 1) * PORT_W - 1 downto active_port_idx * PORT_W
                            ) <= core_lookup_port;

                            active_kind     <= REQ_NONE;
                            state           <= ST_IDLE;
                        end if;

                    when ST_ISSUE_LEARN =>
                        learn_fifo_rd_en(active_port_idx) <= '1';
                        core_learn_req <= '1';
                        state          <= ST_WAIT_LEARN;

                    when ST_WAIT_LEARN =>
                        if core_learn_done = '1' then
                            learn_done(active_port_idx) <= '1';
                            active_kind                 <= REQ_NONE;
                            state                       <= ST_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end rtl;
