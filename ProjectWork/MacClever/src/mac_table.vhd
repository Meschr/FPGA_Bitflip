library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mac_table is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        src_mac0   : in  std_logic_vector(47 downto 0);
        src_req0   : in  std_logic;
        fcs_valid0 : in  std_logic;
        src_mac1   : in  std_logic_vector(47 downto 0);
        src_req1   : in  std_logic;
        fcs_valid1 : in  std_logic;
        src_mac2   : in  std_logic_vector(47 downto 0);
        src_req2   : in  std_logic;
        fcs_valid2 : in  std_logic;
        src_mac3   : in  std_logic_vector(47 downto 0);
        src_req3   : in  std_logic;
        fcs_valid3 : in  std_logic;

        dst0       : out integer 0 to 3;
        dst_valid0 : out std_logic;
        dst1       : out integer 0 to 3;
        dst_valid1 : out std_logic;
        dst2       : out integer 0 to 3;
        dst_valid2 : out std_logic;
        dst3       : out integer 0 to 3;
        dst_valid3 : out std_logic
        );
end mac_table;
        -- -- From mac_write (port A - read/write during normal op)
        -- addra  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        -- memena : out std_logic;
        -- wena   : out std_logic;
        -- wdataa : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- rdataa : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        -- -- From mac_read (port B - read only)
        -- addrb  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        -- memenb : out std_logic;
        -- wenb   : out std_logic;
        -- wdatab : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- rdatab : in  std_logic_vector(DATA_WIDTH-1 downto 0)