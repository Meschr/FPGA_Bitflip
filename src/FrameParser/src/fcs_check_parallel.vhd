LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fcs_check_parallel IS
  PORT (
    -- inputs
    clk : IN STD_LOGIC;
    reset : IN STD_LOGIC; -- async
    start_of_frame : IN STD_LOGIC; -- arrival of first byte
    end_of_frame : IN STD_LOGIC; -- arrival of last byte
    data_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- outputs
    fcs_error : OUT STD_LOGIC;
    fcs_ok : OUT STD_LOGIC;
    data_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : OUT STD_LOGIC;
    eof_out : OUT STD_LOGIC -- synchronized EOF: high when end_of_frame aligns with data_out
  );
END fcs_check_parallel;

ARCHITECTURE rtl OF fcs_check_parallel IS

  CONSTANT POLY : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"04C11DB7";

  SIGNAL bit_valid : STD_LOGIC;

  SIGNAL crc_reg : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL crc_next : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL checking : STD_LOGIC := '0';
  SIGNAL head_cnt : unsigned(5 DOWNTO 0) := (OTHERS => '0');
BEGIN

  bit_valid <= start_of_frame OR checking;

  ------------------------------------------------------------------
  -- Combinational CRC next-state (8 bits per cycle, MSB-first)
  ------------------------------------------------------------------
  crc_comb : process(all)
    VARIABLE c : STD_LOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE feedback : STD_LOGIC;
    VARIABLE din_eff : STD_LOGIC_VECTOR(7 DOWNTO 0);
  BEGIN

    IF bit_valid = '1' THEN
      -- keep your existing inversion policy
      IF (head_cnt < 4) THEN
        din_eff := NOT data_in;
      ELSE
        din_eff := data_in;
      END IF;

      -- start from current/base CRC value
      c := crc_reg;

      -- apply 8 serial bit-steps in one combinational block (MSB-first)
      FOR i IN 7 DOWNTO 0 LOOP
        feedback := c(31) XOR din_eff(i);
        c := c(30 DOWNTO 0) & '0';
        IF feedback = '1' THEN
          c := c XOR POLY;
        END IF;
      END LOOP;
    ELSE --
      c := (OTHERS => '0');
    END IF;
    -- output of this combinational logic
    crc_next <= c;
  END PROCESS;

  ------------------------------------------------------------------
  -- Sequential control + registers
  ------------------------------------------------------------------
  seq : process(all)
  BEGIN
    IF reset = '0' THEN
      crc_reg <= (OTHERS => '0');
      checking <= '0';
      fcs_error <= '0';
      fcs_ok <= '0';
      head_cnt <= (OTHERS => '0');

    ELSIF rising_edge(clk) THEN

      fcs_error <= '0'; -- default
      fcs_ok <= '0'; -- default
      
      data_out <= data_in; -- passthrough of input data

      -- Start-of-frame sets control state, but does NOT block processing the bit
      IF start_of_frame = '1' THEN
        checking <= '1';
        fcs_error <= '0';
        fcs_ok <= '0';
        head_cnt <= (OTHERS => '0');
      END IF;

      -- Process bytes while stream is active.
      IF bit_valid = '1' THEN
        -- end_of_frame marks data_valid falling edge from parser,
        -- so crc_reg already contains the CRC after the last valid byte.

        wr_en <= not end_of_frame; -- valid data output until end_of_frame
        data_out <= data_in; -- passthrough of input data

        IF end_of_frame = '1' THEN
          IF crc_reg = x"C704DD7B" THEN
            fcs_error <= '0';
            fcs_ok <= '1';
          ELSE
            fcs_error <= '1';
            fcs_ok <= '0';
          END IF;

          checking <= '0';
          head_cnt <= (OTHERS => '0');
          crc_reg <= (OTHERS => '0');
        ELSE
          crc_reg <= crc_next;

          -- count first 32 bits
          IF head_cnt < 4 THEN
            head_cnt <= head_cnt + 1;
          END IF;
        END IF;
      ELSE
        wr_en <= '0';
      END IF;

    END IF;
  END PROCESS;

  -- EOF output synchronized with data_out
  eof_out <= end_of_frame AND bit_valid;

END rtl;