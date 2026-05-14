LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY switchcore IS

	PORT (
		clk : IN STD_LOGIC;
		reset : IN STD_LOGIC;

		--Activity indicators
		link_sync : IN STD_LOGIC_VECTOR(3 DOWNTO 0); --High indicates a peer connection at the physical layer. 

		--Four GMII interfaces
		tx_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --(7 downto 0)=TXD0...(31 downto 24=TXD3)
		tx_ctrl : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); --(0)=TXC0...(3=TXC3)
		rx_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --(7 downto 0)=RXD0...(31 downto 24=RXD3)
		rx_ctrl : IN STD_LOGIC_VECTOR(3 DOWNTO 0) --(0)=RXC0...(3=RXC3)
	);

END switchcore;

ARCHITECTURE rtl OF switchcore IS

	SIGNAL handled_frame0, handled_frame1, handled_frame2, handled_frame3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL dst_mac0, dst_mac1, dst_mac2, dst_mac3 : STD_LOGIC_VECTOR(47 DOWNTO 0);
	SIGNAL dst_valid0, dst_valid1, dst_valid2, dst_valid3 : STD_LOGIC;
	SIGNAL dst_req0, dst_req1, dst_req2, dst_req3 : STD_LOGIC;
	SIGNAL dst0, dst1, dst2, dst3 : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL src_mac0, src_mac1, src_mac2, src_mac3 : STD_LOGIC_VECTOR(47 DOWNTO 0);
	SIGNAL src_valid0, src_valid1, src_valid2, src_valid3 : STD_LOGIC;
	SIGNAL fcs_valid0, fcs_valid1, fcs_valid2, fcs_valid3 : STD_LOGIC;

BEGIN

	frame_handler_inst0 : ENTITY work.frame_handler
		PORT MAP(
			clk => clk,
			reset => reset,
			data_in => rx_data(7 DOWNTO 0),
			data_valid => rx_ctrl(0),
			buffer_dest_port => dst0,
			buffer_dest_port_flag => dst_valid0,
			eof_handler => , -- connections not ready yet
			data_out => handled_frame0,
			dst_mac => dst_mac0,
			dst_valid => dst_valid0,
			src_mac => src_mac0,
			src_valid => src_valid0,
			crc_valid => fcs_valid0
		);

	frame_handler_inst1 : ENTITY work.frame_handler
		PORT MAP(
			clk => clk,
			reset => reset,
			data_in => rx_data(15 DOWNTO 8),
			data_valid => rx_ctrl(1),
			data_out => handled_frame1,
			dst_mac => dst_mac1,
			dst_valid => dst_valid1,
			src_mac => src_mac1,
			src_valid => src_valid1,
			crc_valid => fcs_valid1
		);

	frame_handler_inst2 : ENTITY work.frame_handler
		PORT MAP(
			clk => clk,
			reset => reset,
			data_in => rx_data(23 DOWNTO 16),
			data_valid => rx_ctrl(2),
			data_out => handled_frame2,
			dst_mac => dst_mac2,
			dst_valid => dst_valid2,
			src_mac => src_mac2,
			src_valid => src_valid2,
			crc_valid => fcs_valid2
		);

	frame_handler_inst3 : ENTITY work.frame_handler
		PORT MAP(
			clk => clk,
			reset => reset,
			data_in => rx_data(31 DOWNTO 24),
			data_valid => rx_ctrl(3),
			data_out => handled_frame3,
			dst_mac => dst_mac3,
			dst_valid => dst_valid3,
			src_mac => src_mac3,
			src_valid => src_valid3,
			crc_valid => fcs_valid3
		);
	mac_table_inst : ENTITY work.mac_table
		GENERIC MAP(
			ADDR_WIDTH => 14,
			DATA_WIDTH => 8,
			FORGET_CNT => 16
		)
		PORT MAP(
			clk => clk,
			rst => reset,
			src_mac0 => src_mac0,
			src_req0 => src_valid0,
			fcs_valid0 => fcs_valid0,
			src_mac1 => src_mac1,
			src_req1 => src_valid1,
			fcs_valid1 => fcs_valid1,
			src_mac2 => src_mac2,
			src_req2 => src_valid2,
			fcs_valid2 => fcs_valid2,
			src_mac3 => src_mac3,
			src_req3 => src_valid3,
			fcs_valid3 => fcs_valid3,
			dst_mac0 => dst_mac0,
			dst_req0 => dst_req0,
			dst_mac1 => dst_mac1,
			dst_req1 => dst_req1,
			dst_mac2 => dst_mac2,
			dst_req2 => dst_req2,
			dst_mac3 => dst_mac3,
			dst_req3 => dst_req3,
			dst0 => dst0,
			dst_valid0 => dst_valid0,
			dst1 => dst1,
			dst_valid1 => dst_valid1,
			dst2 => dst2,
			dst_valid2 => dst_valid2,
			dst3 => dst3,
			dst_valid3 => dst_valid3
		);
END rtl;