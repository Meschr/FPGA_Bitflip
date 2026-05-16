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
	SIGNAL eof_handler0, eof_handler1, eof_handler2, eof_handler3 : STD_LOGIC;
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
			eof_handler => eof_handler0,
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
			buffer_dest_port => dst1,
			buffer_dest_port_flag => dst_valid1,
			eof_handler => eof_handler1,
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
			buffer_dest_port => dst2,
			buffer_dest_port_flag => dst_valid2,
			eof_handler => eof_handler2,
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
			buffer_dest_port => dst3,
			buffer_dest_port_flag => dst_valid3,
			eof_handler => eof_handler3,
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

    switch : ENTITY work.voq_rr_crossbar_switch_top
        PORT MAP(
            clk => clk,
            reset => reset,

            flush_out0 => (OTHERS => '0'),
            flush_out1 => (OTHERS => '0'),
            flush_out2 => (OTHERS => '0'),
            flush_out3 => (OTHERS => '0'),

            -- input from frame_handler0
            wr_en_in0 => dst0,
            wr_data_in0 => handled_frame0,
            wr_eof_in0 => eof_handler0,

            -- unused inputs tied off
            wr_en_in1 => dst1,
            wr_data_in1 => handled_frame1,
            wr_eof_in1 => eof_handler1,

            wr_en_in2 => dst2,
            wr_data_in2 => handled_frame2,
            wr_eof_in2 => eof_handler2,

            wr_en_in3 => dst3,
            wr_data_in3 => handled_frame3,
            wr_eof_in3 => eof_handler3,

            out_data_0 => tx_data(7 DOWNTO 0), -- Ausgabedaten Ausgang 0
            out_data_1 => tx_data(15 DOWNTO 8), -- Ausgabedaten Ausgang 1
            out_data_2 => tx_data(23 DOWNTO 16), -- Ausgabedaten Ausgang 2
            out_data_3 => tx_data(31 DOWNTO 24), -- Ausgabedaten Ausgang 3

            -- Valid = '1': Ausgabedaten sind gueltig (mind. ein FIFO dieser Queue aktiv)
            out_valid_0 => tx_ctrl(0),
            out_valid_1 => tx_ctrl(1),
            out_valid_2 => tx_ctrl(2),
            out_valid_3 => tx_ctrl(3),

            rr_sel_0 => OPEN,
            rr_sel_1 => OPEN,
            rr_sel_2 => OPEN,
            rr_sel_3 => OPEN,

            rr_grant_0 => OPEN,
            rr_grant_1 => OPEN,
            rr_grant_2 => OPEN,
            rr_grant_3 => OPEN,

            rr_active_0 => OPEN,
            rr_active_1 => OPEN,
            rr_active_2 => OPEN,
            rr_active_3 => OPEN,

            frame_rdy_dbg_0 => OPEN,
            frame_rdy_dbg_1 => OPEN,
            frame_rdy_dbg_2 => OPEN,
            frame_rdy_dbg_3 => OPEN,

            rd_eof_dbg_0 => OPEN,
            rd_eof_dbg_1 => OPEN,
            rd_eof_dbg_2 => OPEN,
            rd_eof_dbg_3 => OPEN,

            full_dbg_0 => OPEN,
            full_dbg_1 => OPEN,
            full_dbg_2 => OPEN,
            full_dbg_3 => OPEN,

            empty_dbg_0 => OPEN,
            empty_dbg_1 => OPEN,
            empty_dbg_2 => OPEN,
            empty_dbg_3 => OPEN
        );

END rtl;