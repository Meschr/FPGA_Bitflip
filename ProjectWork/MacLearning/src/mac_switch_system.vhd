library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================================
-- mac_switch_system
--
-- Top-level integration wrapper for the 4-port MAC switch.
--
-- This entity exists so the switch has a clear system entry point:
--   - it exposes the 4-port request/response interface
--   - it instantiates the 4-port scheduler/controller
--   - it keeps the table core isolated behind a stable boundary
--
-- The real switching behavior is implemented in mac_switch_4port.
-- ============================================================================
entity mac_switch_system is
    generic (
        NUM_PORTS  : integer := 4;
        MAC_W      : integer := 48;
        PORT_W     : integer := 2
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        lookup_req_valid : in  std_logic_vector(NUM_PORTS-1 downto 0);
        lookup_req_mac   : in  std_logic_vector(NUM_PORTS*MAC_W-1 downto 0);
        lookup_req_port  : in  std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);

        learn_req_valid  : in  std_logic_vector(NUM_PORTS-1 downto 0);
        learn_req_mac    : in  std_logic_vector(NUM_PORTS*MAC_W-1 downto 0);
        learn_req_port   : in  std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);

        lookup_hit       : out std_logic_vector(NUM_PORTS-1 downto 0);
        lookup_dst_port  : out std_logic_vector(NUM_PORTS*PORT_W-1 downto 0);
        lookup_done      : out std_logic_vector(NUM_PORTS-1 downto 0);
        learn_done       : out std_logic_vector(NUM_PORTS-1 downto 0);

        age_tick         : in  std_logic
    );
end mac_switch_system;

architecture rtl of mac_switch_system is
begin

    core: entity work.mac_switch_4port
        generic map (
            NUM_PORTS => NUM_PORTS,
            MAC_W     => MAC_W,
            PORT_W    => PORT_W
        )
        port map (
            clk             => clk,
            rst             => rst,
            lookup_req_valid => lookup_req_valid,
            lookup_req_mac   => lookup_req_mac,
            lookup_req_port  => lookup_req_port,
            learn_req_valid  => learn_req_valid,
            learn_req_mac    => learn_req_mac,
            learn_req_port   => learn_req_port,
            lookup_hit       => lookup_hit,
            lookup_dst_port  => lookup_dst_port,
            lookup_done      => lookup_done,
            learn_done       => learn_done,
            age_tick         => age_tick
        );

end rtl;
