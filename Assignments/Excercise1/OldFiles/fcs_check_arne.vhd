library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity Exercise1_CRC is
	port (
		clk : in std_logic; -- system clock	
		reset : in std_logic; --asynchronous reset	
		start_of_frame : in std_logic; --arrival of the first bit.	
		end_of_frame : in std_logic; --arrival of the first bit in FCS.	
		data_in : in std_logic; -- serialinput data.	
		fcs_error : out std_logic --indicates an error.
	
	);
end Exercise1_CRC;

architecture rtl of Exercise1_CRC is

  -- Ethernet CRC-32 polynomial (non-reflected) without the x^32 term:
  -- 0x04C11DB7 corresponds to x^32 + x^26 + x^23 + ... + 1
  constant POLY : std_logic_vector(31 downto 0) := x"04C11DB7";

  signal crc_reg   : std_logic_vector(31 downto 0) := (others => '1');
  signal crc_next  : std_logic_vector(31 downto 0);

  signal checking  : std_logic := '0'; -- are we currently processing a frame?
  signal in_fcs    : std_logic := '0'; -- are we currently inside FCS field?
  signal fcs_cnt   : unsigned(5 downto 0) := (others => '0'); -- counts 0..31

begin

  ------------------------------------------------------------------
  -- Combinational CRC next-state (1 bit per cycle, MSB-first)
  ------------------------------------------------------------------
  crc_comb : process(crc_reg, data_in)
    variable feedback : std_logic;
    variable shifted  : std_logic_vector(31 downto 0);
    variable tmp      : std_logic_vector(31 downto 0);
  begin
    feedback := crc_reg(31) xor data_in;			-- optimization if MSB+input =1 otherwise shifting
    shifted  := crc_reg(30 downto 0) & '0';		-- shift register to the left add 0 at LSB

    if feedback = '1' then								-- Optimization algorythm --> tmp = crc_next 
      tmp := shifted xor POLY;
    else
      tmp := shifted;									-- if MSB and Input = 0--> just shift all registers without G(x)
    end if;													-- because in this case we don't change values through XOR between Registers

    crc_next <= tmp;
  end process;

  ------------------------------------------------------------------
  -- Sequential control + registers
  ------------------------------------------------------------------
  seq : process(clk, reset)
  begin
    if reset = '1' then
      crc_reg   <= (others => '1');
      checking  <= '0';
      in_fcs    <= '0';
      fcs_cnt   <= (others => '0');
      fcs_error <= '0';

    elsif rising_edge(clk) then

      -- Start a new frame
      if start_of_frame = '1' then
        crc_reg   <= (others => '1');  -- standard Ethernet init
        checking  <= '1';
        in_fcs    <= '0';
        fcs_cnt   <= (others => '0');
        fcs_error <= '0';

      elsif checking = '1' then
        -- Feed current bit into CRC
        crc_reg <= crc_next;

        -- Mark that FCS starts NOW (this cycle's bit is the first FCS bit)
        if end_of_frame = '1' then
          in_fcs  <= '1';
          fcs_cnt <= (others => '0');
        end if;

        -- Count FCS bits and decide after 32 bits
        if in_fcs = '1' or end_of_frame = '1' then
          -- end_of_frame means: current bit is already FCS bit #0
          if fcs_cnt = 31 then
            -- After processing the 32nd FCS bit, crc_next is the "new CRC"
            if unsigned(crc_next) = 0 then
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
