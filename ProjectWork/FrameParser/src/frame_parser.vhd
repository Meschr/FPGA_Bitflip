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

  p_parse : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state     <= IDLE;
        byte_cnt  <= 0;
        mac_valid <= '0';
        dst_buf   <= (others => '0');
        src_buf   <= (others => '0');
        dst_mac   <= (others => '0');
        src_mac   <= (others => '0');
        port_out  <= (others => '0');

      else
        mac_valid <= '0';  -- default: kein Puls

        case state is

          -- Warten auf Start of Frame
          when IDLE =>
            if sof = '1' then
              byte_cnt <= 0;
              state    <= DST_MAC;
            end if;

          -- Bytes 0..5 = Destination MAC (MSB zuerst)
          when DST_MAC =>
            if data_valid = '1' then
              dst_buf <= dst_buf(39 downto 0) & data_in;
              if byte_cnt = 5 then
                byte_cnt <= 0;
                state    <= SRC_MAC;
              else
                byte_cnt <= byte_cnt + 1;
              end if;
            end if;

          -- Bytes 6..11 = Source MAC (MSB zuerst)
          when SRC_MAC =>
            if data_valid = '1' then
              src_buf <= src_buf(39 downto 0) & data_in;
              if byte_cnt = 5 then
                state <= DONE;
              else
                byte_cnt <= byte_cnt + 1;
              end if;
            end if;

          -- Ausgabe registrieren, 1 Takt mac_valid
          when DONE =>
            dst_mac   <= dst_buf;
            src_mac   <= src_buf;
            port_out  <= src_port;
            mac_valid <= '1';
            state     <= IDLE;

        end case;
      end if;
    end if;
  end process p_parse;

end architecture rtl;
