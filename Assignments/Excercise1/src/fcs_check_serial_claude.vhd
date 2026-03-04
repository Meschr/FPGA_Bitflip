library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs_check_serial is
    port (
        clk            : in  std_logic;
        reset          : in  std_logic;
        start_of_frame : in  std_logic;
        end_of_frame   : in  std_logic;
        data_in        : in  std_logic;
        fcs_error      : out std_logic
    );
end fcs_check_serial;

architecture rtl of fcs_check_serial is

    constant genPoly   : std_logic_vector(31 downto 0) := x"04C11DB7";

    signal crc_reg  : std_logic_vector(31 downto 0) := (others => '0');
    signal crc_next : std_logic_vector(31 downto 0);
    signal crc_base : std_logic_vector(31 downto 0);

    signal active   : std_logic := '0';
    signal fcs_in   : std_logic := '0';
    signal fcs_cnt  : unsigned(5 downto 0) := (others => '0');
    signal head_cnt : unsigned(5 downto 0) := (others => '0');

begin

    -- to correctly handle first bit 
    crc_base <= (others => '0') when start_of_frame = '1' else crc_reg;
		
	 -- changes immediately
    crc_comb : process(crc_base, data_in, head_cnt, fcs_in, end_of_frame)
        variable feedback : std_logic;
        variable din_eff  : std_logic;
        variable shifted  : std_logic_vector(31 downto 0);
    begin
        -- first 32 bit and fcs needs to be complemented see excercise
        if (head_cnt < 32) or (fcs_in = '1') or (end_of_frame = '1') then
            din_eff := not data_in;
        else
            din_eff := data_in;
        end if;

        feedback := crc_base(31) xor din_eff;
        shifted  := crc_base(30 downto 0) & '0';

        if feedback = '1' then
            crc_next <= shifted xor genPoly;
        else
            crc_next <= shifted;
        end if;
    end process;
		
	 -- triggers on clk
    seq : process(clk, reset)
    begin
        if reset = '1' then
            crc_reg   <= (others => '0');
            active    <= '0';
            fcs_in    <= '0';
            fcs_cnt   <= (others => '0');
            head_cnt  <= (others => '0');
            fcs_error <= '0';

        elsif rising_edge(clk) then

            -- init with start of frame
            if start_of_frame = '1' then
                active    <= '1';
                fcs_in    <= '0';
                fcs_cnt   <= (others => '0');
                head_cnt  <= (others => '0');
                fcs_error <= '0';
            end if;

            -- handle data bits
            if (active = '1') or (start_of_frame = '1') then
                crc_reg <= crc_next;
                if head_cnt < 32 then
                    head_cnt <= head_cnt + 1;
                end if;
            end if;

            -- handle end of frame and first fcs_bit
            if end_of_frame = '1' then
                crc_reg <= crc_next;
                active  <= '0';
                fcs_in  <= '1';
                fcs_cnt <= to_unsigned(1, fcs_cnt'length);
            end if;

            -- check fcs
            if fcs_in = '1' then
                crc_reg <= crc_next;
                fcs_cnt <= fcs_cnt + 1;

                if fcs_cnt = 31 then
                    if crc_next = x"00000000" then
                        fcs_error <= '0';
                    else
                        fcs_error <= '1';
                    end if;
                    fcs_in <= '0';
                    active <= '0';
                end if;
            end if;

        end if;
    end process;

end architecture rtl;