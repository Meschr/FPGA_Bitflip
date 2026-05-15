LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY frame_parser IS
  PORT (
    clk : IN STD_LOGIC;                           --  clock input for synchronizing the frame parsing process
    reset : IN STD_LOGIC;                         -- async reset

    -- Byte-stream input
    data_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);    -- 8-bit data bus
    data_valid : IN STD_LOGIC;                    -- Indicates that the data on data_in is valid

    -- Output 
    data_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- 8-bit data bus 
    sof : OUT STD_LOGIC;                          -- Start-of-frame pulse
    eof : OUT STD_LOGIC;                          -- End-of-frame pulse end of payload --> fcs follows

    dst_mac : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);  -- Destination MAC address
    dst_valid : OUT STD_LOGIC;                    -- Destination MAC valid, pulse when dst_mac is valid and can be used for MAC learning
    src_mac : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);  -- Source MAC address
    src_valid : OUT STD_LOGIC                     -- Source MAC valid, pulse when src_mac is valid and can be used for MAC learning
  );
END ENTITY frame_parser;

ARCHITECTURE rtl OF frame_parser IS
  TYPE state_t IS (ERR, PREAMBLE, SFD, DST, SRC, ETHER_PAYLOAD_FCS); -- State machine states for parsing the Ethernet frame

  SIGNAL state : state_t;                               -- State variable to track the current stage of frame parsing

  SIGNAL dst_buf : STD_LOGIC_VECTOR(47 DOWNTO 0);       -- Buffer to hold the incoming bytes for the destination MAC address until fully received
  SIGNAL src_buf : STD_LOGIC_VECTOR(47 DOWNTO 0);       -- Buffer to hold the incoming bytes for the source MAC address until fully received
  SIGNAL ether_byte_0 : STD_LOGIC_VECTOR(7 DOWNTO 0);   -- Temporary storage for first EtherType byte
  SIGNAL byte_cnt : INTEGER RANGE 0 TO 1500;            -- Shared byte counter (uses up to 6 during preamble detection)
  SIGNAL data_valid_prev : STD_LOGIC;                   -- Previous data_valid value for falling-edge detection

BEGIN

  PROCESS (clk, reset)
  BEGIN
    IF reset = '0' THEN
      state <= PREAMBLE;
      dst_buf <= (OTHERS => '0');
      src_buf <= (OTHERS => '0');
      ether_byte_0 <= (OTHERS => '0');
      byte_cnt <= 0;
      data_valid_prev <= '0';

      data_out <= (OTHERS => '0');
      sof <= '0';
      eof <= '0';
      dst_valid <= '0';
      src_valid <= '0';
      dst_mac <= (OTHERS => '0');
      src_mac <= (OTHERS => '0');
    
    ELSIF rising_edge(clk) THEN

      data_out <= (OTHERS => '0');
      sof <= '0';
      eof <= '0';
      dst_valid <= '0';
      src_valid <= '0';
      dst_mac <= (others => '0');
      src_mac <= (others => '0');
      data_valid_prev <= data_valid;
      byte_cnt <= 0;

      IF data_valid = '1' THEN
        byte_cnt <= byte_cnt + 1;

        CASE state IS
          WHEN PREAMBLE => -- Expecting 7 bytes of preamble (0x55). After receiving 7 bytes, expect SFD (0xD5).
            IF NOT data_in = x"55" THEN
              state <= ERR;
            ELSIF byte_cnt = 6 THEN -- Seventh preamble byte received, next byte must be SFD.
              state <= SFD;
              data_out <= data_in; -- Forward preamble bytes to FCS checker
            ELSE
              data_out <= data_in; -- Forward preamble bytes to FCS checker
              state <= PREAMBLE;
            END IF;

          WHEN SFD => -- Expecting the Start of Frame Delimiter (SFD) which should be 0xD5.
            IF data_in = x"D5" THEN
              data_out <= data_in; 
              state <= DST;
            ELSE -- If we receive a byte that is not 0xD5, its error
              state <= ERR;
            END IF;

          WHEN DST =>
            data_out <= data_in; 

            IF byte_cnt = 8 THEN
              sof <= '1'; -- Pulse SOF when the first byte of the destination MAC is received
            END IF;

            CASE byte_cnt IS
              WHEN  8 => dst_buf(47 DOWNTO 40) <= data_in;
              WHEN  9 => dst_buf(39 DOWNTO 32) <= data_in;
              WHEN 10 => dst_buf(31 DOWNTO 24) <= data_in;
              WHEN 11 => dst_buf(23 DOWNTO 16) <= data_in;
              WHEN 12 => dst_buf(15 DOWNTO 8) <= data_in;
              WHEN 13 => dst_buf(7 DOWNTO 0) <= data_in;
              WHEN OTHERS => NULL;
            END CASE;

            IF byte_cnt = 13 THEN
              dst_valid <= '1';
              dst_mac <= dst_buf(47 DOWNTO 8) & data_in;
              state <= SRC;
            END IF;

          WHEN SRC => 
            data_out <= data_in;

            CASE byte_cnt IS
              WHEN 14 => src_buf(47 DOWNTO 40) <= data_in;
              WHEN 15 => src_buf(39 DOWNTO 32) <= data_in;
              WHEN 16 => src_buf(31 DOWNTO 24) <= data_in;
              WHEN 17 => src_buf(23 DOWNTO 16) <= data_in;
              WHEN 18 => src_buf(15 DOWNTO 8) <= data_in;
              WHEN 19 => src_buf(7 DOWNTO 0) <= data_in;
              WHEN OTHERS => NULL;
            END CASE;

            IF byte_cnt = 19 THEN
            src_valid <= '1';
            src_mac <= src_buf(47 DOWNTO 8) & data_in;
            state <= ETHER_PAYLOAD_FCS;
            END IF;

          WHEN ETHER_PAYLOAD_FCS =>
            -- Forward bytes while data_valid is high.
            data_out <= data_in;
            byte_cnt <= byte_cnt + 1;
            if byte_cnt > 1526 then
              state <= ERR;
            else 
              state <= ETHER_PAYLOAD_FCS;
            end if;

          WHEN ERR =>
            eof <= '1';
            state <= PREAMBLE;
            byte_cnt <= 0;

        END CASE;

      ELSIF data_valid_prev = '1' THEN
        eof <= '1';
        state <= PREAMBLE;
      ELSE
        state <= PREAMBLE;
      END IF;
    END IF;
  END PROCESS;

END ARCHITECTURE rtl;