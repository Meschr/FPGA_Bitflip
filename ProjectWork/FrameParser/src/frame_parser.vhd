library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac_pkg.all;

------------------- Ethernet Package Frame---------------------------------------------------------------------------------------------------------------------------------------------------
  -- Preamble (7 Byte) | SFD : Start of Frame Delimeter |Destination MAC (6 Byte) | Source MAC (6 Byte) | EtherType (2 Byte) | Payload (46-1500 Byte) | CRC (4 Byte) | Idle Line State (12 Byte)

  -- Preamble is a 7 Byte field which just consists series of 1s and 0s 
    --like 10101010101010101010?. 56 Bits like this in sequence. This is to 
    --make sure the receiver clocks are synchronized, lock on to the Data Stream 
    --before the actual Frame begins

  -- Start of Frame Delimeter ? This is the continuation of Preamble which 
    --indicates the start of the Frame. It is a 1 Byte field with value 10101011. 
    --This is to make sure that the receiver can identify the start of the Frame 
    --and differentiate it from the Preamble.

  -- Destination MAC Address ? This is a 6 Byte field which contains the MAC address 
    --of the destination device. It is used by the receiver to determine if the Frame is intended for it or not.
        
  -- Source MAC Address ? This is a 6 Byte field which contains the MAC address of 
    --the source device. It is used by the receiver to identify the sender of the Frame
    --and for various network management purposes.  

  -- EtherType ? This is a 2 Byte field which indicates the type of the payload data from the upper layer. 
    --It is used by the receiver to determine how to process the payload. For example, 
    --0x0800 is an IPv4 packet, 0x86dd is for IPv6, 0x0806 is an ARP, 0x8100 for a Dot(.)1Q Frame, etc.

  -- Payload ? This is the actual data being transmitted in the Frame. It can be between 
    --46 and 1500 Bytes in length. The payload can contain various types of data, such as 
    --IP packets, ARP messages, or other types of network traffic.  

  -- CRC (Cyclic Redundancy Check) ? This is a 4 Byte field which contains a checksum of the 
    --Frame. It is used by the receiver to detect errors in the Frame.   constant genPoly : std_logic_vector(31 downto 0) := x"04C11DB7";

  -- Idle Line State ? This is a 12 Byte field which indicates that the line is idle and ready for the next Frame. 
    --It consists of a series of 1s and 0s, similar to the Preamble, and is used to ensure that the receiver can synchronize with the incoming data stream before the next Frame begins.      
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


entity frame_parser is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    -- Byte-stream input
    data_in    : in  std_logic_vector(7 downto 0); -- 8-bit data bus
    data_valid : in  std_logic; -- Indicates that the data on data_in is valid
    header_done : in  std_logic;  -- Indicates that the header has been fully received
    drop_frame  : in  std_logic;  -- Indicates that the current frame should be dropped

    -- Output (valid once mac_valid = '1')
    sof        : out  std_logic;  -- Start-of-frame pulse
    eof        : out  std_logic;  -- End-of-frame pulse
    lof       : out  std_logic;  -- Length of frame (only valid at EOF)
    
    dst_mac    : out mac_addr_t; -- Destination MAC address
    src_mac    : out mac_addr_t; -- Source MAC address
    mac_valid  : out std_logic;   -- Indicates that the MAC addresses are valid

    ethertype  : out std_logic_vector(15 downto 0);
  );
end entity frame_parser;

architecture rtl of frame_parser is

  type state_t is (IDLE, DST_MAC, SRC_MAC, DONE);
  signal state   : state_t := IDLE; -- Current state of the state machine

  signal byte_cnt   : integer range 0 to 11 := 0;
  signal dst_buf    : mac_addr_t := (others => '0');
  signal src_buf    : mac_addr_t := (others => '0');

begin

end architecture rtl;
