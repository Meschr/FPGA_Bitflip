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
        clk   : in std_logic;
        
        reset : in std_logic;
        
        -- inputs
        data_in    : in std_logic_vector(7 downto 0);
        data_valid : in std_logic;

        --outputs
        data_out    : out std_logic_vector(7 downto 0);
        dst_mac     : out std_logic_vector(47 downto 0);
        dst_valid   : out std_logic;                       -- Destination MAC valid, pulse when dst_mac is valid and can be used for MAC learning
        src_mac     : out std_logic_vector(47 downto 0);
        src_valid   : out std_logic;                        -- Source MAC valid, pulse when src_mac is valid and can be used for MAC learning
        crc_valid   : out std_logic
    );
end entity;

architecture rtl of frame_handler is
    signal sof         : std_logic := '0'; -- Start of Frame
    signal eof         : std_logic := '0'; -- End of Frame
    signal data        : std_logic_vector(7 downto 0);
    signal fcs_ok      : std_logic := '0';
begin

    u_frameparser : entity work.frame_parser
    port map (
        clk       => clk,
        reset     => reset,
            
        data_in   => data_in,
        data_out  => data,
        data_valid => data_valid,           
        sof       => sof,
        eof       => eof,
        dst_mac   => dst_mac,
        dst_valid => dst_valid,
        src_mac   => src_mac,
        src_valid => src_valid
    );
    
    u_fcscheck : entity work.fcs_check_parallel
    port map (
        clk            => clk,
        reset          => reset,
        start_of_frame => sof,
        end_of_frame   => eof,
        data_in        => data,
        fcs_error      => crc_valid,
        fcs_ok         => fcs_ok
    );

    data_out <= data;
end architecture;