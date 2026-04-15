library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac_pkg.all;

------------------- Ethernet Frame ---------------------------------------------
-- Preamble (7B) | SFD (1B) | DST MAC (6B) | SRC MAC (6B) | EtherType (2B)
-- Payload (46..1500B) | FCS (4B) | IFG (12B)
--
-- frame_len counts from the first DST byte through the last FCS byte
-- (i.e. excludes Preamble/SFD and the inter-frame gap).
--
-- The header (dst_mac, src_mac) is buffered internally and released to the
-- MAC-learning block ONLY after the external FCS check confirms the frame
-- is good (fcs_valid pulse).
--------------------------------------------------------------------------------

entity frame_parser1 is
  port (
    clk             : in  std_logic;
    reset           : in  std_logic;

    -- RX byte stream (e.g. from the MII / GMII receive side)
    data_in         : in  std_logic_vector(7 downto 0);
    data_valid      : in  std_logic;

    -- Result of the FCS check
    -- (single-cycle pulse from the FCS module when the CRC is correct)
    fcs_valid       : in  std_logic;

    -- Stream forwarded to the FCS-check module
    -- (registered, so 1 clock cycle behind data_in)
    data_out        : out std_logic_vector(7 downto 0);
    data_out_valid  : out std_logic;                 -- aligned with data_out
    sof             : out std_logic;                 -- first DST byte on data_out
    eof             : out std_logic;                 -- pulse one cycle after last byte
    frame_len       : out unsigned(13 downto 0);     -- valid with eof

    -- Header to MAC learning (gated by fcs_valid)
    dst_mac         : out mac_addr_t;
    src_mac         : out mac_addr_t;
    dst_mac_valid   : out std_logic;                 -- pulse when dst_mac is valid
    src_mac_valid   : out std_logic;                 -- pulse when src_mac is valid
    ethertype       : out std_logic_vector(15 downto 0)
  );
end entity frame_parser1;

architecture rtl of frame_parser1 is

  constant PREAMBLE_BYTE : std_logic_vector(7 downto 0) := x"55";
  constant SFD_BYTE      : std_logic_vector(7 downto 0) := x"D5";

  type state_t is (IDLE, ST_PREAMBLE, ST_SFD, ST_HEADER, ST_PAYLOAD);
  signal state           : state_t := IDLE;

  signal prev_data_valid : std_logic := '0';

  signal dst_buf         : mac_addr_t                   := (others => '0');
  signal src_buf         : mac_addr_t                   := (others => '0');
  signal ether_buf_hi    : std_logic_vector(7 downto 0) := (others => '0');

  signal header_cnt      : integer range 0 to 13        := 0;
  signal frame_byte_cnt  : unsigned(13 downto 0)        := (others => '0');

  signal header_pending  : std_logic := '0';
  signal frame_active    : std_logic := '0';

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state           <= IDLE;
        dst_buf         <= (others => '0');
        src_buf         <= (others => '0');
        ether_buf_hi    <= (others => '0');
        header_cnt      <= 0;
        frame_byte_cnt  <= (others => '0');
        prev_data_valid <= '0';
        header_pending  <= '0';
        frame_active    <= '0';

        data_out        <= (others => '0');
        data_out_valid  <= '0';
        sof             <= '0';
        eof             <= '0';
        dst_mac         <= (others => '0');
        src_mac         <= (others => '0');
        dst_mac_valid   <= '0';
        src_mac_valid   <= '0';
        ethertype       <= (others => '0');
        frame_len       <= (others => '0');

      else
        sof            <= '0';
        eof            <= '0';
        dst_mac_valid  <= '0';
        src_mac_valid  <= '0';
        data_out       <= (others => '0');
        data_out_valid <= '0';

        if fcs_valid = '1' and header_pending = '1' then
          dst_mac        <= dst_buf;
          src_mac        <= src_buf;
          dst_mac_valid  <= '1';
          src_mac_valid  <= '1';
          header_pending <= '0';
        end if;

        if data_valid = '1' then

          if state = ST_HEADER or state = ST_PAYLOAD then
            frame_byte_cnt <= frame_byte_cnt + 1;
          end if;

          case state is

            when IDLE =>
              data_out       <= (others => '0');
              data_out_valid <= '0';

              if data_in = PREAMBLE_BYTE then
                header_cnt   <= 1;
                frame_active <= '0';
                state        <= ST_PREAMBLE;
              else
                header_cnt <= 0;
                state      <= IDLE;
              end if;

            when ST_PREAMBLE =>
              data_out       <= (others => '0');
              data_out_valid <= '0';

              if data_in = PREAMBLE_BYTE then
                if header_cnt = 6 then
                  header_cnt <= 0;
                  state      <= ST_SFD;
                else
                  header_cnt <= header_cnt + 1;
                end if;
              else
                header_cnt <= 0;
                state      <= IDLE;
              end if;

            when ST_SFD =>
              data_out       <= (others => '0');
              data_out_valid <= '0';

              if data_in = SFD_BYTE then
                header_cnt     <= 0;
                frame_byte_cnt <= (others => '0');
                header_pending <= '0';
                frame_active   <= '1';
                state          <= ST_HEADER;
              else
                state      <= IDLE;
                header_cnt <= 0;
              end if;

            when ST_HEADER =>
              data_out       <= data_in;
              data_out_valid <= '1';

              if header_cnt = 0 then
                sof <= '1';
              end if;

              if header_cnt <= 5 then
                case header_cnt is
                  when 0 => dst_buf(47 downto 40) <= data_in;
                  when 1 => dst_buf(39 downto 32) <= data_in;
                  when 2 => dst_buf(31 downto 24) <= data_in;
                  when 3 => dst_buf(23 downto 16) <= data_in;
                  when 4 => dst_buf(15 downto  8) <= data_in;
                  when 5 => dst_buf( 7 downto  0) <= data_in;
                  when others => null;
                end case;
              elsif header_cnt <= 11 then
                case header_cnt is
                  when 6  => src_buf(47 downto 40) <= data_in;
                  when 7  => src_buf(39 downto 32) <= data_in;
                  when 8  => src_buf(31 downto 24) <= data_in;
                  when 9  => src_buf(23 downto 16) <= data_in;
                  when 10 => src_buf(15 downto  8) <= data_in;
                  when 11 => src_buf( 7 downto  0) <= data_in;
                  when others => null;
                end case;
              elsif header_cnt = 12 then
                ether_buf_hi <= data_in;
              else
                ethertype      <= ether_buf_hi & data_in;
                header_pending <= '1';
                header_cnt     <= 0;
                state          <= ST_PAYLOAD;
              end if;

              if header_cnt < 13 then
                header_cnt <= header_cnt + 1;
              end if;

            when ST_PAYLOAD =>
              data_out       <= data_in;
              data_out_valid <= '1';
              -- Forward payload + FCS until data_valid drops.

          end case;

        elsif prev_data_valid = '1' then
          if frame_active = '1' then
            eof       <= '1';
            frame_len <= frame_byte_cnt;
          end if;
          state     <= IDLE;
          header_cnt  <= 0;
          frame_active <= '0';
        end if;

        prev_data_valid <= data_valid;

      end if;
    end if;
  end process;

end architecture rtl;
