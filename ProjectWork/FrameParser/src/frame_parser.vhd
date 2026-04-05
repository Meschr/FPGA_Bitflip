library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac_pkg.all;

------------------- Ethernet Package Frame---------------------------------------------------------------------------------------------------------------------------------------------------
  -- Preamble (7 Byte) | SFD : Start of Frame Delimeter (1 Byte) |Destination MAC (6 Byte) | Source MAC (6 Byte) | EtherType (2 Byte) | Payload (46-1500 Byte) | CRC (4 Byte) | Idle Line State (12 Byte)

  -- Preamble is a 7 Byte field which just consists series of 1s and 0s 
    --like 10101010101010101010... 56 Bits like this in sequence. This is to 
    --make sure the receiver clocks are synchronized, lock on to the Data Stream 
    --before the actual Frame begins

  -- Start of Frame Delimeter: This is the continuation of Preamble which 
    --indicates the start of the Frame. It is a 1 Byte field with value 10101011. 
    --This is to make sure that the receiver can identify the start of the Frame 
    --and differentiate it from the Preamble.

  -- Destination MAC Address: This is a 6 Byte field which contains the MAC address 
    --of the destination device. It is used by the receiver to determine if the Frame is intended for it or not.
        
  -- Source MAC Address: This is a 6 Byte field which contains the MAC address of 
    --the source device. It is used by the receiver to identify the sender of the Frame
    --and for various network management purposes.  

  -- EtherType: This is a 2 Byte field which indicates the type of the payload data from the upper layer. 
    --It is used by the receiver to determine how to process the payload. For example, 
    --0x0800 is an IPv4 packet, 0x86dd is for IPv6, 0x0806 is an ARP, 0x8100 for a Dot(.)1Q Frame, etc.

  -- Payload: This is the actual data being transmitted in the Frame. It can be between 
    --46 and 1500 Bytes in length. The payload can contain various types of data, such as 
    --IP packets, ARP messages, or other types of network traffic.  

  -- CRC (Cyclic Redundancy Check): This is a 4 Byte field which contains a checksum of the 
    --Frame. It is used by the receiver to detect errors in the Frame.   constant genPoly : std_logic_vector(31 downto 0) := x"04C11DB7";

  -- Idle Line State: This is a 12 Byte field which indicates that the line is idle and ready for the next Frame. 
    --It consists of a series of 1s and 0s, similar to the Preamble, and is used to ensure that the receiver can synchronize with the incoming data stream before the next Frame begins.      
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


entity frame_parser is
  port (
    clk        : in  std_logic; --  clock input for synchronizing the frame parsing process
    reset      : in  std_logic; -- async reset

    -- Byte-stream input
    data_in    : in  std_logic_vector(7 downto 0); -- 8-bit data bus
    data_valid : in  std_logic; -- Indicates that the data on data_in is valid           --> Maybe we don't need this if we can rely on the preamble/SFD to indicate valid data, but it can be useful for timing control and to avoid false triggers during idle periods.
    header_done : in  std_logic;  -- Indicates that the header has been fully received
    drop_frame  : in  std_logic;  -- Indicates that the current frame should be dropped   --> From where do we get this signal? Could be an output from the FSC Checker

    -- Output (valid once mac_valid = '1')
    data_out   : out  std_logic_vector(7 downto 0); -- 8-bit data bus 
    sof        : out  std_logic;  -- Start-of-frame pulse
    eof        : out  std_logic;  -- End-of-frame pulse
    lof        : out std_logic;  -- Header-complete pulse (valid with EOF)
    
    dst_mac    : out mac_addr_t; -- Destination MAC address /subtype mac_addr_t is std_logic_vector(47 downto 0);
    src_mac    : out mac_addr_t; -- Source MAC address
    mac_valid  : out std_logic;  -- Indicates that the MAC addresses are valid --> How is a MAC address considered valid? Do we need to check for multicast/broadcast addresses or other invalid patterns, or is it sufficient to just indicate that we've successfully parsed the header?

    ethertype  : out std_logic_vector(15 downto 0) -- EtherType field from the header
  );
end entity frame_parser;

