LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY frame_handler IS
    PORT (
        clk : IN STD_LOGIC;

        reset : IN STD_LOGIC;

        -- inputs
        data_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        data_valid : IN STD_LOGIC;
        buffer_dest_port : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        buffer_dest_port_flag : IN STD_LOGIC;
        --outputs
        data_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        eof_handler : OUT STD_LOGIC; -- for voq
        dst_port : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        crc_valid : OUT STD_LOGIC; -- signal for MAC learning to store dst_adr
        frame_rdy : OUT STD_LOGIC; -- frame ready signal
        full_buffer : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- buffer full status per port
        dst_mac : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
        dst_valid : OUT STD_LOGIC;
        src_mac : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
        src_valid : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE rtl OF frame_handler IS
    -- output frameparser
    SIGNAL sof_int : STD_LOGIC := '0'; -- Start of Frame
    SIGNAL eof_int : STD_LOGIC := '0'; -- End of Frame
    SIGNAL data_int : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL dst_mac_int : STD_LOGIC_VECTOR(47 DOWNTO 0) := (OTHERS => '0'); -- Destination MAC from parser
    SIGNAL dst_valid_int : STD_LOGIC := '0'; -- Destination MAC valid pulse
    SIGNAL src_mac_int : STD_LOGIC_VECTOR(47 DOWNTO 0) := (OTHERS => '0'); -- Source MAC from parser
    SIGNAL src_valid_int : STD_LOGIC := '0'; -- Source MAC valid pulse

    -- output fcs_check_parallel    
    SIGNAL data_int_crc : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL fcs_ok_int : STD_LOGIC := '0';
    SIGNAL fcs_error_int : STD_LOGIC := '0';
    SIGNAL bit_valid_int : STD_LOGIC := '0';
    SIGNAL eof_int_delayed : STD_LOGIC := '0'; -- EOF synchronized with FCS output
    SIGNAL buffer_flush : STD_LOGIC := '0';

BEGIN

    -- buffer_flush <= fcs_error_int;
    crc_valid <= fcs_ok_int;

    u_frameparser : ENTITY work.frame_parser
        PORT MAP(
            -- inputs
            clk => clk,
            reset => reset,

            data_in => data_in,
            data_valid => data_valid,

            -- outputs
            data_out => data_int,
            sof => sof_int,
            eof => eof_int,
            dst_mac => dst_mac_int,
            dst_valid => dst_valid_int,
            src_mac => src_mac_int,
            src_valid => src_valid_int
        );

    u_fcscheck : ENTITY work.fcs_check_parallel
        PORT MAP(
            -- inputs
            clk => clk,
            reset => reset,
            start_of_frame => sof_int,
            end_of_frame => eof_int,
            data_in => data_int,

            -- outputs
            fcs_error => fcs_error_int,
            fcs_ok => fcs_ok_int,
            data_out => data_int_crc,
            wr_en => bit_valid_int,
            eof_out => eof_int_delayed
        );

    u_crc_buffer : ENTITY work.crc_to_voq_buffer
        PORT MAP(

            -- inputs
            clk => clk,
            reset => reset,
            flush => buffer_flush,

            wr_en => bit_valid_int,
            wr_data => data_int_crc,
            wr_eof => eof_int_delayed, -- Synchronized EOF from FCS checker

            dest_port => buffer_dest_port,
            dest_port_flag => buffer_dest_port_flag,

            -- outputs
            rd_data => data_out,
            rd_eof => eof_handler, -- pulse when EOF is detected
            rd_en_dest_port => dst_port, -- enable singal for the voq
            crc_valid => crc_valid -- pulse when FCS is correct, used for MAC learning
        );

END ARCHITECTURE rtl;