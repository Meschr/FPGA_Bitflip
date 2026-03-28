library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs_check_parallel is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic; -- async
    start_of_frame : in  std_logic; -- arrival of first byte
    end_of_frame   : in  std_logic; -- arrival of first FCS byte
    data_in        : in  std_logic_vector(7 downto 0);
    fcs_error      : out std_logic
  );
end fcs_check_parallel;

architecture rtl of fcs_check_parallel is

  constant genPoly : std_logic_vector(31 downto 0) := x"04C11DB7";

  signal crc_reg   : std_logic_vector(31 downto 0) := (others => '0');
  signal crc_next  : std_logic_vector(31 downto 0);

  signal checking  : std_logic := '0';
  signal in_fcs    : std_logic := '0';
  signal fcs_cnt   : unsigned(5 downto 0) := (others => '0');
  signal head_cnt  : unsigned(5 downto 0) := (others => '0');

  signal bit_valid : std_logic;

begin

  bit_valid <= start_of_frame or checking;

crc_comb : process(crc_reg, data_in, head_cnt, end_of_frame, in_fcs, bit_valid)
  variable c        : std_logic_vector(31 downto 0);
  variable feedback : std_logic;
  variable din_eff  : std_logic_vector(7 downto 0);
begin
	
	if bit_valid = '1' then
	 
	  if (head_cnt < 4) then
		 din_eff := not data_in;
	  elsif (in_fcs = '1') or (end_of_frame = '1') then
		 din_eff := not data_in;
	  else
		 din_eff := data_in;
	  end if;
	
	  c := crc_reg;
	  for i in 7 downto 0 loop
		 feedback := c(31) xor din_eff(i);
		 c        := c(30 downto 0) & '0';
		 if feedback = '1' then
			c := c xor genPoly;
		 end if;
	  end loop;
	else 
	 c := (others => '0');
	end if ;

  crc_next <= c;
end process;

  seq : process(clk, reset)
  begin
    if reset = '1' then
      crc_reg   <= (others => '0');
      checking  <= '0';
      in_fcs    <= '0';
      fcs_cnt   <= (others => '0');
      fcs_error <= '0';
      head_cnt  <= (others => '0');

    elsif rising_edge(clk) then

      if start_of_frame = '1' then
        checking  <= '1';
        in_fcs    <= '0';
        fcs_cnt   <= (others => '0');
        fcs_error <= '0';
        head_cnt  <= (others => '0');
      end if;

      -- Process a bit whenever valid (SOF cycle included)
      if bit_valid = '1' then
        crc_reg <= crc_next;

        if head_cnt < 4 then
          head_cnt <= head_cnt + 1;
			 elsif fcs_cnt = 3 then
				head_cnt <= (others => '0');
		
		 end if;
        
        if end_of_frame = '1' then
          in_fcs  <= '1';
          fcs_cnt <= to_unsigned(1, fcs_cnt'length);  
        end if;

        -- evalute fcs after 32 bits
        if (in_fcs = '1') or (end_of_frame = '1') then
          if fcs_cnt = 3 then
           
            if crc_next = x"00000000" then
              fcs_error <= '0';
            else
              fcs_error <= '1';
            end if;

            checking <= '0';
            in_fcs   <= '0';
          else
            fcs_cnt <= fcs_cnt + 1;
          end if;
        end if;
      end if;

    end if;
  end process;

end rtl;