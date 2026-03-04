library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs_check_serial_tb is
end entity fcs_check_serial_tb;

architecture sim of fcs_check_serial_tb is

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

    -- Signals
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal start_of_frame : std_logic := '0';
    signal end_of_frame   : std_logic := '0';
    signal data_in        : std_logic := '0';
    signal fcs_error      : std_logic;

    -- Complete Ethernet frame including FCS (64 bytes)
    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

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
        x"00", x"01", x"02", x"03", x"04", x"05",  -- Payload data
        x"06", x"07", x"08", x"09", x"0A", x"0B",
        x"0C", x"0D", x"0E", x"0F", x"10", x"11",
        x"E6", x"C5", x"3D", x"B2"                  -- FCS
    );

    -- FCS is the last 4 bytes (indices 60..63)
    constant FCS_START_INDEX : natural := 60;

begin

    --------------------------------------------------------------------------
    -- DUT instantiation
    --------------------------------------------------------------------------
    uut : entity work.fcs_check_serial
        port map (
            clk            => clk,
            reset          => reset,
            start_of_frame => start_of_frame,
            end_of_frame   => end_of_frame,
            data_in        => data_in,
            fcs_error      => fcs_error
        );

    --------------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------------
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    --------------------------------------------------------------------------
    -- Stimulus process
    --------------------------------------------------------------------------
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

                -- Corrupt last byte of FCS if invalid test requested
                if (not valid_fcs) and (byte_idx = FRAME'high) then
                    current_byte := current_byte xor x"FF";
                end if;

                -- Send each bit LSB FIRST (Ethernet bit ordering)
                for bit_idx in 0 to 7 loop
                    -- Drive data_in
                    data_in <= current_byte(bit_idx);

                    -- Assert start_of_frame on the very first bit of the frame
                    if byte_idx = 0 and bit_idx = 0 then
                        start_of_frame <= '1';
                    else
                        start_of_frame <= '0';
                    end if;

                    -- Assert end_of_frame on the first bit of the FCS field
                    if byte_idx = FCS_START_INDEX and bit_idx = 0 then
                        end_of_frame <= '1';
                    else
                        end_of_frame <= '0';
                    end if;

                    wait until rising_edge(clk);
                end loop;
            end loop;

            -- De-assert all inputs after the last bit
            start_of_frame <= '0';
            end_of_frame   <= '0';
            data_in        <= '0';

            -- Wait a few cycles for the DUT to settle
            wait for CLK_PERIOD * 4;

            -- Check result
            if valid_fcs then
                assert fcs_error = '0'
                    report "FAIL: fcs_error asserted on a valid frame!"
                    severity error;
                if fcs_error = '0' then
                    report "PASS: fcs_error is '0' for valid FCS frame.";
                end if;
            else
                assert fcs_error = '1'
                    report "FAIL: fcs_error NOT asserted on a corrupted frame!"
                    severity error;
                if fcs_error = '1' then
                    report "PASS: fcs_error is '1' for corrupted FCS frame.";
                end if;
            end if;

            -- Idle gap between frames
            wait for CLK_PERIOD * 10;
        end procedure send_frame;

    begin
        -----------------------------------------------------------------------
        -- Initial reset
        -----------------------------------------------------------------------
        reset          <= '1';
        start_of_frame <= '0';
        end_of_frame   <= '0';
        data_in        <= '0';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD * 2;

        -----------------------------------------------------------------------
        -- Test 1: Valid FCS  (expect fcs_error = '0')
        -----------------------------------------------------------------------
        send_frame(valid_fcs => true);

        -----------------------------------------------------------------------
        -- Reset between tests
        -----------------------------------------------------------------------
        reset <= '1';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD * 2;

        -----------------------------------------------------------------------
        -- Test 2: Corrupted FCS  (expect fcs_error = '1')
        -----------------------------------------------------------------------
        send_frame(valid_fcs => false);

        -----------------------------------------------------------------------
        -- Done
        -----------------------------------------------------------------------
        report "============================================================";
        report "ALL TESTS COMPLETE";
        report "============================================================";
        wait;
    end process;

end architecture sim;