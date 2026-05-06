library ieee;
use ieee.std_logic_1164.all;

entity switchcore is

	port
			(
				clk:			in	std_logic;
				reset:			in	std_logic;
				
				--Activity indicators
				link_sync:		in	std_logic_vector(3 downto 0);	--High indicates a peer connection at the physical layer. 
				
				--Four GMII interfaces
				tx_data:			out	std_logic_vector(31 downto 0);	--(7 downto 0)=TXD0...(31 downto 24=TXD3)
				tx_ctrl:			out	std_logic_vector(3 downto 0);	--(0)=TXC0...(3=TXC3)
				rx_data:			in	std_logic_vector(31 downto 0);	--(7 downto 0)=RXD0...(31 downto 24=RXD3)
				rx_ctrl:			in	std_logic_vector(3 downto 0)	--(0)=RXC0...(3=RXC3)
			);

end switchcore;

architecture rtl of switchcore is

	signal handled_frame0, handled_frame1, handled_frame2, handled_frame3 : std_logic_vector(7 downto 0);
	signal dst_mac0, dst_mac1, dst_mac2, dst_mac3                         : std_logic_vector(47 downto 0);
	signal dst_valid0, dst_valid1, dst_valid2, dst_valid3                 : std_logic;
	signal dst_req0, dst_req1, dst_req2, dst_req3                         : std_logic;
	signal dst0, dst1, dst2, dst3                                         : std_logic_vector(3 downto 0);
	signal src_mac0, src_mac1, src_mac2, src_mac3                         : std_logic_vector(47 downto 0);
	signal src_valid0, src_valid1, src_valid2, src_valid3                 : std_logic;
	signal fcs_valid0, fcs_valid1, fcs_valid2, fcs_valid3                 : std_logic;

BEGIN

	frame_handler_inst0: entity work.frame_handler
	 port map(
		clk => clk,
		reset => reset,
		data_in => rx_data(7 downto 0),
		data_valid => rx_ctrl(0),
		data_out => handled_frame0,
		dst_mac => dst_mac0,
		dst_valid => dst_valid0,
		src_mac => src_mac0,
		src_valid => src_valid0,
		crc_valid => fcs_valid0
	);

	frame_handler_inst1: entity work.frame_handler
	 port map(
		clk => clk,
		reset => reset,
		data_in => rx_data(15 downto 8),
		data_valid => rx_ctrl(1),
		data_out => handled_frame1,
		dst_mac => dst_mac1,
		dst_valid => dst_valid1,
		src_mac => src_mac1,
		src_valid => src_valid1,
		crc_valid => fcs_valid1
	);

	frame_handler_inst2: entity work.frame_handler
	 port map(
		clk => clk,
		reset => reset,
		data_in => rx_data(23 downto 16),
		data_valid => rx_ctrl(2),
		data_out => handled_frame2,
		dst_mac => dst_mac2,
		dst_valid => dst_valid2,
		src_mac => src_mac2,
		src_valid => src_valid2,
		crc_valid => fcs_valid2
	);

	frame_handler_inst3: entity work.frame_handler
	 port map(
		clk => clk,
		reset => reset,
		data_in => rx_data(31 downto 24),
		data_valid => rx_ctrl(3),
		data_out => handled_frame3,
		dst_mac => dst_mac3,
		dst_valid => dst_valid3,
		src_mac => src_mac3,
		src_valid => src_valid3,
		crc_valid => fcs_valid3
	);


	mac_table_inst: entity work.mac_table
	 generic map(
		ADDR_WIDTH => 14,
		DATA_WIDTH => 8,
		FORGET_CNT => 16
	)		
	 port map(
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

