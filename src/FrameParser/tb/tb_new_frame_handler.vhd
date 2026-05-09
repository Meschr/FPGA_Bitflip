library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_new_frame_handler is
end entity tb_new_frame_handler;

architecture tb of tb_new_frame_handler is

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

    -- Signals for DUT ports
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    
    -- Inputs to frame_handler
    signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal buffer_dest_port : std_logic_vector(3 downto 0) := (others => '0');

    -- Outputs from frame_handler
    signal data_out    : std_logic_vector(7 downto 0);
    signal dst_port    : std_logic_vector(3 downto 0);
    signal crc_valid   : std_logic;
    signal eof_handler : std_logic;
    signal frame_rdy_handler : std_logic;
    signal full_buffer : std_logic_vector(3 downto 0);

begin

    -- ===================================================================
    -- DUT Instantiation
    -- ===================================================================
    u_dut : entity work.frame_handler
    port map (
        clk   => clk,
        reset => reset,
        data_in    => data_in,
        data_valid => data_valid,
        buffer_dest_port => buffer_dest_port,
        data_out    => data_out,
        dst_port    => dst_port,
        crc_valid   => crc_valid,
        eof_handler => eof_handler,
        frame_rdy_handler => frame_rdy_handler,
        full_buffer => full_buffer
    );

    -- ===================================================================
    -- Clock Generator
    -- ===================================================================
    clock_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clock_proc;

    -- ===================================================================
    -- Main Test Process
    -- ===================================================================
    test_proc : process
    begin
        -- Reset the DUT
        reset <= '1';
        wait for 3 * CLK_PERIOD;
        reset <= '0';
        
        wait for 10 * CLK_PERIOD;

        -- TODO: Add test stimuli and assertions here

        wait for 10 * CLK_PERIOD;
        report "Test completed" severity note;
        finish;
    end process test_proc;

end architecture tb;