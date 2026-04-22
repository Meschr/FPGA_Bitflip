library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- This component should implement the orchestration of the round robin logic 
-- behind reading with 4 different requuesting entities (4 ports).
-- Each port can request a read, and when it is the port's turn, the  requested 
-- destination is the output, with a valid signal. The valid signal is only asserted 
-- if the counter stored in the first DATA_WIDTH-2 bits of the memory word is NOT 0. 
-- If there is no valid destination present at the output of this entity, the packet 
-- should be flooded to all output ports.
-- The other 2 bits represent the destination port. (casted to integer for convenience)
-- 0b00: port 0
-- 0b01: port 1
-- 0b10: port 2
-- 0b11: port 3
-- 
-- Ports:
-- in  :
--     addrx  : the hash of the mac address requested, 16 bit crc, least signifiant ADDR_WIDTH bits as address
--     reqx   : requesting a read. assert at the same time as giving the address
-- out :
--     destx  : the destination the packet requesting with addrx should go
--     validx : wether the current destx is valid. has to be deasserted upon reqx assertion.

entity mac_read is
    generic (
        ADDR_WIDTH : positive := 10; -- address size
        DATA_WIDTH : positive := 8
    );
    port (

        -- System
        clk    : in  std_logic;
        rst    : in  std_logic;
    
        -- Eingaben
        addr0  : in  std_logic_vector(12 downto 0);
        req0   : in  std_logic;
        addr1  : in  std_logic_vector(12 downto 0);
        req1   : in  std_logic;
        addr2  : in  std_logic_vector(12 downto 0);
        req2   : in  std_logic;
        addr3  : in  std_logic_vector(12 downto 0);
        req3   : in  std_logic;

        -- Ausgaben
        dest0  : out integer 0 to 3;
        valid0 : out std_logic;
        dest1  : out integer 0 to 3;
        valid1 : out std_logic;
        dest2  : out integer 0 to 3;
        valid2 : out std_logic;
        dest3  : out integer 0 to 3;
        valid3 : out std_logic;

        -- Service (bram interfacing)
        rdata  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        raddr  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        ren    : out std_logic
    );
end mac_read;