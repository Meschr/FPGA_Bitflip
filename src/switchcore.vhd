library ieee;
use ieee.std_logic_1164.all;

entity switchcore is

	port (
		clk   : in STD_LOGIC;
		reset : in STD_LOGIC;

		--Activity indicators
		link_sync : in STD_LOGIC_VECTOR(3 downto 0); --High indicates a peer connection at the physical layer. 

		--Four GMII interfaces
		tx_data : out STD_LOGIC_VECTOR(31 downto 0); --(7 downto 0)=TXD0...(31 downto 24=TXD3)
		tx_ctrl : out STD_LOGIC_VECTOR(3 downto 0);  --(0)=TXC0...(3=TXC3)
		rx_data : in STD_LOGIC_VECTOR(31 downto 0);  --(7 downto 0)=RXD0...(31 downto 24=RXD3)
		rx_ctrl : in STD_LOGIC_VECTOR(3 downto 0)    --(0)=RXC0...(3=RXC3)
	);

end switchcore;

architecture rtl of switchcore is

	signal handled_frame0, handled_frame1, handled_frame2, handled_frame3 : STD_LOGIC_VECTOR(7 downto 0);
	signal eof_handler0, eof_handler1, eof_handler2, eof_handler3 : STD_LOGIC;
	signal dst_mac0, dst_mac1, dst_mac2, dst_mac3 : STD_LOGIC_VECTOR(47 downto 0);
	signal dst_valid0, dst_valid1, dst_valid2, dst_valid3 : STD_LOGIC;
	signal dst_req0, dst_req1, dst_req2, dst_req3 : STD_LOGIC;
	signal dst0, dst1, dst2, dst3 : STD_LOGIC_VECTOR(3 downto 0);
	signal src_mac0, src_mac1, src_mac2, src_mac3 : STD_LOGIC_VECTOR(47 downto 0);
	signal src_valid0, src_valid1, src_valid2, src_valid3 : STD_LOGIC;
	signal fcs_valid0, fcs_valid1, fcs_valid2, fcs_valid3 : STD_LOGIC;
	signal fcs_error0, fcs_error1, fcs_error2, fcs_error3 : STD_LOGIC;
	signal dst_port0, dst_port1, dst_port2, dst_port3 : STD_LOGIC_VECTOR(3 downto 0);

begin

	frame_handler_inst0 : entity work.frame_handler
		port map(
			clk                   => clk,
			reset                 => reset,
			data_in               => rx_data(7 downto 0),
			data_valid            => rx_ctrl(0),
			buffer_dest_port      => dst0,
			buffer_dest_port_flag => dst_valid0,
			eof_handler           => eof_handler0,
			data_out              => handled_frame0,
			dst_mac               => dst_mac0,
			dst_valid             => dst_req0,
			src_mac               => src_mac0,
			src_valid             => src_valid0,
			crc_valid             => fcs_valid0,
			fcs_error             => fcs_error0,
			dst_port              => dst_port0
		);

	frame_handler_inst1 : entity work.frame_handler
		port map(
			clk                   => clk,
			reset                 => reset,
			data_in               => rx_data(15 downto 8),
			data_valid            => rx_ctrl(1),
			buffer_dest_port      => dst1,
			buffer_dest_port_flag => dst_valid1,
			eof_handler           => eof_handler1,
			data_out              => handled_frame1,
			dst_mac               => dst_mac1,
			dst_valid             => dst_req1,
			src_mac               => src_mac1,
			src_valid             => src_valid1,
			crc_valid             => fcs_valid1,
			fcs_error             => fcs_error1,
			dst_port              => dst_port1
		);

	frame_handler_inst2 : entity work.frame_handler
		port map(
			clk                   => clk,
			reset                 => reset,
			data_in               => rx_data(23 downto 16),
			data_valid            => rx_ctrl(2),
			buffer_dest_port      => dst2,
			buffer_dest_port_flag => dst_valid2,
			eof_handler           => eof_handler2,
			data_out              => handled_frame2,
			dst_mac               => dst_mac2,
			dst_valid             => dst_req2,
			src_mac               => src_mac2,
			src_valid             => src_valid2,
			crc_valid             => fcs_valid2,
			fcs_error             => fcs_error2,
			dst_port              => dst_port2
		);

	frame_handler_inst3 : entity work.frame_handler
		port map(
			clk                   => clk,
			reset                 => reset,
			data_in               => rx_data(31 downto 24),
			data_valid            => rx_ctrl(3),
			buffer_dest_port      => dst3,
			buffer_dest_port_flag => dst_valid3,
			eof_handler           => eof_handler3,
			data_out              => handled_frame3,
			dst_mac               => dst_mac3,
			dst_valid             => dst_req3,
			src_mac               => src_mac3,
			src_valid             => src_valid3,
			crc_valid             => fcs_valid3,
			fcs_error             => fcs_error3,
			dst_port              => dst_port3
		);

	mac_table_inst : entity work.mac_table
		generic map(
			ADDR_WIDTH => 14,
			DATA_WIDTH => 8,
			FORGET_CNT => 16
		)
		port map(
			clk        => clk,
			rst        => reset,
			src_mac0   => src_mac0,
			src_req0   => src_valid0,
			fcs_valid0 => fcs_valid0,
			src_mac1   => src_mac1,
			src_req1   => src_valid1,
			fcs_valid1 => fcs_valid1,
			src_mac2   => src_mac2,
			src_req2   => src_valid2,
			fcs_valid2 => fcs_valid2,
			src_mac3   => src_mac3,
			src_req3   => src_valid3,
			fcs_valid3 => fcs_valid3,
			dst_mac0   => dst_mac0,
			dst_req0   => dst_req0,
			dst_mac1   => dst_mac1,
			dst_req1   => dst_req1,
			dst_mac2   => dst_mac2,
			dst_req2   => dst_req2,
			dst_mac3   => dst_mac3,
			dst_req3   => dst_req3,
			dst0       => dst0,
			dst_valid0 => dst_valid0,
			dst1       => dst1,
			dst_valid1 => dst_valid1,
			dst2       => dst2,
			dst_valid2 => dst_valid2,
			dst3       => dst3,
			dst_valid3 => dst_valid3
		);

	switch : entity work.voq_rr_crossbar_switch_top
		port map(
			clk   => clk,
			reset => reset,

			flush_out0 => (others => '0'),
			flush_out1 => (others => '0'),
			flush_out2 => (others => '0'),
			flush_out3 => (others => '0'),

			wr_en_in0    => dst_port0,
			wr_data_in0  => handled_frame0,
			wr_eof_in0   => eof_handler0,
			wr_abort_in0 => fcs_error0,

			wr_en_in1    => dst_port1,
			wr_data_in1  => handled_frame1,
			wr_eof_in1   => eof_handler1,
			wr_abort_in1 => fcs_error1,

			wr_en_in2    => dst_port2,
			wr_data_in2  => handled_frame2,
			wr_eof_in2   => eof_handler2,
			wr_abort_in2 => fcs_error2,

			wr_en_in3    => dst_port3,
			wr_data_in3  => handled_frame3,
			wr_eof_in3   => eof_handler3,
			wr_abort_in3 => fcs_error3,

			out_data_0 => tx_data(7 downto 0),  
			out_data_1 => tx_data(15 downto 8),  
			out_data_2 => tx_data(23 downto 16), 
			out_data_3 => tx_data(31 downto 24), 

			out_valid_0 => tx_ctrl(0),
			out_valid_1 => tx_ctrl(1),
			out_valid_2 => tx_ctrl(2),
			out_valid_3 => tx_ctrl(3)

		);

end rtl;
