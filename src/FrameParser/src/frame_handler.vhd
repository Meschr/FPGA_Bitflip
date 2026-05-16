library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_handler is
    port (
        clk   : in STD_LOGIC;
        reset : in STD_LOGIC;

        -- inputs
        data_in               : in STD_LOGIC_VECTOR(7 downto 0);
        data_valid            : in STD_LOGIC;
        buffer_dest_port      : in STD_LOGIC_VECTOR(3 downto 0);
        buffer_dest_port_flag : in STD_LOGIC;
        --outputs
        data_out    : out STD_LOGIC_VECTOR(7 downto 0);
        eof_handler : out STD_LOGIC; -- for voq
        dst_port    : out STD_LOGIC_VECTOR(3 downto 0);
        crc_valid   : out STD_LOGIC; -- signal for MAC learning to store dst_adr
        dst_mac     : inout STD_LOGIC_VECTOR(47 downto 0);
        dst_valid   : out STD_LOGIC;
        src_mac     : inout STD_LOGIC_VECTOR(47 downto 0);
        src_valid   : out STD_LOGIC
    );
end entity;

architecture rtl of frame_handler is
    -- output frameparser
    signal sof_int  : STD_LOGIC := '0'; -- Start of Frame
    signal eof_int  : STD_LOGIC := '0'; -- End of Frame
    signal data_int : STD_LOGIC_VECTOR(7 downto 0);

    -- output fcs_check_parallel    
    signal data_int_crc    : STD_LOGIC_VECTOR(7 downto 0);
    signal fcs_ok_int      : STD_LOGIC := '0';
    signal fcs_error_int   : STD_LOGIC := '0';
    signal bit_valid_int   : STD_LOGIC := '0';
    signal eof_int_delayed : STD_LOGIC := '0'; -- EOF synchronized with FCS output
    signal buffer_flush    : STD_LOGIC := '0';

begin

    -- buffer_flush <= fcs_error_int;
    crc_valid <= fcs_ok_int;

    u_frameparser : entity work.frame_parser
        port map(
            -- inputs
            clk   => clk,
            reset => reset,

            data_in    => data_in,
            data_valid => data_valid,

            -- outputs
            data_out  => data_int,
            sof       => sof_int,
            eof       => eof_int,
            dst_mac   => dst_mac,
            dst_valid => dst_valid,
            src_mac   => src_mac,
            src_valid => src_valid
        );

    u_fcscheck : entity work.fcs_check_parallel
        port map(
            -- inputs
            clk            => clk,
            reset          => reset,
            start_of_frame => sof_int,
            end_of_frame   => eof_int,
            data_in        => data_int,

            -- outputs
            fcs_error => fcs_error_int,
            fcs_ok    => fcs_ok_int,
            data_out  => data_int_crc,
            wr_en     => bit_valid_int,
            eof_out   => eof_int_delayed
        );

    u_crc_buffer : entity work.crc_to_voq_buffer
        port map(

            -- inputs
            clk   => clk,
            reset => reset,
            flush => buffer_flush,

            wr_en   => bit_valid_int,
            wr_data => data_int_crc,
            wr_eof  => eof_int_delayed, -- Synchronized EOF from FCS checker

            dest_port      => buffer_dest_port,
            dest_port_flag => buffer_dest_port_flag,

            -- outputs
            rd_data         => data_out,
            rd_eof          => eof_handler, -- pulse when EOF is detected
            rd_en_dest_port => dst_port,    -- enable singal for the voq
            crc_valid       => fcs_ok_int   -- pulse when FCS is correct, used for MAC learning
        );

end architecture rtl;
