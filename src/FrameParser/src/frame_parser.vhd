library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_parser is
  port (
    clk   : in STD_LOGIC;
    reset : in STD_LOGIC;

    data_in    : in STD_LOGIC_VECTOR(7 downto 0);
    data_valid : in STD_LOGIC;

    data_out : out STD_LOGIC_VECTOR(7 downto 0);
    sof      : out STD_LOGIC;
    eof      : out STD_LOGIC;

    dst_mac   : inout STD_LOGIC_VECTOR(47 downto 0); -- Destination MAC address
    dst_valid : out STD_LOGIC;                       -- Destination MAC valid
    src_mac   : inout STD_LOGIC_VECTOR(47 downto 0); -- Source MAC address
    src_valid : out STD_LOGIC                        -- Source MAC valid
  );
end entity frame_parser;

architecture rtl of frame_parser is
  type state_t is (ERR, PREAMBLE, SFD, DST, SRC, ETHER_PAYLOAD_FCS); -- State machine states for parsing the Ethernet frame

  signal state : state_t; 

  signal ether_byte_0    : STD_LOGIC_VECTOR(7 downto 0); -- Temporary storage for first EtherType byte
  signal byte_cnt        : INTEGER range 0 to 2047;      
  signal data_valid_prev : STD_LOGIC;                    -- Previous data_valid value for falling-edge detection

begin

  process (all)
  begin
    if reset = '0' then
      state           <= PREAMBLE;
      ether_byte_0    <= (others => '0');
      byte_cnt        <= 0;
      data_valid_prev <= '0';

      data_out  <= (others => '0');
      sof       <= '0';
      eof       <= '0';
      dst_valid <= '0';
      src_valid <= '0';
      dst_mac   <= (others => '0');
      src_mac   <= (others => '0');

    elsif rising_edge(clk) then

      data_out        <= (others => '0');
      sof             <= '0';
      eof             <= '0';
      dst_valid       <= '0';
      src_valid       <= '0';
      dst_mac         <= dst_mac;
      src_mac         <= src_mac;
      data_valid_prev <= data_valid;
      byte_cnt        <= 0;

      if data_valid = '1' then
        byte_cnt <= byte_cnt + 1;

        case state is
          when PREAMBLE => -- Expecting 7 bytes of preamble (0x55). After receiving 7 bytes, expect SFD (0xD5).
            if not data_in = x"55" then
              state <= ERR;
            elsif byte_cnt = 6 then 
              state    <= SFD;
              data_out <= data_in; 
            else
              data_out <= data_in; 
              state    <= PREAMBLE;
            end if;

          when SFD => -- Expecting the Start of Frame Delimiter (SFD) 0xD5.
            if data_in = x"D5" then
              data_out <= data_in;
              state    <= DST;
            else 
              state <= ERR;
            end if;

          when DST =>
            data_out <= data_in;

            if byte_cnt = 8 then
              sof <= '1'; 
            end if;

            case byte_cnt is
              when 8      => dst_mac(47 downto 40)  <= data_in;
              when 9      => dst_mac(39 downto 32)  <= data_in;
              when 10     => dst_mac(31 downto 24) <= data_in;
              when 11     => dst_mac(23 downto 16) <= data_in;
              when 12     => dst_mac(15 downto 8)  <= data_in;
              when 13     => dst_mac(7 downto 0)   <= data_in;
              when others => null;
            end case;

            if byte_cnt = 13 then
              dst_valid <= '1';
              state     <= SRC;
            end if;

          when SRC =>
            data_out <= data_in;

            case byte_cnt is
              when 14     => src_mac(47 downto 40) <= data_in;
              when 15     => src_mac(39 downto 32) <= data_in;
              when 16     => src_mac(31 downto 24) <= data_in;
              when 17     => src_mac(23 downto 16) <= data_in;
              when 18     => src_mac(15 downto 8)  <= data_in;
              when 19     => src_mac(7 downto 0)   <= data_in;
              when others => null;
            end case;

            if byte_cnt = 19 then
              src_valid <= '1';
              state     <= ETHER_PAYLOAD_FCS;
            end if;

          when ETHER_PAYLOAD_FCS =>            
            data_out <= data_in;
            byte_cnt <= byte_cnt + 1;
            if byte_cnt > 1526 then
              state <= ERR;
            else
              state <= ETHER_PAYLOAD_FCS;
            end if;

          when ERR =>
            eof      <= '1';
            data_out <= (others => '0');
            byte_cnt <= 0;

            if data_valid_prev = '1' and data_valid = '0' then
              state <= PREAMBLE;
            else
              state <= ERR;
            end if;

        end case;

      elsif data_valid_prev = '1' then
        eof   <= '1';
        state <= PREAMBLE;
      else
        state <= PREAMBLE;
      end if;
    end if;
  end process;

end architecture rtl;
