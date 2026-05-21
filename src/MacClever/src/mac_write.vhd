library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

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
--     reqx   : requesting a read. assert at the same time as giving the address (already registered in source entity)
--     validx : the fcs check was passed, the write action can be commited. 

entity mac_write is
    generic (
        ADDR_WIDTH : POSITIVE := 13; -- address size
        DATA_WIDTH : POSITIVE := 8;  -- bram depth
        -- width of forget counting ratelimiter. remembering items for 2^FORGET_CNT*0,004194304 seconds (2^FORGET_CNT*8192*64/125000000)
        -- FORGET_CNT = 16 is approx 4.5 mins.
        FORGET_CNT : POSITIVE := 16
    );
    port (

        -- System
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;

        -- Inputs
        addr0    : in STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
        req0     : in STD_LOGIC;
        fcs_ok0  : in STD_LOGIC;
        fcs_err0 : in STD_LOGIC;
        addr1    : in STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
        req1     : in STD_LOGIC;
        fcs_ok1  : in STD_LOGIC;
        fcs_err1 : in STD_LOGIC;
        addr2    : in STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
        req2     : in STD_LOGIC;
        fcs_ok2  : in STD_LOGIC;
        fcs_err2 : in STD_LOGIC;
        addr3    : in STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
        req3     : in STD_LOGIC;
        fcs_ok3  : in STD_LOGIC;
        fcs_err3 : in STD_LOGIC;

        -- Outputs
        ack0 : out STD_LOGIC;
        ack1 : out STD_LOGIC;
        ack2 : out STD_LOGIC;
        ack3 : out STD_LOGIC;

        -- Service (bram interfacing)
        addr  : out STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
        wen   : out STD_LOGIC;
        wdata : out STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
        ren   : out STD_LOGIC;
        rdata : in STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0)
    );
end mac_write;

architecture rtl of mac_write is
    signal ack0_sig, ack1_sig, ack2_sig, ack3_sig, ackcnt : STD_LOGIC;
    signal reqcnt : STD_LOGIC;
    signal valid0_reg, valid1_reg, valid2_reg, valid3_reg : STD_LOGIC;
    signal reqcnt_reg : STD_LOGIC;
    signal forget_rate_limit : unsigned(FORGET_CNT - 1 downto 0);
    signal expiry_addr : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);

    type state_t is (ZERO, ONE, TWO, THREE, COUNTER_R, COUNTER_W, COUNTER_WAIT0);
    signal round_robin, round_robin_next : state_t;

    signal addr_next : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal wdata_next : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
    signal wen_next : STD_LOGIC;
    signal ren_next : STD_LOGIC;

begin
    expiry_ratelimiter : process (all)
    begin
        if rst = '0' then
            forget_rate_limit <= (others => '0');
        elsif rising_edge(clk) then
            forget_rate_limit <= forget_rate_limit + 1;
        end if;
        if forget_rate_limit = 0 then
            reqcnt <= '1';
        else
            reqcnt <= '0';
        end if;
    end process expiry_ratelimiter;

    expiry_addr_counter : process (all)
    begin
        if rst = '0' then
            expiry_addr <= (others => '0');
        elsif rising_edge(clk) then
            if ackcnt = '1' then
                expiry_addr <= STD_LOGIC_VECTOR(unsigned(expiry_addr) + 1);
            else
                expiry_addr <= expiry_addr;
            end if;
        end if;
    end process expiry_addr_counter;

    round_robin_comb : process (all)
    begin
        round_robin_next <= ZERO;
        addr_next <= (others => '0');
        wen_next <= '0';
        ren_next <= '0';
        wdata_next <= "00000000";
        ack0_sig <= '0';
        ack1_sig <= '0';
        ack2_sig <= '0';
        ack3_sig <= '0';
        ackcnt <= '0';

        case(round_robin) is
            when ZERO =>
            round_robin_next <= ONE;
            if req0 and valid0_reg then
                addr_next <= addr0;
                wen_next <= '1';
                wdata_next <= "11111100";
                ack0_sig <= '1';
            end if;
            when ONE =>
            round_robin_next <= TWO;
            if req1 and valid1_reg then
                addr_next <= addr1;
                wen_next <= '1';
                wdata_next <= "11111101";
                ack1_sig <= '1';
            end if;
            when TWO =>
            round_robin_next <= THREE;
            if req2 and valid2_reg then
                addr_next <= addr2;
                wen_next <= '1';
                wdata_next <= "11111110";
                ack2_sig <= '1';
            end if;
            when THREE =>
            round_robin_next <= COUNTER_R;
            if req3 and valid3_reg then
                addr_next <= addr3;
                wen_next <= '1';
                wdata_next <= "11111111";
                ack3_sig <= '1';
            end if;
            when COUNTER_R =>
            if reqcnt_reg then
                addr_next <= expiry_addr;
                ren_next <= '1';
                round_robin_next <= COUNTER_WAIT0;
            else
                round_robin_next <= ZERO;
            end if;
            when COUNTER_WAIT0 =>
            round_robin_next <= COUNTER_W;
            when COUNTER_W =>
            round_robin_next <= ZERO;
            ackcnt <= '1';
            if unsigned(rdata(DATA_WIDTH - 1 downto 2)) /= 0 then
                addr_next <= expiry_addr;
                wen_next <= '1';
                wdata_next <= STD_LOGIC_VECTOR(unsigned(rdata(DATA_WIDTH - 1 downto 2)) - 1) & rdata(1 downto 0);
            end if;
        end case;
    end process round_robin_comb;

    round_robin_seq : process (all)
    begin
        if rst = '0' then
            round_robin <= ZERO;
            addr <= (others => '0');
            wen <= '0';
            ren <= '0';
            wdata <= (others => '0');
        elsif rising_edge(clk) then
            round_robin <= round_robin_next;
            addr <= addr_next;
            wen <= wen_next;
            ren <= ren_next;
            wdata <= wdata_next;
        end if;
    end process round_robin_seq;

    buffers : process (all)
    begin
        if rst = '0' then
            valid0_reg <= '0';
            valid1_reg <= '0';
            valid2_reg <= '0';
            valid3_reg <= '0';
            reqcnt_reg <= '0';
        elsif rising_edge(clk) then
            -- Valid signal registration: set by input, cleared by ack
            
            ack0 <= ack0_sig or fcs_err0;
            if ack0_sig = '1' then
                valid0_reg <= '0';
            elsif fcs_ok0 = '1' then
                valid0_reg <= '1';
            else
                valid0_reg <= valid0_reg;
            end if;

            ack1 <= ack1_sig or fcs_err1;
            if ack1_sig = '1' then
                valid1_reg <= '0';
            elsif fcs_ok1 = '1' then
                valid1_reg <= '1';
            else
                valid1_reg <= valid1_reg;
            end if;

            ack2 <= ack2_sig or fcs_err2;
            if ack2_sig = '1' then
                valid2_reg <= '0';
            elsif fcs_ok2 = '1' then
                valid2_reg <= '1';
            else
                valid2_reg <= valid2_reg;
            end if;

            ack3 <= ack3_sig or fcs_err3;
            if ack3_sig = '1' then
                valid3_reg <= '0';
            elsif fcs_ok3 = '1' then
                valid3_reg <= '1';
            else
                valid3_reg <= valid3_reg;
            end if;

            -- Reqcnt registration (unchanged)
            if ackcnt = '1' then
                reqcnt_reg <= '0';
            elsif reqcnt = '1' then
                reqcnt_reg <= '1';
            else
                reqcnt_reg <= reqcnt_reg;
            end if;
        end if;
    end process buffers;
end rtl;
