LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

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

ENTITY frame_parser IS
  PORT (
    clk : IN STD_LOGIC; --  clock input for synchronizing the frame parsing process
    reset : IN STD_LOGIC; -- async reset

    -- Byte-stream input
    data_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- 8-bit data bus
    data_valid : IN STD_LOGIC; -- Indicates that the data on data_in is valid

    -- Output 
    data_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- 8-bit data bus 
    sof : OUT STD_LOGIC; -- Start-of-frame pulse
    eof : OUT STD_LOGIC; -- End-of-frame pulse end of payload --> fcs follows

    dst_mac : OUT STD_LOGIC_VECTOR(47 DOWNTO 0); -- Destination MAC address
    dst_valid : OUT STD_LOGIC; -- Destination MAC valid, pulse when dst_mac is valid and can be used for MAC learning
    src_mac : OUT STD_LOGIC_VECTOR(47 DOWNTO 0); -- Source MAC address
    src_valid : OUT STD_LOGIC -- Source MAC valid, pulse when src_mac is valid and can be used for MAC learning
  );
END ENTITY frame_parser;

ARCHITECTURE rtl OF frame_parser IS
  TYPE state_t IS (IDLE, ST_Preamble, ST_SFD, ST_DST, ST_SRC, ST_ETHER, ST_PAYLOAD_FCS); -- State machine states for parsing the Ethernet frame
  SIGNAL state : state_t := IDLE; -- State variable to track the current stage of frame parsing

  SIGNAL dst_buf : STD_LOGIC_VECTOR(47 DOWNTO 0) := (OTHERS => '0'); -- Buffer to hold the incoming bytes for the destination MAC address until fully received
  SIGNAL src_buf : STD_LOGIC_VECTOR(47 DOWNTO 0) := (OTHERS => '0'); -- Buffer to hold the incoming bytes for the source MAC address until fully received
  SIGNAL ether_byte_0 : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- Temporary storage for first EtherType byte
  SIGNAL byte_cnt : INTEGER RANGE 0 TO 1500 := 0; -- Shared byte counter (uses up to 6 during preamble detection)
  SIGNAL payload_length : INTEGER RANGE 0 TO 1500 := 0; -- Extracted payload length from length/ethertype field
  SIGNAL ethertype : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0'); -- EtherType field from the header https://en.wikipedia.org/wiki/EtherType
  SIGNAL data_valid_prev : STD_LOGIC := '0'; -- Previous data_valid value for falling-edge detection

BEGIN

  PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' THEN -- Asynchronous reset: clear all state and outputs
        state <= IDLE;
        dst_buf <= (OTHERS => '0');
        src_buf <= (OTHERS => '0');
        ether_byte_0 <= (OTHERS => '0');
        payload_length <= 0;
        byte_cnt <= 0;
        data_valid_prev <= '0';

        data_out <= (OTHERS => '0');
        sof <= '0';
        eof <= '0';
        dst_valid <= '0';
        src_valid <= '0';
        dst_mac <= (OTHERS => '0');
        src_mac <= (OTHERS => '0');
        ethertype <= (OTHERS => '0');
      ELSE
        data_out <= (OTHERS => '0');
        sof <= '0';
        eof <= '0';
        dst_valid <= '0';
        src_valid <= '0';

        -- Detect end-of-frame from data_valid falling edge.
        -- This pulse occurs one cycle after the last valid byte.
        IF (data_valid_prev = '1') AND (data_valid = '0') AND (state = ST_PAYLOAD_FCS) THEN
          eof <= '1';
          state <= IDLE;
          byte_cnt <= 0;
        ELSIF data_valid = '1' THEN
          CASE state IS
            WHEN IDLE => -- dont look for pattern but count byte
              state <= ST_Preamble;
              byte_cnt <= 1; -- Start counting bytes for preamble detection

            WHEN ST_Preamble => -- Expecting 7 bytes of preamble (0x55). After receiving 7 bytes, expect SFD (0xD5).
              IF byte_cnt = 6 THEN -- Seventh preamble byte received, next byte must be SFD.
                state <= ST_SFD;
                byte_cnt <= 0; -- Reset byte count for SFD detection
              ELSE
                byte_cnt <= byte_cnt + 1;
              END IF;

            WHEN ST_SFD => -- Expecting the Start of Frame Delimiter (SFD) which should be 0xD5.
              IF data_in = x"D5" THEN
                state <= ST_DST;
                byte_cnt <= 0; -- Reset byte count for destination MAC address reception
              ELSE -- If we receive a byte that is not 0xD5, reset to IDLE.
                state <= IDLE;
                byte_cnt <= 0;
              END IF;

            WHEN ST_DST =>
              data_out <= data_in; -- from here on we write to the FCS checker
              IF byte_cnt = 0 THEN
                sof <= '1'; -- Align SOF with first byte forwarded to CRC checker
              END IF;

              CASE byte_cnt IS
                WHEN 0 => dst_buf(47 DOWNTO 40) <= data_in;
                WHEN 1 => dst_buf(39 DOWNTO 32) <= data_in;
                WHEN 2 => dst_buf(31 DOWNTO 24) <= data_in;
                WHEN 3 => dst_buf(23 DOWNTO 16) <= data_in;
                WHEN 4 => dst_buf(15 DOWNTO 8) <= data_in;
                WHEN 5 => dst_buf(7 DOWNTO 0) <= data_in;
                WHEN OTHERS => NULL;
              END CASE;

              IF byte_cnt = 5 THEN
                state <= ST_SRC;
                byte_cnt <= 0;
                dst_mac <= dst_buf;
                dst_valid <= '1';
              ELSE
                byte_cnt <= byte_cnt + 1;
              END IF;

            WHEN ST_SRC => -- set variable for MAC Learning "1" we are writing src_mac now
              data_out <= data_in;

              CASE byte_cnt IS
                WHEN 0 => src_buf(47 DOWNTO 40) <= data_in;
                WHEN 1 => src_buf(39 DOWNTO 32) <= data_in;
                WHEN 2 => src_buf(31 DOWNTO 24) <= data_in;
                WHEN 3 => src_buf(23 DOWNTO 16) <= data_in;
                WHEN 4 => src_buf(15 DOWNTO 8) <= data_in;
                WHEN 5 => src_buf(7 DOWNTO 0) <= data_in;
                WHEN OTHERS => NULL;
              END CASE;

              byte_cnt <= byte_cnt + 1;

              IF byte_cnt = 5 THEN
                state <= ST_ETHER;
                byte_cnt <= 0;
                src_valid <= '1';
                src_mac <= src_buf;
              END IF;

            WHEN ST_ETHER =>
              data_out <= data_in;

              IF byte_cnt = 0 THEN
                ether_byte_0 <= data_in;
                byte_cnt <= 1;
              ELSE
                ethertype <= ether_byte_0 & data_in;

                -- Extract payload length from ethertype field: if <= 1500, it's the length; otherwise use 1500 as default
                IF unsigned(ether_byte_0 & data_in) <= 1500 THEN
                  payload_length <= to_integer(unsigned(ether_byte_0 & data_in));
                ELSE
                  payload_length <= 1500; -- Default for EtherType frames
                END IF;

                state <= ST_PAYLOAD_FCS;
                byte_cnt <= 0;
              END IF;

            WHEN ST_PAYLOAD_FCS =>
              -- Forward bytes while data_valid is high.
              data_out <= data_in;
              byte_cnt <= byte_cnt + 1;

          END CASE;
        END IF;

        data_valid_prev <= data_valid;

      END IF; -- if reset
    END IF; -- if rising_edge
  END PROCESS;

END ARCHITECTURE rtl;