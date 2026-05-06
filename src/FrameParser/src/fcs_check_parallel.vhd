library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs_check_parallel is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic; -- async
    start_of_frame : in  std_logic; -- arrival of first byte
    end_of_frame   : in  std_logic; -- arrival of last byte
    data_in        : in  std_logic_vector(7 downto 0);
    fcs_error      : out std_logic;
    fcs_ok         : out std_logic
  );
end fcs_check_parallel;

architecture rtl of fcs_check_parallel is

  constant POLY : std_logic_vector(31 downto 0) := x"04C11DB7";

  signal crc_reg   : std_logic_vector(31 downto 0) := (others => '0');
  signal crc_next  : std_logic_vector(31 downto 0);
  signal checking  : std_logic := '0';
  signal in_fcs    : std_logic := '0';
  signal head_cnt  : unsigned(5 downto 0) := (others => '0');

  signal bit_valid : std_logic;

begin

  bit_valid <= start_of_frame or checking;

------------------------------------------------------------------
-- Combinational CRC next-state (8 bits per cycle, MSB-first)
------------------------------------------------------------------
crc_comb : process(crc_reg, data_in, head_cnt, bit_valid)
  variable c        : std_logic_vector(31 downto 0);
  variable feedback : std_logic;
  variable din_eff  : std_logic_vector(7 downto 0);
begin
	
	if bit_valid = '1' then
	  -- keep your existing inversion policy
	  if (head_cnt < 4) then
		 din_eff := not data_in;
	  else
		 din_eff := data_in;
	  end if;
	
	  -- start from current/base CRC value
	  c := crc_reg;
	
	  -- apply 8 serial bit-steps in one combinational block (MSB-first)
	  for i in 7 downto 0 loop
		 feedback := c(31) xor din_eff(i);
		 c        := c(30 downto 0) & '0';
		 if feedback = '1' then
			c := c xor POLY;
		 end if;
	  end loop;
	else  --
	 c := (others => '0');
	end if ;
  -- output of this combinational logic
  crc_next <= c;
end process;

  ------------------------------------------------------------------
  -- Sequential control + registers
  ------------------------------------------------------------------
  seq : process(clk, reset)
  begin
    if reset = '1' then
      crc_reg   <= (others => '0');
      checking  <= '0';
      in_fcs    <= '0';
      fcs_error <= '0';
      fcs_ok    <= '0';
      head_cnt  <= (others => '0');

    elsif rising_edge(clk) then

      fcs_error <= '0'; -- default
      fcs_ok    <= '0'; -- default
      
      -- Start-of-frame sets control state, but does NOT block processing the bit
      if start_of_frame = '1' then
        checking  <= '1';
        in_fcs    <= '0';
        fcs_error <= '0';
        fcs_ok    <= '0';
        head_cnt  <= (others => '0');
      end if;

      -- Process bytes while stream is active.
      if bit_valid = '1' then
        -- end_of_frame marks data_valid falling edge from parser,
        -- so crc_reg already contains the CRC after the last valid byte.
        if end_of_frame = '1' then
          if crc_reg = x"C704DD7B" then
            fcs_error <= '0';
            fcs_ok <= '1';
          else
            fcs_error <= '1';
            fcs_ok <= '0';
          end if;

          checking <= '0';
          crc_reg  <= (others => '0');
        else
          crc_reg <= crc_next;

          -- count first 32 bits
          if head_cnt < 4 then
            head_cnt <= head_cnt + 1;
          end if;
        end if;
      end if;

    end if;
  end process;

end rtl;