library ieee;
use ieee.std_logic_1164.all;

entity framehandler_switch is

	port
			(
				clk:			in	std_logic;
				reset:			in	std_logic;

                dest_port_in : in std_logic_vector(3 downto 0); -- Zielport vom frame_handler, wird an die voq weitergegeben
				dest_port_in_flag : in std_logic; -- Flag, das anzeigt, ob dest_port_in gültig ist (z.B. während der Übertragung eines Frames)
				--Activity indicators
				--link_sync:		in	std_logic_vector(3 downto 0);	--High indicates a peer connection at the physical layer. 
				
				--Four GMII interfaces
				tx_data:			out	std_logic_vector(31 downto 0);	--(7 downto 0)=TXD0...(31 downto 24=TXD3)
				tx_ctrl:			out	std_logic_vector(3 downto 0);	--(0)=TXC0...(3=TXC3)

				rx_data:			in	std_logic_vector(31 downto 0);	--(7 downto 0)=RXD0...(31 downto 24=RXD3)
				rx_ctrl:			in	std_logic_vector(3 downto 0)	--(0)=RXC0...(3=RXC3)
			);

end framehandler_switch;

architecture rtl of framehandler_switch is

    signal wr_en_in0   : std_logic_vector(3 downto 0);       
    signal wr_data_in0 : std_logic_vector(7 downto 0);  
    signal wr_eof_in0  : std_logic; 
    

BEGIN

    frame_handler_inst0: entity work.frame_handler
     port map(
        clk   => clk,
        
        reset => reset,
        
        -- inputs
        data_in    => rx_data(7 downto 0),
        data_valid => rx_ctrl(0),
        buffer_dest_port => dest_port_in, -- Zielport vom frame_handler, wird an die voq weitergegeben;
        buffer_dest_port_flag => dest_port_in_flag, -- Flag, das anzeigt, ob dest_port_in gültig ist (z.B. während der Übertragung eines Frames)

        --outputs
        data_out    => wr_data_in0,
        eof_handler => wr_eof_in0,                                     -- for voq
        dst_port    => wr_en_in0,
        crc_valid   =>   open  
    );

    switch: entity work.voq_rr_crossbar_switch_top
        port map(
            clk         => clk,
            reset       => reset,

            flush_out0 => (others => '0'),
            flush_out1 => (others => '0'),
            flush_out2 => (others => '0'),
            flush_out3 => (others => '0'),
    
            -- input from frame_handler
            wr_en_in0   => wr_en_in0,
            wr_data_in0 => wr_data_in0,
            wr_eof_in0  => wr_eof_in0,
    
            -- unused inputs tied off
            wr_en_in1   => (others => '0'),
            wr_data_in1 => (others => '0'),
            wr_eof_in1  => '0',
    
            wr_en_in2   => (others => '0'),
            wr_data_in2 => (others => '0'),
            wr_eof_in2  => '0',
    
            wr_en_in3   => (others => '0'),
            wr_data_in3 => (others => '0'),
            wr_eof_in3  => '0',

            out_data_0  => tx_data(7 downto 0),   -- Ausgabedaten Ausgang 0
            out_data_1  => tx_data(15 downto 8),  -- Ausgabedaten Ausgang 1
            out_data_2  => tx_data(23 downto 16), -- Ausgabedaten Ausgang 2
            out_data_3  => tx_data(31 downto 24), -- Ausgabedaten Ausgang 3

            -- Valid = '1': Ausgabedaten sind gueltig (mind. ein FIFO dieser Queue aktiv)
            out_valid_0  => tx_ctrl(0),
            out_valid_1  => tx_ctrl(1),
            out_valid_2  => tx_ctrl(2),
            out_valid_3  => tx_ctrl(3),

            rr_sel_0    => open,
            rr_sel_1    => open,
            rr_sel_2    => open,
            rr_sel_3    => open,

            rr_grant_0  => open,
            rr_grant_1  => open,
            rr_grant_2  => open,
            rr_grant_3  => open,

            rr_active_0 => open,
            rr_active_1 => open,
            rr_active_2 => open,
            rr_active_3 => open,

            frame_rdy_dbg_0 => open,
            frame_rdy_dbg_1 => open,
            frame_rdy_dbg_2 => open,
            frame_rdy_dbg_3 => open,

            rd_eof_dbg_0 => open,
            rd_eof_dbg_1 => open,
            rd_eof_dbg_2 => open,
            rd_eof_dbg_3 => open,

            full_dbg_0 => open,
            full_dbg_1 => open,
            full_dbg_2 => open,
            full_dbg_3 => open,

            empty_dbg_0 => open,
            empty_dbg_1 => open,
            empty_dbg_2 => open,
            empty_dbg_3 => open
        );


     end architecture rtl;
