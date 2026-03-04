library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs_check_serial_v2 is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic; -- async
    start_of_frame : in  std_logic; -- arrival of first bit
    end_of_frame   : in  std_logic; -- arrival of first FCS bit
    data_in        : in  std_logic; -- serial data
    fcs_error      : out std_logic
  );
end fcs_check_serial_v2;

architecture rtl of fcs_check_serial_v2 is

  constant POLY : std_logic_vector(31 downto 0) := x"04C11DB7";

  signal crc_reg   : std_logic_vector(31 downto 0) := (others => '0');
  signal crc_next  : std_logic_vector(31 downto 0);

  signal checking  : std_logic := '0';
  signal in_fcs    : std_logic := '0';
  signal fcs_cnt   : unsigned(5 downto 0) := (others => '0');
  signal head_cnt  : unsigned(5 downto 0) := (others => '0');

  -- NEW: base crc used for combinational calculation (allows SOF bit to be processed)
  signal crc_base  : std_logic_vector(31 downto 0);

  -- NEW: bit is valid when we're inside a frame OR starting a new one
  signal bit_valid : std_logic;

begin

  bit_valid <= start_of_frame or checking;

  -- When SOF is high, use init value (0) as the "previous CRC" for this bit
  crc_base <= (others => '0') when start_of_frame = '1' else crc_reg;

  ------------------------------------------------------------------
  -- Combinational CRC next-state (1 bit per cycle, MSB-first)
  ------------------------------------------------------------------
  crc_comb : process(crc_base, data_in, head_cnt, end_of_frame, in_fcs)
    variable feedback : std_logic;
    variable shifted  : std_logic_vector(31 downto 0);
    variable tmp      : std_logic_vector(31 downto 0);
    variable din_eff  : std_logic;
  begin
    -- keep your existing inversion policy
    if (head_cnt < 32) then
      din_eff := not data_in;
    elsif (in_fcs = '1') or (end_of_frame = '1') then
      din_eff := not data_in;
    else
      din_eff := data_in;
    end if;

    feedback := crc_base(31) xor din_eff;
    shifted  := crc_base(30 downto 0) & '0';

    if feedback = '1' then
      tmp := shifted xor POLY;
    else
      tmp := shifted;
    end if;

    crc_next <= tmp;
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
      fcs_cnt   <= (others => '0');
      fcs_error <= '0';
      head_cnt  <= (others => '0');

    elsif rising_edge(clk) then

      -- Start-of-frame sets control state, but does NOT block processing the bit
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

        -- count first 32 bits (your rule)
        if head_cnt < 32 then
          head_cnt <= head_cnt + 1;
        end if;

        -- FCS starts NOW (same cycle as first FCS bit)
        if end_of_frame = '1' then
          in_fcs  <= '1';
          fcs_cnt <= to_unsigned(1, fcs_cnt'length);  -- we've just processed FCS bit #0
        end if;

        -- count FCS bits and decide after 32 bits total
        if (in_fcs = '1') or (end_of_frame = '1') then
          if fcs_cnt = 31 then
            -- after processing 32nd FCS bit (bit #31)
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