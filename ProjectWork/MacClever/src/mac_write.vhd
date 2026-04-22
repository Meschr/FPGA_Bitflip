library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- This component implements the orchestration of the round robin logic 
-- behind writing with 4 different requesting entities (4 ports) to the mac table.
-- Each port can request a write, and when it is the port's turn, the source port
-- is written as the destination. The write data is cached each time there is a req signal asserted,
-- but the write is only commited when the frame check crc is valid. If the data isn't to be written
-- at a certain moment the counters are decreased until they reach 0, at which point it is invalidated.
-- The decrementing takes 1 read an then 1 write action that takes up a lot of clocks, only executed
-- when enough stagnant time is expected. This requires that this entity has it's designated read port
-- in the bram.
-- The counter stored in the first DATA_WIDTH-2 bits of the memory word set to maximum at each write. 
-- The other 2 bits represent the current source, and future destination port.
-- 0b00: port 0
-- 0b01: port 1
-- 0b10: port 2
-- 0b11: port 3
-- 
-- Ports:
-- in  :
--     addrx  : the hash of the mac address requested, 16 bit crc, least signifiant ADDR_WIDTH bits as address
--     reqx   : requesting a read. assert at the same time as giving the address
--     validx : the fcs check was passed, the write action can be commited. 

entity mac_read is
    generic (
        ADDR_WIDTH : positive := 13; -- address size
        DATA_WIDTH : positive := 8   -- bram depth
    );
    port (

        -- System
        clk    : in  std_logic;
        rst    : in  std_logic;
    
        -- Eingaben
        addr0  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        req0   : in  std_logic;
        valid0 : in  std_logic;
        addr1  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        req1   : in  std_logic;
        valid1 : in  std_logic;
        addr2  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        req2   : in  std_logic;
        valid2 : in  std_logic;
        addr3  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        req3   : in  std_logic;
        valid3 : in  std_logic;

        -- Service (bram interfacing)
        wdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        waddr  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        wen    : out std_logic;
        rdata  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        raddr  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        ren    : out std_logic
    );
end mac_read;