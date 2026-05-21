library ieee;
use ieee.std_logic_1164.all;

entity framehandler_switch is

    port (
        clk   : in STD_LOGIC;
        reset : in STD_LOGIC;

        dest_port_in      : in STD_LOGIC_VECTOR(3 downto 0); -- Destination port from frame_handler, forwarded to VOQ
        dest_port_in_flag : in STD_LOGIC;                    -- Flag indicating `dest_port_in` is valid

        tx_data : out STD_LOGIC_VECTOR(31 downto 0); -- Packed 4x8-bit TX lanes (port0..port3)
        tx_ctrl : out STD_LOGIC_VECTOR(3 downto 0);  -- TX valid per port

        rx_data : in STD_LOGIC_VECTOR(31 downto 0);  -- Packed 4x8-bit RX lanes (port0..port3)
        rx_ctrl : in STD_LOGIC_VECTOR(3 downto 0)    -- RX valid per port
    );

end framehandler_switch;

architecture rtl of framehandler_switch is

    signal wr_en_in0   : STD_LOGIC_VECTOR(3 downto 0);
    signal wr_data_in0 : STD_LOGIC_VECTOR(7 downto 0);
    signal wr_eof_in0  : STD_LOGIC;
    signal fcs_error0  : STD_LOGIC;
begin

    frame_handler_inst0 : entity work.frame_handler
        port map(
            clk   => clk,
            reset => reset,

            -- inputs
            data_in               => rx_data(7 downto 0),
            data_valid            => rx_ctrl(0),
            buffer_dest_port      => dest_port_in,      -- Destination port from frame_handler, forwarded to VOQ
            buffer_dest_port_flag => dest_port_in_flag, -- Flag indicating `dest_port_in` is valid (e.g. during frame transmission)

            --outputs
            data_out    => wr_data_in0,
            eof_handler => wr_eof_in0, -- EOF forwarded to VOQ
            dst_port    => wr_en_in0,
            crc_valid   => open,
            fcs_error   => fcs_error0
        );

    switch : entity work.voq_rr_crossbar_switch_top
        port map(
            clk   => clk,
            reset => reset,

            flush_out0 => (others => '0'),
            flush_out1 => (others => '0'),
            flush_out2 => (others => '0'),
            flush_out3 => (others => '0'),

            -- input from frame_handler
            wr_en_in0    => wr_en_in0,
            wr_data_in0  => wr_data_in0,
            wr_eof_in0   => wr_eof_in0,
            wr_abort_in0 => fcs_error0,

            -- unused inputs tied off
            wr_en_in1 => (others => '0'),
            wr_data_in1 => (others => '0'),
            wr_eof_in1   => '0',
            wr_abort_in1 => '0',

            wr_en_in2 => (others => '0'),
            wr_data_in2 => (others => '0'),
            wr_eof_in2   => '0',
            wr_abort_in2 => '0',

            wr_en_in3 => (others => '0'),
            wr_data_in3 => (others => '0'),
            wr_eof_in3   => '0',
            wr_abort_in3 => '0',

            out_data_0 => tx_data(7 downto 0),
            out_data_1 => tx_data(15 downto 8),
            out_data_2 => tx_data(23 downto 16),
            out_data_3 => tx_data(31 downto 24),

            -- Output valid signals per port
            out_valid_0 => tx_ctrl(0),
            out_valid_1 => tx_ctrl(1),
            out_valid_2 => tx_ctrl(2),
            out_valid_3 => tx_ctrl(3)
        );
end architecture rtl;
