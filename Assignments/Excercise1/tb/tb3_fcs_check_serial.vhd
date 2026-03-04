-- ============================================================
-- Exercise 1 - Task 3: Testbench for fcs_check_serial
-- ============================================================
-- Test 1: Valid packet from exercise (FCS = E6 C5 3D B2)   -> fcs_error = '0'
-- Test 2: Corrupt packet (1 byte changed)                  -> fcs_error = '1'
-- Test 3: Valid packet again after reset                   -> fcs_error = '0'
--
-- IMPORTANT:
--  - Bits are sent MSB-first within each byte (bit 7 downto bit 0).
--  - start_of_frame pulses on the first bit of the whole frame.
--  - end_of_frame pulses on the first bit of the FCS field (start of FCS).
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fcs_check_serial is
end entity;

architecture sim of tb_fcs_check_serial is

  --------------------------------------------------------------------------
  -- DUT component (adapt name/ports to your actual serial checker entity)
  --------------------------------------------------------------------------
  component fcs_check_serial is
    port (
      clk            : in  std_logic;
      reset          : in  std_logic;
      start_of_frame : in  std_logic;
      end_of_frame   : in  std_logic;
      data_in        : in  std_logic;
      fcs_error      : out std_logic
    );
  end component;

  signal clk            : std_logic := '0';
  signal reset          : std_logic := '1';
  signal start_of_frame : std_logic := '0';
  signal end_of_frame   : std_logic := '0';
  signal data_in        : std_logic := '0';
  signal fcs_error      : std_logic;

  constant CLK_PERIOD : time := 8 ns; -- 125 MHz

  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

  -- -------------------------------------------------------
  -- Valid packet from the exercise, FCS = E6 C5 3D B2
  -- Total 64 bytes (60 data + 4 FCS)
  -- -------------------------------------------------------
  constant VALID_PACKET : byte_array_t(0 to 63) := (
    x"00", x"10", x"A4", x"7B", x"EA", x"80",   -- Dst MAC
    x"00", x"12", x"34", x"56", x"78", x"90",   -- Src MAC
    x"08", x"00",                               -- EtherType IPv4
    x"45", x"00", x"00", x"2E", x"B3", x"FE",
    x"00", x"00", x"80", x"11", x"05", x"40",
    x"C0", x"A8", x"00", x"2C", x"C0", x"A8",
    x"00", x"04", x"04", x"00", x"04", x"00",
    x"00", x"1A", x"2D", x"E8", x"00", x"01",
    x"02", x"03", x"04", x"05", x"06", x"07",
    x"08", x"09", x"0A", x"0B", x"0C", x"0D",
    x"0E", x"0F", x"10", x"11",
    x"E6", x"C5", x"3D", x"B2"                  -- FCS (4 bytes)
  );

  -- Corrupt: byte 20 (0x00 -> 0xFF) with original FCS (now wrong)
  constant CORRUPT_PACKET : byte_array_t(0 to 63) := (
    x"AA", x"AA", x"A4", x"7B", x"EA", x"80",
    x"00", x"12", x"34", x"56", x"78", x"90",
    x"08", x"00",
    x"45", x"00", x"00", x"2E", x"B3", x"FE",
    x"FF",  -- << bit error here
    x"00", x"80", x"11", x"05", x"40",
    x"C0", x"A8", x"00", x"2C", x"C0", x"A8",
    x"00", x"04", x"04", x"00", x"04", x"00",
    x"00", x"1A", x"2D", x"E8", x"00", x"01",
    x"02", x"03", x"04", x"05", x"06", x"07",
    x"08", x"09", x"0A", x"0B", x"0C", x"0D",
    x"0E", x"0F", x"10", x"11",
    x"E6", x"C5", x"3D", x"B2"  -- original FCS (now invalid)
  );

  
