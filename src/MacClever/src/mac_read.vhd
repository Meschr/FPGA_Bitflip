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
        dest0  : out std_logic_vector(3 downto 0);
        valid0 : out std_logic;
        ack0   : out std_logic; 
        dest1  : out std_logic_vector(3 downto 0);
        valid1 : out std_logic;
        ack1   : out std_logic;
        dest2  : out std_logic_vector(3 downto 0);
        valid2 : out std_logic;
        ack2   : out std_logic;
        dest3  : out std_logic_vector(3 downto 0);
        valid3 : out std_logic;
        ack3   : out std_logic;

        -- Service (bram interfacing)
        rdata  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        raddr  : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        ren    : out std_logic
    );
end mac_read;

architecture rtl of mac_read is
    type state_t is (ZERO, ZERO_WAIT, ZERO_OUT, ONE, ONE_WAIT, ONE_OUT, TWO, TWO_WAIT, TWO_OUT, THREE, THREE_WAIT, THREE_OUT);
    signal state, state_next : state_t;

    function to_onehot(sel : std_logic_vector(1 downto 0)) return std_logic_vector is
        variable oh : std_logic_vector(3 downto 0) := (others => '0');
    begin
        case sel is
            when "00" => oh := "0001";
            when "01" => oh := "0010";
            when "10" => oh := "0100";
            when others => oh := "1000";
        end case;
        return oh;
    end function;

    signal raddr_next : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal ren_next   : std_logic;

    signal dest0_reg, dest1_reg, dest2_reg, dest3_reg : STD_LOGIC_VECTOR(3 downto 0);
    signal dest0_next, dest1_next, dest2_next, dest3_next : STD_LOGIC_VECTOR(3 downto 0);
    signal valid0_reg, valid1_reg, valid2_reg, valid3_reg : std_logic := '0';
    signal valid0_next, valid1_next, valid2_next, valid3_next : std_logic;
    signal ack0_reg, ack1_reg, ack2_reg, ack3_reg : std_logic;
    signal ack0_next, ack1_next, ack2_next, ack3_next : std_logic;
    
begin

    -- Round robin combinational: decide which port to read next
    round_robin_comb : process(state, req0, req1, req2, req3, addr0, addr1, addr2, addr3, rdata, 
                               dest0_reg, dest1_reg, dest2_reg, dest3_reg,
                               valid0_reg, valid1_reg, valid2_reg, valid3_reg)
    begin
        -- defaults
        state_next   <= state;
        raddr_next   <= (others => '0');
        ren_next     <= '0';
        dest0_next <= dest0_reg;
        dest1_next <= dest1_reg;
        dest2_next <= dest2_reg;
        dest3_next <= dest3_reg;
        valid0_next <= valid0_reg;
        valid1_next <= valid1_reg;
        valid2_next <= valid2_reg;
        valid3_next <= valid3_reg;
        ack0_next <= '0';
        ack1_next <= '0';
        ack2_next <= '0';
        ack3_next <= '0';

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
                state_next <= ZERO_OUT;
                ack0_next <= '1';
            when ZERO_OUT =>
                state_next <= ONE;
                valid0_next <= '1';
                if unsigned(rdata(DATA_WIDTH-1 downto 2)) = 0 then
                    dest0_next  <= "1110";
                else
                    dest0_next <= to_onehot(rdata(1 downto 0));
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
                ack1_next <= '1';
            when ONE_OUT =>
                state_next <= TWO;
                valid1_next <= '1';
                if unsigned(rdata(DATA_WIDTH-1 downto 2)) = 0 then
                    dest1_next <= "1101";
                else
                    dest1_next <= to_onehot(rdata(1 downto 0));
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
                ack2_next <= '1';
            when TWO_OUT =>
                state_next <= THREE;
                valid2_next <= '1';
                if unsigned(rdata(DATA_WIDTH-1 downto 2)) = 0 then
                    dest2_next <= "1011";
                else
                    dest2_next <= to_onehot(rdata(1 downto 0));
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
                ack3_next <= '1';
            when THREE_OUT =>
                state_next <= ZERO;
                valid3_next <= '1';
                if unsigned(rdata(DATA_WIDTH-1 downto 2)) = 0 then
                    dest3_next <= "0111";
                else
                    dest3_next <= to_onehot(rdata(1 downto 0));
                end if;
        end case;
    end process round_robin_comb;

    -- sequential: register state and BRAM control outputs
    round_robin_seq : process(clk, rst, state, raddr_next, ren_next, dest0_next, dest1_next, dest2_next, dest3_next,
                               valid0_next, valid1_next, valid2_next, valid3_next,
                               ack0_next, ack1_next, ack2_next, ack3_next)
    begin
        if rst = '0' then
            state <= ZERO;
            raddr <= (others => '0');
            ren <= '0';
            dest0_reg <= (others => '0');
            dest1_reg <= (others => '0');
            dest2_reg <= (others => '0');
            dest3_reg <= (others => '0');
            valid0_reg <= '0';
            valid1_reg <= '0';
            valid2_reg <= '0';
            valid3_reg <= '0';
            ack0_reg <= '0';
            ack1_reg <= '0';
            ack2_reg <= '0';
            ack3_reg <= '0';

        elsif rising_edge(clk) then
            state <= state_next;
            raddr <= raddr_next;
            ren <= ren_next;
            dest0_reg <= dest0_next;
            dest1_reg <= dest1_next;
            dest2_reg <= dest2_next;
            dest3_reg <= dest3_next;
            valid0_reg <= valid0_next;
            valid1_reg <= valid1_next;
            valid2_reg <= valid2_next;
            valid3_reg <= valid3_next;
            ack0_reg <= ack0_next;
            ack1_reg <= ack1_next;
            ack2_reg <= ack2_next;
            ack3_reg <= ack3_next;
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

    ack0 <= ack0_reg;
    ack1 <= ack1_reg;
    ack2 <= ack2_reg;
    ack3 <= ack3_reg;
    
end rtl;