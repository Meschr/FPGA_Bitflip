library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac_pkg.all;

entity frame_parser is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    -- Byte-Stream Eingang
    data_in    : in  std_logic_vector(7 downto 0);
    data_valid : in  std_logic;
    sof        : in  std_logic;  -- Start of Frame Puls
    src_port   : in  std_logic_vector(PORT_WIDTH-1 downto 0);

    -- Ausgabe (gültig sobald mac_valid = '1')
    dst_mac    : out mac_addr_t;
    src_mac    : out mac_addr_t;
    port_out   : out std_logic_vector(PORT_WIDTH-1 downto 0);
    mac_valid  : out std_logic
  );
end entity frame_parser;

architecture rtl of frame_parser is

  type state_t is (IDLE, DST_MAC, SRC_MAC, DONE);
  signal state   : state_t := IDLE;

  signal byte_cnt   : integer range 0 to 11 := 0;
  signal dst_buf    : mac_addr_t := (others => '0');
  signal src_buf    : mac_addr_t := (others => '0');

begin

end architecture rtl;