--------------------------------------------------------------------------
  -- Procedure: send one packet bit by bit, MSB first per byte (bit 7..0).
  -- RULES (per assignment):
  --  - start_of_frame pulses on the SAME clock edge as the FIRST bit of frame.
  --  - end_of_frame pulses on the SAME clock edge as the FIRST bit of the FCS field.
  --------------------------------------------------------------------------
  procedure send_packet (
    signal clk_s : in  std_logic;
    signal sof   : out std_logic;
    signal eof   : out std_logic;
    signal din   : out std_logic;
    packet       : in  byte_array_t
  ) is
    constant total_bits   : integer := packet'length * 8;
    constant fcs_bits     : integer := 32;
    constant first_fcs_bit: integer := total_bits - fcs_bits; -- index of first FCS bit (0-based)
    variable bit_count    : integer := 0; -- 0..total_bits-1
  begin
    -- idle defaults
    sof <= '0';
    eof <= '0';
    din <= '0';

    -- align to clock
    wait until rising_edge(clk_s);

    for byte_idx in packet'range loop
      for bit_idx in 7 downto 0 loop

        -- global bit index from start of frame (0-based)
        bit_count := (byte_idx - packet'low) * 8 + (7 - bit_idx);

        -- drive data for THIS bit BEFORE the sampling edge
        din <= packet(byte_idx)(bit_idx);

        -- SOF asserted exactly with first bit
        if bit_count = 0 then
          sof <= '1';
        else
          sof <= '0';
        end if;

        -- EOF asserted exactly with first FCS bit
        if bit_count = first_fcs_bit then
          eof <= '1';
        else
          eof <= '0';
        end if;

        -- sample at clock edge
        wait until rising_edge(clk_s);

      end loop;
    end loop;

    -- back to idle
    sof <= '0';
    eof <= '0';
    din <= '0';
    wait for CLK_PERIOD * 4;
  end procedure;

begin

  --------------------------------------------------------------------------
  -- DUT instantiation
  --------------------------------------------------------------------------
  DUT : entity work.fcs_check_serial
    port map (
      clk            => clk,
      reset          => reset,
      start_of_frame => start_of_frame,
      end_of_frame   => end_of_frame,
      data_in        => data_in,
      fcs_error      => fcs_error
    );

  -- Clock generation
  clk <= not clk after CLK_PERIOD / 2;

  --------------------------------------------------------------------------
  -- Test sequence
  --------------------------------------------------------------------------
  process
  begin
    -- Reset
    reset <= '1';
    wait for CLK_PERIOD * 4;
    reset <= '0';
    wait for CLK_PERIOD * 2;

    -- ===================================================
    -- TEST 1: Valid packet -> expect fcs_error = '0'
    -- ===================================================
    report "=== TEST 1: Valid Ethernet Packet (FCS = E6 C5 3D B2) ===";
    send_packet(clk, start_of_frame, end_of_frame, data_in, VALID_PACKET);

    wait for CLK_PERIOD * 2; -- allow DUT to latch final decision

    assert fcs_error = '0'
      report "TEST 1 FAILED: fcs_error = '1' on valid packet!"
      severity error;
    if fcs_error = '0' then
      report "TEST 1 PASSED: fcs_error = '0' correct.";
    end if;

    wait for CLK_PERIOD * 8;

    -- ===================================================
    -- TEST 2: Corrupt packet -> expect fcs_error = '1'
    -- ===================================================
    report "=== TEST 2: Corrupted Ethernet Packet ===";
    send_packet(clk, start_of_frame, end_of_frame, data_in, CORRUPT_PACKET);

    wait for CLK_PERIOD * 2;

    assert fcs_error = '1'
      report "TEST 2 FAILED: fcs_error = '0' on corrupt packet!"
      severity error;
    if fcs_error = '1' then
      report "TEST 2 PASSED: fcs_error = '1' correctly detected.";
    end if;

    wait for CLK_PERIOD * 8;

    -- ===================================================
    -- TEST 3: Valid packet after reset
    -- ===================================================
    report "=== TEST 3: Valid Packet After Reset ===";
    reset <= '1';
    wait for CLK_PERIOD * 2;
    reset <= '0';
    wait for CLK_PERIOD * 2;

    send_packet(clk, start_of_frame, end_of_frame, data_in, VALID_PACKET);

    wait for CLK_PERIOD * 2;

    assert fcs_error = '0'
      report "TEST 3 FAILED: fcs_error = '1' after reset + valid packet!"
      severity error;
    if fcs_error = '0' then
      report "TEST 3 PASSED: fcs_error = '0' after reset.";
    end if;

    report "=== ALL TESTS COMPLETE ===";
    wait;
  end process;

end architecture sim;