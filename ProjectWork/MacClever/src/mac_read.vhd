library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

-- This component implements the orchestration of the round robin logic 
-- behind reading with 4 different requesting entities (4 ports) from the mac table.
-- Each port can request a read, and when it is the port's turn, the  requested 
-- destination is output, together with a valid signal. The valid signal is only asserted 
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
        addr1  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        req1   : in  std_logic;
        addr2  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        req2   : in  std_logic;
        addr3  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        req3   : in  std_logic;

        -- Ausgaben
        dest0  : out integer range 0 to 3;
        valid0 : out std_logic;
        dest1  : out integer range 0 to 3;
        valid1 : out std_logic;
        dest2  : out integer range 0 to 3;
        valid2 : out std_logic;
        dest3  : out integer range 0 to 3;
        valid3 : out std_logic;

        -- Service (bram interfacing)
        rdata  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        raddr  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        ren    : out std_logic
    );
end mac_read;

architecture rtl of mac_read is
    type state_t is (ZERO, ZERO_WAIT, ZERO_OUT, ONE, ONE_WAIT, ONE_OUT, TWO, TWO_WAIT, TWO_OUT, THREE, THREE_WAIT, THREE_OUT);
    signal state, state_next : state_t;

    signal raddr_next : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal ren_next   : std_logic;

    signal ack0, ack1, ack2, ack3 : std_logic;

    signal dest0_reg, dest1_reg, dest2_reg, dest3_reg : integer range 0 to 3 := 0;
    signal valid0_reg, valid1_reg, valid2_reg, valid3_reg : std_logic := '0';

begin

    -- Round robin combinational: decide which port to read next
    round_robin_comb : process(state, req0, req1, req2, req3, addr0, addr1, addr2, addr3)
    begin
        -- defaults
        state_next   <= state;
        raddr_next   <= (others => '0');
        ren_next     <= '0';
        ack0 <= '0'; ack1 <= '0'; ack2 <= '0'; ack3 <= '0';

        case state is
            when ZERO =>
                -- advance by default
                state_next <= ONE;
                if req0 = '1' then
                    raddr_next <= addr0;
                    ren_next   <= '1';
                    state_next <= ZERO_WAIT;
                end if;
            when ZERO_WAIT =>
                -- read data available this cycle
                state_next <= ONE;
                ack0 <= '1';
            when ZERO_OUT =>
                state_next <= ONE;
                ack0 <= '1';
                if rdata (DATA_WIDTH-1 downto 2) = (DATA_WIDTH-1 downto 2 => '0') then
                    valid0_reg <= '0';
                else
                    valid0_reg <= '1';
                    dest0_reg <= to_integer(unsigned(rdata(1 downto 0)));
                end if;
                
            when ONE =>
                state_next <= TWO;
                if req1 = '1' then
                    raddr_next <= addr1;
                    ren_next   <= '1';
                    state_next <= ONE_WAIT;
                end if;
            when ONE_WAIT =>
                state_next <= ONE_OUT;
            when ONE_OUT =>
                state_next <= TWO;
                ack1 <= '1';
                if rdata (DATA_WIDTH-1 downto 2) = (DATA_WIDTH-1 downto 2 => '0') then
                    valid1_reg <= '0';
                else
                    valid1_reg <= '1';
                    dest1_reg <= to_integer(unsigned(rdata(1 downto 0)));
                end if;
            when TWO =>
                state_next <= THREE;
                if req2 = '1' then
                    raddr_next <= addr2;
                    ren_next   <= '1';
                    state_next <= TWO_WAIT;
                end if;
            when TWO_WAIT =>
                state_next <= TWO_OUT;
            when TWO_OUT =>
                state_next <= THREE;
                ack2 <= '1';
                if rdata (DATA_WIDTH-1 downto 2) = (DATA_WIDTH-1 downto 2 => '0') then
                    valid2_reg <= '0';
                else
                    valid2_reg <= '1';
                    dest2_reg <= to_integer(unsigned(rdata(1 downto 0)));
                end if;
            when THREE =>
                state_next <= ZERO;
                if req3 = '1' then
                    raddr_next <= addr3;
                    ren_next   <= '1';
                    state_next <= THREE_WAIT;
                end if;
            when THREE_WAIT =>
                state_next <= THREE_OUT;
            when THREE_OUT =>
                state_next <= ZERO;
                ack3 <= '1';
                if rdata (DATA_WIDTH-1 downto 2) = (DATA_WIDTH-1 downto 2 => '0') then
                    valid3_reg <= '0';
                else
                    valid3_reg <= '1';
                    dest3_reg <= to_integer(unsigned(rdata(1 downto 0)));
                end if;
        end case;
    end process round_robin_comb;

    -- sequential: register state and BRAM control outputs
    round_robin_seq : process(clk, rst)
    begin
        if rst = '0' then
            state <= ZERO;
            raddr <= (others => '0');
            ren <= '0';
        elsif rising_edge(clk) then
            state <= state_next;
            raddr <= raddr_next;
            ren <= ren_next;
        end if;
    end process round_robin_seq;

    -- output assignments
    dest0 <= dest0_reg;
    dest1 <= dest1_reg;
    dest2 <= dest2_reg;
    dest3 <= dest3_reg;

    valid0 <= valid0_reg;
    valid1 <= valid1_reg;
    valid2 <= valid2_reg;
    valid3 <= valid3_reg;

end rtl;