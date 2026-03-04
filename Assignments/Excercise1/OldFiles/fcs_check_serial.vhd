library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs_check_serial is
	port (
		clk : in std_logic;            -- system clock
		reset : in std_logic;          -- asynchronous reset
		start_of_frame : in std_logic; -- arrival of the first bit.
		end_of_frame : in std_logic;   -- arrival of the first bit in FCS.
		data_in : in std_logic;        -- serial input data.
		fcs_error : out std_logic      -- indicates an error.
	);
end fcs_check_serial;


architecture rtl of fcs_check_serial is

    signal crc_reg  : std_logic_vector(31 downto 0) := (others => '1');
    signal feedback : std_logic;
    signal active   : std_logic := '0';
	 signal fcs_in   : std_logic := '0';
    signal check    : std_logic := '0';  -- one-cycle pulse after last FCS bit
	 signal fcs_cnt   : unsigned(5 downto 0) := (others => '0');
	
	begin
	
	  feedback <= data_in xor crc_reg(31);

		process(clk, reset)
		begin
        if reset = '1' then
            crc_reg   <= (others => '0');
            active    <= '0';
				fcs_in    <= '0';
            check     <= '0';
            fcs_error <= '0';
				
			  elsif rising_edge(clk) then
			
			-- Start of frame: initialise registers to 0xFFFFFFFF
            if start_of_frame = '1' then
                crc_reg   <= (others => '1');
                active    <= '1';
                fcs_error <= '0';
					 check <= '0';
            end if;
				
				-- Serial LFSR: process one bit per clock
            if active = '1' then
					if feedback = '1' then
						crc_reg <= (crc_reg(30 downto 0) & '0') xor x"04C11DB7";
					else
						crc_reg <= (crc_reg(30 downto 0) & '0');
					end if;
				
				end if;
				
				-- End of frame reached raise check to evaluate residue
				if end_of_frame = '1' then
					 if feedback = '1' then
                    crc_reg <= (crc_reg(30 downto 0) & '0') xor x"04C11DB7";
                else
                    crc_reg <= (crc_reg(30 downto 0) & '0');
                end if;
				
                active <= '0';
                fcs_in  <= '1';
					 fcs_cnt <= to_unsigned(1, fcs_cnt'length);
            end if;
				
				if fcs_in = '1' then 
					if feedback = '1' then
						crc_reg <= (crc_reg(30 downto 0) & '0') xor x"04C11DB7";
					else
						crc_reg <= (crc_reg(30 downto 0) & '0');
					end if;
				
					fcs_cnt <= fcs_cnt + 1;
					
					if fcs_cnt = to_unsigned(31, fcs_cnt'length) then
						check <= '1';
						fcs_in <= '0';
					end if;
				end if;
				
				-- Evaluate Residue
				if check = '1' then
                if unsigned(crc_reg) = x"00000000" then
                    fcs_error <= '0';
                else
                    fcs_error <= '1';
                end if;
					 check <= '0';
            end if;
				
			end if;
		end process;

end architecture rtl;