architecture rtl of frame_parser is
  type state_t is (IDLE, ST_Preamble, ST_SFD, ST_DST, ST_SRC, ST_ETHER, ST_PAYLOAD); -- State machine states for parsing the Ethernet frame
  signal state      : state_t := IDLE; -- State variable to track the current stage of frame parsing
  signal prev_data_valid : std_logic := '0'; -- Registered copy of data_valid for end-of-frame detection

  signal dst_buf    : mac_addr_t := (others => '0'); -- Buffer to hold the incoming bytes for the destination MAC address until fully received
  signal src_buf    : mac_addr_t := (others => '0'); -- Buffer to hold the incoming bytes for the source MAC address until fully received
  signal ether_buf  : std_logic_vector(15 downto 0) := (others => '0'); -- Buffer to hold the incoming bytes for the EtherType field until fully received
  signal byte_cnt   : integer range 0 to 6 := 0; -- Shared byte counter (uses up to 6 during preamble detection)

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then                 -- Asynchronous reset: clear all state and outputs
        state      <= IDLE;
        dst_buf    <= (others => '0');
        src_buf    <= (others => '0');
        ether_buf  <= (others => '0');
        byte_cnt   <= 0;
        prev_data_valid <= '0';

        data_out   <= (others => '0');
        sof        <= '0';
        eof        <= '0';
        lof        <= '0';
        mac_valid  <= '0';
        dst_mac    <= (others => '0');
        src_mac    <= (others => '0');
        ethertype  <= (others => '0');
      else
        -- Default outputs are one-cycle pulses unless explicitly asserted below.
        data_out <= (others => '0');
        sof <= '0';
        eof <= '0';
        lof <= '0';


        if drop_frame = '1' then
          state     <= IDLE;
          byte_cnt  <= 0;
          mac_valid <= '0';
        elsif data_valid = '1' then
          case state is
            when IDLE => 
              -- Wait for the first byte of the preamble (0x55) to start parsing a new frame.
              if data_in = x"55" then
                byte_cnt <= 1; -- Count first preamble byte seen in IDLE.
                state <= ST_Preamble;
              end if;

            when ST_preamble =>              -- Expecting 7 bytes of preamble (0x55). After receiving 7 bytes, expect SFD (0xD5).
              if data_in = x"55" then
                if byte_cnt = 6 then
                  -- Seventh preamble byte received, next byte must be SFD.
                  byte_cnt <= 0;
                  state    <= ST_SFD;
                else
                  byte_cnt <= byte_cnt + 1;
                end if;
              else
                -- If we receive a byte that is not 0x55 during the preamble, reset to IDLE.
                state <= IDLE;
                byte_cnt <= 0;
              end if;

            when ST_SFD =>              -- Expecting the Start of Frame Delimiter (SFD) which should be 0xD5.
              if data_in = x"D5" then
                mac_valid <= '0';
                byte_cnt  <= 0;      -- Reset counter; first MAC byte arrives next cycle
                state     <= ST_DST;
              else
                -- If we receive a byte that is not 0xD5, reset to IDLE.
                state <= IDLE;
                byte_cnt <= 0;
              end if;                  

            when ST_DST =>
              data_out <= data_in;

              case byte_cnt is
                when 0 => dst_buf(47 downto 40) <= data_in;
                          sof <= '1'; -- Assert start-of-frame pulse on the first byte of the destination MAC address.
                when 1 => dst_buf(39 downto 32) <= data_in;
                when 2 => dst_buf(31 downto 24) <= data_in;
                when 3 => dst_buf(23 downto 16) <= data_in;
                when 4 => dst_buf(15 downto 8)  <= data_in;
                when 5 => dst_buf(7 downto 0)   <= data_in;
                when others => null;
              end case;

              if byte_cnt = 5 then
                byte_cnt <= 0;
                state    <= ST_SRC;
              else
                byte_cnt <= byte_cnt + 1;
              end if;

            when ST_SRC =>
              data_out <= data_in;

              case byte_cnt is
                when 0 => src_buf(47 downto 40) <= data_in;
                when 1 => src_buf(39 downto 32) <= data_in;
                when 2 => src_buf(31 downto 24) <= data_in;
                when 3 => src_buf(23 downto 16) <= data_in;
                when 4 => src_buf(15 downto 8)  <= data_in;
                when 5 => src_buf(7 downto 0)   <= data_in;
                when others => null;
              end case;

              if byte_cnt = 5 then
                byte_cnt <= 0;
                state    <= ST_ETHER;
              else
                byte_cnt <= byte_cnt + 1;
              end if;

            when ST_ETHER => -- Expecting 2 bytes of EtherType field after the source MAC address.
              data_out <= data_in;

              if byte_cnt = 0 then
                ether_buf(15 downto 8) <= data_in;
                byte_cnt <= 1;
              else
                ether_buf(7 downto 0) <= data_in;

                dst_mac    <= dst_buf;
                src_mac    <= src_buf;
                ethertype  <= ether_buf(15 downto 8) & data_in;
                mac_valid  <= '1';
                lof        <= '1';

                byte_cnt   <= 0;
                state      <= ST_PAYLOAD;
              end if;

            when ST_PAYLOAD =>
              -- Forward the payload and FCS bytes until data_valid drops.
              data_out <= data_in;

              -- Hold valid header outputs until an external header_done pulse arrives.
              if header_done = '1' then
                mac_valid <= '0';
              end if;
          end case;

        elsif prev_data_valid = '1' and data_valid = '0' then
          eof       <= '1';
          state     <= IDLE;
          byte_cnt  <= 0;
          mac_valid <= '0';
        elsif state = ST_PAYLOAD and header_done = '1' then
          mac_valid <= '0';
        end if;

        prev_data_valid <= data_valid;
      end if;
    end if;
  end process;

end architecture rtl;
