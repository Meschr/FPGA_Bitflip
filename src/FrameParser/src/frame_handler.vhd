library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--architecture Struktur of TopLevel is
  -- Komponente deklarieren
  --  component Untermodul is
    --    port ( a : in std_logic; b : out std_logic );
    --end component;
    --begin
    --   -- Instanz erzeugen (instanziieren)
   -- instanz_name : Untermodul
     --   port map ( a => signal_a, b => signal_b );
--end architecture;


entity frame_handler is
    port (
        clk   : in std_logic;       -- clk

        reset : in std_logic;       -- reset
        
        -- inputs
        data_in    : in std_logic_vector(7 downto 0);   -- Rx_0 [7:0]
        data_valid : in std_logic;                      -- Rx_0_ctrl
        buffer_dest_port : in std_logic_vector(3 downto 0); -- port_addr [3:0]
        buffer_dest_port_flag : in std_logic;               -- valid


        --outputs
        data_out    : out std_logic_vector(7 downto 0);     -- data_o_0[7:0]
        eof_handler : out std_logic;                        -- eof_handler
        dst_port    : out std_logic_vector(3 downto 0);     -- dst_port [3:0]           
        crc_valid   : out  std_logic;                       -- crc_valid 
        frame_rdy_handler : out std_logic;                  -- wr_en
        -- full_buffer : out std_logic_vector(3 downto 0)      -- xxxxxxxx
              
    );
end entity;

architecture rtl of frame_handler is
    -- output frameparser
    signal sof_int         : std_logic := '0'; -- Start of Frame
    signal eof_int         : std_logic := '0'; -- End of Frame
    signal data_int        : std_logic_vector(7 downto 0);
    signal dst_mac_int     :  std_logic_vector(47 downto 0) := (others => '0');    -- Destination MAC from parser
    signal dst_valid_int   :  std_logic := '0';                                     -- Destination MAC valid pulse
    signal src_mac_int     :  std_logic_vector(47 downto 0) := (others => '0');    -- Source MAC from parser
    signal src_valid_int   :  std_logic := '0';                                     -- Source MAC valid pulse

    -- output fcs_check_parallel    
    signal data_int_crc   : std_logic_vector(7 downto 0);
    signal fcs_ok_int      : std_logic := '0';
    signal fcs_error_int   : std_logic := '0';
    signal bit_valid_int  : std_logic := '0';
    signal eof_int_delayed : std_logic := '0';  -- EOF synchronized with FCS output
    
    
    signal buffer_flush : std_logic := '0';
    
begin

    
    
    -- buffer_flush <= fcs_error_int;
    crc_valid <= fcs_ok_int;

    u_frameparser : entity work.frame_parser
    port map (
        -- inputs
        clk       => clk,
        reset     => reset,
            
        data_in   => data_in,                   -- Rx_0 [7:0]
        data_valid => data_valid,               -- Rx_0_ctrl

        -- outputs
        data_out  => data_int,                  -- data_int [7:0]
        sof       => sof_int,                   -- sof_int
        eof       => eof_int,                   -- eof_int
        dst_mac   => dst_mac_int,               -- dst_mac[47:0]
        dst_valid => dst_valid_int,             -- dst_valid
        src_mac   => src_mac_int,               -- src_mac[47:0]
        src_valid => src_valid_int              -- src_valid
    );
    
    u_fcscheck : entity work.fcs_check_parallel
    port map (
        -- inputs
        clk            => clk,
        reset          => reset,
        start_of_frame => sof_int,
        end_of_frame   => eof_int,
        data_in        => data_int,

        -- outputs
        fcs_error      => fcs_error_int,
        fcs_ok         => fcs_ok_int,
        data_out       => data_int_crc,             -- wr_data [7:0]
        wr_en          => bit_valid_int,            -- wr_en
        eof_out        => eof_int_delayed           -- wr_eof
    );

    u_crc_buffer : entity work.crc_to_voq_buffer
    port map (

        -- inputs
        clk         => clk,
        reset       => reset,
        flush       => buffer_flush,            -- flush

        wr_en       => bit_valid_int,           -- wr_en
        wr_data     => data_int_crc,            -- wr_data [7:0]
        wr_eof      => eof_int_delayed,         -- wr_eof

        dest_port   => buffer_dest_port,        -- port_addr [3:0]
        dest_port_flag => buffer_dest_port_flag,-- valid

        -- outputs
        rd_data     => data_out,        -- data_o_0 [7:0]
        rd_eof      => eof_handler,     -- eof_handler
        rd_en_dest_port  => dst_port,     --dst_port [3:0]
        crc_valid   => crc_valid        -- crc_valid
        --wr_en ?! für voq
    );

end architecture rtl;