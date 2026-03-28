library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mac_pkg.all;

entity tb_frame_parser is
end entity tb_frame_parser;

architecture sim of tb_frame_parser is

  -- -------------------------------------------------------
  -- DUT Signale
  -- -------------------------------------------------------
  signal clk        : std_logic := '0';
  signal rst        : std_logic := '1';
  signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid : std_logic := '0';
  signal sof        : std_logic := '0';
  signal src_port   : std_logic_vector(PORT_WIDTH-1 downto 0) := (others => '0');
  signal dst_mac    : mac_addr_t;
  signal src_mac    : mac_addr_t;
  signal port_out   : std_logic_vector(PORT_WIDTH-1 downto 0);
  signal mac_valid  : std_logic;

  -- -------------------------------------------------------
  -- Takt: 10 ns Periode = 100 MHz
  -- -------------------------------------------------------
  constant CLK_PERIOD : time := 10 ns;

  -- -------------------------------------------------------
  -- Testframe: dst=AA:BB:CC:DD:EE:FF  src=11:22:33:44:55:66
  -- -------------------------------------------------------
  type byte_array_t is array(natural range <>) of std_logic_vector(7 downto 0);

  constant FRAME : byte_array_t(0 to 11) := (
    x"AA", x"BB", x"CC", x"DD", x"EE", x"FF",  -- dst MAC
    x"11", x"22", x"33", x"44", x"55", x"66"   -- src MAC
  );

  constant EXP_DST : mac_addr_t := x"AABBCCDDEEFF";
  constant EXP_SRC : mac_addr_t := x"112233445566";

  -- -------------------------------------------------------
  -- Hilfsprozedur: Byte senden
  -- -------------------------------------------------------
  procedure send_byte (
    signal clk   : in  std_logic;
    signal dout  : out std_logic_vector(7 downto 0);
    signal dv    : out std_logic;
    constant val : in  std_logic_vector(7 downto 0)
  ) is
  begin
    dout <= val;
    dv   <= '1';
    wait until rising_edge(clk);
    dv   <= '0';
  end procedure;

begin

  -- -------------------------------------------------------
  -- DUT Instanz
  -- -------------------------------------------------------
  DUT : entity work.frame_parser
    port map (
      clk        => clk,
      rst        => rst,
      data_in    => data_in,
      data_valid => data_valid,
      sof        => sof,
      src_port   => src_port,
      dst_mac    => dst_mac,
      src_mac    => src_mac,
      port_out   => port_out,
      mac_valid  => mac_valid
    );

  -- -------------------------------------------------------
  -- Taktezeugung
  -- -------------------------------------------------------
  p_clk : process
  begin
    clk <= '0'; wait for CLK_PERIOD / 2;
    clk <= '1'; wait for CLK_PERIOD / 2;
  end process;

  -- -------------------------------------------------------
  -- Stimuli
  -- -------------------------------------------------------
  p_stim : process
  begin
    -- Reset halten
    rst      <= '1';
    src_port <= "010";  -- Eingangsport 2
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    rst <= '0';
    wait for CLK_PERIOD;

    -- -------------------------------------------------------
    -- Test 1: normaler Frame ohne Lücken
    -- -------------------------------------------------------
    report "=== Test 1: Frame ohne Lücken ===";

    -- SOF-Puls
    sof <= '1';
    wait until rising_edge(clk);
    sof <= '0';

    -- 12 Bytes des Frames senden
    for i in FRAME'range loop
      send_byte(clk, data_in, data_valid, FRAME(i));
      wait for CLK_PERIOD;
    end loop;

    -- Warten bis mac_valid erscheint (max 5 Takte)
    for i in 0 to 4 loop
      wait until rising_edge(clk);
      if mac_valid = '1' then
        -- Ergebnisse prüfen
        assert dst_mac = EXP_DST
          report "FEHLER dst_mac: got " & to_hstring(dst_mac) &
                 " erwartet " & to_hstring(EXP_DST)
          severity error;

        assert src_mac = EXP_SRC
          report "FEHLER src_mac: got " & to_hstring(src_mac) &
                 " erwartet " & to_hstring(EXP_SRC)
          severity error;

        assert port_out = "010"
          report "FEHLER port_out"
          severity error;

        report "Test 1 BESTANDEN: dst=" & to_hstring(dst_mac) &
               "  src=" & to_hstring(src_mac);
        exit;
      end if;
      if i = 4 then
        report "FEHLER: mac_valid nie gesetzt (Test 1)" severity error;
      end if;
    end loop;

    wait for 3 * CLK_PERIOD;

    -- -------------------------------------------------------
    -- Test 2: Frame mit Taktlücken (data_valid = 0 dazwischen)
    -- -------------------------------------------------------
    report "=== Test 2: Frame mit Lücken ===";

    sof <= '1';
    wait until rising_edge(clk);
    sof <= '0';

    for i in FRAME'range loop
      send_byte(clk, data_in, data_valid, FRAME(i));
      -- nach jedem 2. Byte eine Pause einfügen
      if i mod 2 = 1 then
        wait for 2 * CLK_PERIOD;
      else
        wait for CLK_PERIOD;
      end if;
    end loop;

    for i in 0 to 9 loop
      wait until rising_edge(clk);
      if mac_valid = '1' then
        assert dst_mac = EXP_DST
          report "FEHLER dst_mac (Test 2)" severity error;
        assert src_mac = EXP_SRC
          report "FEHLER src_mac (Test 2)" severity error;
        report "Test 2 BESTANDEN (mit Lücken)";
        exit;
      end if;
    end loop;

    wait for 3 * CLK_PERIOD;

    -- -------------------------------------------------------
    -- Test 3: Reset mitten im Frame
    -- -------------------------------------------------------
    report "=== Test 3: Reset während Empfang ===";

    sof <= '1';
    wait until rising_edge(clk);
    sof <= '0';

    -- nur 4 Bytes senden, dann Reset
    for i in 0 to 3 loop
      send_byte(clk, data_in, data_valid, FRAME(i));
      wait for CLK_PERIOD;
    end loop;

    rst <= '1';
    wait for 2 * CLK_PERIOD;
    rst <= '0';
    wait for CLK_PERIOD;

    -- Nach Reset: vollständigen Frame senden
    sof <= '1';
    wait until rising_edge(clk);
    sof <= '0';

    for i in FRAME'range loop
      send_byte(clk, data_in, data_valid, FRAME(i));
      wait for CLK_PERIOD;
    end loop;

    for i in 0 to 4 loop
      wait until rising_edge(clk);
      if mac_valid = '1' then
        assert dst_mac = EXP_DST
          report "FEHLER dst_mac (Test 3)" severity error;
        assert src_mac = EXP_SRC
          report "FEHLER src_mac (Test 3)" severity error;
        report "Test 3 BESTANDEN (Reset-Recovery)";
        exit;
      end if;
    end loop;

    wait for 5 * CLK_PERIOD;
    report "=== Alle Tests abgeschlossen ===" severity note;
    std.env.stop;
  end process;

end architecture sim;
