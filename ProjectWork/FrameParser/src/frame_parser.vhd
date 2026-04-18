library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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


-- Idee: Frame parser bekommt daten von Tx signal 8 bit breit und ein valid signal solange bytes gesendet werden. er extrahiert in zwei vektoren (47 bit) die source mac und dest. mac adresse. die werden witergeben an Mac lernich sobald der FCS check sagt das der check gültig ist. 
--- Die einzelnen bytes werden an fcs weitergeleitet und eine eof flagg gesetzt wenn das letzte byte weitergeleitet wurde.
-- zu den daten an fcs wird gleichzeitig start of frame flag gesetzt die länge wird gezählt und auch weitergegeben. 

entity frame_parser is
  port (
    clk        : in  std_logic;                       --  clock input for synchronizing the frame parsing process
    reset      : in  std_logic;                       -- async reset

    -- Byte-stream input
    data_in    : in  std_logic_vector(7 downto 0);    -- 8-bit data bus
    data_valid : in  std_logic;                       -- Indicates that the data on data_in is valid
    
    -- Output 
    data_out   : out  std_logic_vector(7 downto 0);   -- 8-bit data bus 
    sof        : out  std_logic;                      -- Start-of-frame pulse
    eof        : out  std_logic;                      -- End-of-frame pulse end of payload --> fcs follows
    lof        : out std_logic;                       -- length of frame ???

    dst_mac    : out std_logic_vector(47 downto 0);   -- Destination MAC address
    src_mac    : out std_logic_vector(47 downto 0);   -- Source MAC address
    macs_valid  : out std_logic                       -- Macs valid, pulse when dst_mac and src_mac are valid and can be used for MAC learning
  );
end entity frame_parser;

architecture rtl of frame_parser is
  type state_t is (IDLE, ST_Preamble, ST_SFD, ST_DST, ST_SRC, ST_ETHER, ST_PAYLOAD, ST_FCS);  -- State machine states for parsing the Ethernet frame
  signal state      : state_t := IDLE;                                                        -- State variable to track the current stage of frame parsing

  signal dst_buf    : std_logic_vector(47 downto 0) := (others => '0');                       -- Buffer to hold the incoming bytes for the destination MAC address until fully received
  signal src_buf    : std_logic_vector(47 downto 0) := (others => '0');                       -- Buffer to hold the incoming bytes for the source MAC address until fully received
  signal ether_byte_0 : std_logic_vector(7 downto 0) := (others => '0');                      -- Temporary storage for first EtherType byte
  signal byte_cnt   : integer range 0 to 1500 := 0;                                           -- Shared byte counter (uses up to 6 during preamble detection)
  signal payload_length : integer range 0 to 1500 := 0;                                       -- Extracted payload length from length/ethertype field
  signal ethertype  : std_logic_vector(15 downto 0) := (others => '0');                       -- EtherType field from the header https://en.wikipedia.org/wiki/EtherType

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then                               -- Asynchronous reset: clear all state and outputs
        state      <= IDLE;
        dst_buf    <= (others => '0');
        src_buf    <= (others => '0');
        ether_byte_0 <= (others => '0');
        payload_length <= 0;
        byte_cnt   <= 0;

        data_out   <= (others => '0');
        sof        <= '0';
        eof        <= '0';
        lof        <= '0';
        macs_valid <= '0';
        dst_mac    <= (others => '0');
        src_mac    <= (others => '0');
        ethertype  <= (others => '0');
      else
        data_out <= (others => '0');
        sof <= '0';
        eof <= '0';
        macs_valid <= '0';
        lof <= '0';

        if data_valid = '1' then
          case state is
            when IDLE =>                                -- dont look for pattern but count byte               
              state <= ST_Preamble;
              byte_cnt <= 1;                            -- Start counting bytes for preamble detection
              
            when ST_preamble =>                         -- Expecting 7 bytes of preamble (0x55). After receiving 7 bytes, expect SFD (0xD5).
                if byte_cnt = 6 then                    -- Seventh preamble byte received, next byte must be SFD.  

                  state    <= ST_SFD;
                  byte_cnt <= 0;                        -- Reset byte count for SFD detection
                else
                  byte_cnt <= byte_cnt + 1;
                end if;

            when ST_SFD =>                              -- Expecting the Start of Frame Delimiter (SFD) which should be 0xD5.
              if data_in = x"D5" then
                sof <= '1'; 

                state     <= ST_DST;
                byte_cnt  <= 0;                         -- Reset byte count for destination MAC address reception 
              else                                      -- If we receive a byte that is not 0xD5, reset to IDLE.
                state <= IDLE;
                byte_cnt <= 0;
              end if;                  

            when ST_DST =>
              data_out <= data_in;                      -- from here on we write to the FCS checker

              case byte_cnt is
                when 0 => dst_buf(47 downto 40) <= data_in;                          
                when 1 => dst_buf(39 downto 32) <= data_in;
                when 2 => dst_buf(31 downto 24) <= data_in;
                when 3 => dst_buf(23 downto 16) <= data_in;
                when 4 => dst_buf(15 downto 8)  <= data_in;
                when 5 => dst_buf(7 downto 0)   <= data_in;
                when others => null;
              end case;

              if byte_cnt = 5 then
                state    <= ST_SRC;
                byte_cnt <= 0;
              else
                byte_cnt <= byte_cnt + 1;
              end if;

            when ST_SRC =>                                  -- set variable for MAC Learning "1" we are writing src_mac now
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

              byte_cnt <= byte_cnt + 1;

              if byte_cnt = 5 then
                state    <= ST_ETHER;
                byte_cnt <= 0;
              end if;

            when ST_ETHER => 
              data_out <= data_in;

              if byte_cnt = 0 then
                ether_byte_0 <= data_in;
                byte_cnt <= 1;
              else              
                ethertype  <= ether_byte_0 & data_in;
                
                -- Extract payload length from ethertype field: if <= 1500, it's the length; otherwise use 1500 as default
                if unsigned(ether_byte_0 & data_in) <= 1500 then
                  payload_length <= to_integer(unsigned(ether_byte_0 & data_in));
                else
                  payload_length <= 1500;                  -- Default for EtherType frames
                end if;

                lof        <= '1';
                macs_valid <= '1';                        -- Assert macs_valid pulse when both dst_mac and src_mac are valid and can be used for MAC learning.
                dst_mac    <= dst_buf;                
                src_mac    <= src_buf;

                state      <= ST_PAYLOAD;
                byte_cnt   <= 0;
              end if;

            when ST_PAYLOAD =>
              -- Forward the payload and FCS bytes until data_valid drops.
              data_out <= data_in;

              if byte_cnt = payload_length - 1 then
                eof <= '1'; -- Assert end-of-frame pulse on the last byte of the payload.

                state <= ST_FCS; -- Transition to FCS state after expected payload length is received.
                byte_cnt <= 0; -- Reset byte count for FCS reception
              else
                byte_cnt <= byte_cnt + 1;
              end if;
              
            when ST_FCS =>
              -- Keep forwarding bytes while waiting for end-of-frame.
              data_out <= data_in;

              byte_cnt <= byte_cnt + 1; 
              if byte_cnt = 3 then
                state <= IDLE; -- Reset to IDLE after processing the frame
                byte_cnt <= 0; -- Reset byte count for next frame
              end if;

          end case;
        end if; -- if data_valid
      end if; -- if reset
    end if; -- if rising_edge
  end process;

end architecture rtl;
