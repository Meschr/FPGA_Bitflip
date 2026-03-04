library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs_check_serial_tb_v2 is
end entity fcs_check_serial_tb_v2;

architecture sim of fcs_check_serial_tb_v2 is

    constant CLK_PERIOD : time := 10 ns;

    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal start_of_frame : std_logic := '0';
    signal end_of_frame   : std_logic := '0';
    signal data_in        : std_logic := '0';
    signal fcs_error      : std_logic;

    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

    -- Example Ethernet packet with valid FCS (E6 C5 3D B2)
    constant FRAME : byte_array_t(0 to 63) := (
        x"00", x"10", x"A4", x"7B", x"EA", x"80",  -- Dest MAC
        x"00", x"12", x"34", x"56", x"78", x"90",  -- Src MAC
        x"08", x"00",                                -- EtherType
        x"45", x"00", x"00", x"2E", x"B3", x"FE",  -- IP header
        x"00", x"00", x"80", x"11", x"05", x"40",
        x"C0", x"A8", x"00", x"2C", x"C0", x"A8",
        x"00", x"04",
        x"04", x"00", x"04", x"00", x"00", x"1A",  -- UDP header
        x"2D", x"E8",
        x"00", x"01", x"02", x"03", x"04", x"05",  -- Payload
        x"06", x"07", x"08", x"09", x"0A", x"0B",
        x"0C", x"0D", x"0E", x"0F", x"10", x"11",
        x"E6", x"C5", x"3D", x"B2"                  -- FCS
    );

    constant FCS_START_INDEX : natural := 60;

begin

    dut : entity work.fcs_check_serial_v2
        port map (
            clk            => clk,
            reset          => reset,
            start_of_frame => start_of_frame,
            end_of_frame   => end_of_frame,
            data_in        => data_in,
            fcs_error      => fcs_error
        );

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus
    stim_proc : process

        procedure send_frame(valid_fcs : boolean) is
            variable current_byte : std_logic_vector(7 downto 0);
        begin
            report "------------------------------------------------------------";
            if valid_fcs then
                report "TEST: Sending frame with VALID FCS";
            else
                report "TEST: Sending frame with CORRUPTED FCS";
            end if;
            report "------------------------------------------------------------";

            for byte_idx in FRAME'range loop
                current_byte := FRAME(byte_idx);

                -- Corrupt last byte if testing invalid FCS
                if (not valid_fcs) and (byte_idx = FRAME'high) then
                    current_byte := current_byte xor x"FF";
                end if;

                -- Send bits LSB first (Ethernet bit ordering)
                for bit_idx in 0 to 7 loop
                    data_in <= current_byte(bit_idx);

                    -- Pulse start_of_frame on very first bit
                    if byte_idx = 0 and bit_idx = 0 then
                        start_of_frame <= '1';
                    else
                        start_of_frame <= '0';
                    end if;

                    -- Pulse end_of_frame on first bit of FCS field
                    if byte_idx = FCS_START_INDEX and bit_idx = 0 then
                        end_of_frame <= '1';
                    else
                        end_of_frame <= '0';
                    end if;

                    wait until rising_edge(clk);
                end loop;
            end loop;

            -- De-assert
            start_of_frame <= '0';
            end_of_frame   <= '0';
            data_in        <= '0';

            -- Wait for DUT to evaluate
            wait for CLK_PERIOD * 4;

            -- Check
            if valid_fcs then
                assert fcs_error = '0'
                    report "FAIL: fcs_error asserted on a valid frame!"
                    severity error;
                if fcs_error = '0' then
                    report "PASS: fcs_error = '0' for valid FCS.";
                end if;
            else
                assert fcs_error = '1'
                    report "FAIL: fcs_error NOT asserted on corrupted frame!"
                    severity error;
                if fcs_error = '1' then
                    report "PASS: fcs_error = '1' for corrupted FCS.";
                end if;
            end if;

            wait for CLK_PERIOD * 10;
        end procedure send_frame;

    begin
        -- Reset
        reset <= '1';
        start_of_frame <= '0';
        end_of_frame   <= '0';
        data_in        <= '0';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD * 2;

        -- Test 1: Valid FCS
        send_frame(valid_fcs => true);

        -- Reset between tests
        reset <= '1';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD * 2;

        -- Test 2: Corrupted FCS
        send_frame(valid_fcs => false);

        report "============================================================";
        report "ALL TESTS COMPLETE";
        report "============================================================";
        wait;
    end process;

end architecture sim;