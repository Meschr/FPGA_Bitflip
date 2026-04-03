library ieee;
use ieee.std_logic_1164.all;

entity voq_rr_crossbar_top is
    generic (
        DEPTH : integer := 4096
    );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        flush : in std_logic_vector(3 downto 0);

        -- Schreibseite der 4 VOQs
        wr_data_in0 : in std_logic_vector(7 downto 0);
        wr_en_in0   : in std_logic;
        wr_eof_in0  : in std_logic;

        wr_data_in1 : in std_logic_vector(7 downto 0);
        wr_en_in1   : in std_logic;
        wr_eof_in1  : in std_logic;

        wr_data_in2 : in std_logic_vector(7 downto 0);
        wr_en_in2   : in std_logic;
        wr_eof_in2  : in std_logic;

        wr_data_in3 : in std_logic_vector(7 downto 0);
        wr_en_in3   : in std_logic;
        wr_eof_in3  : in std_logic;

        -- Beobachtbare Ausgänge
        out_data_0  : out std_logic_vector(7 downto 0);
        out_valid   : out std_logic;
        

        rr_sel      : out std_logic_vector(1 downto 0);
        rr_grant    : out std_logic_vector(3 downto 0);
        rr_active   : out std_logic;

        frame_rdy_dbg : out std_logic_vector(3 downto 0);
        rd_eof_dbg    : out std_logic_vector(3 downto 0);
        full_dbg      : out std_logic_vector(3 downto 0);
        empty_dbg     : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of voq_rr_crossbar_top is

    signal rd_en_s      : std_logic_vector(3 downto 0);
    signal rd_data_0_s  : std_logic_vector(7 downto 0);
    signal rd_data_1_s  : std_logic_vector(7 downto 0);
    signal rd_data_2_s  : std_logic_vector(7 downto 0);
    signal rd_data_3_s  : std_logic_vector(7 downto 0);

    signal rd_eof_s     : std_logic_vector(3 downto 0);
    signal frame_rdy_s  : std_logic_vector(3 downto 0);
    signal full_s       : std_logic_vector(3 downto 0);
    signal empty_s      : std_logic_vector(3 downto 0);
    signal rd_valid_all_s : std_logic_vector(3 downto 0);

    signal rr_sel_s     : std_logic_vector(1 downto 0);
    signal rr_grant_s   : std_logic_vector(3 downto 0);
    signal rr_active_s  : std_logic;

    signal eof_mux_s    : std_logic;

    signal out1_dummy   : std_logic_vector(7 downto 0);
    signal out2_dummy   : std_logic_vector(7 downto 0);
    signal out3_dummy   : std_logic_vector(7 downto 0);

begin

    ---------------------------------------------------------------------------
    -- 4er-VOQ für genau einen Output
    ---------------------------------------------------------------------------
    u_voq_4to1 : entity work.voq_4to1
        generic map (
            DEPTH => DEPTH
        )
        port map (
            clk         => clk,
            reset       => reset,
            flush => flush,

            wr_data_in0 => wr_data_in0,
            wr_en_in0   => wr_en_in0,
            wr_eof_in0  => wr_eof_in0,

            wr_data_in1 => wr_data_in1,
            wr_en_in1   => wr_en_in1,
            wr_eof_in1  => wr_eof_in1,

            wr_data_in2 => wr_data_in2,
            wr_en_in2   => wr_en_in2,
            wr_eof_in2  => wr_eof_in2,

            wr_data_in3 => wr_data_in3,
            wr_en_in3   => wr_en_in3,
            wr_eof_in3  => wr_eof_in3,

            rd_en       => rd_en_s,

            rd_data_0   => rd_data_0_s,
            rd_data_1   => rd_data_1_s,
            rd_data_2   => rd_data_2_s,
            rd_data_3   => rd_data_3_s,

            rd_eof      => rd_eof_s,
            frame_rdy   => frame_rdy_s,
            full        => full_s,
            empty       => empty_s,
            rd_valid => out_valid
        );


    

    ---------------------------------------------------------------------------
    -- EOF-MUX für den Round Robin
    -- RR bekommt das EOF der aktuell selektierten FIFO
    ---------------------------------------------------------------------------
    with rr_sel_s select
        eof_mux_s <= rd_eof_s(0) when "00",
                     rd_eof_s(1) when "01",
                     rd_eof_s(2) when "10",
                     rd_eof_s(3) when others;

    ---------------------------------------------------------------------------
    -- Round Robin
    ---------------------------------------------------------------------------
    u_rr : entity work.round_robin
        port map (
            clk       => clk,
            reset     => reset,
            frame_rdy => frame_rdy_s,
            eof       => eof_mux_s,
            sel       => rr_sel_s,
            grant     => rr_grant_s,
            active    => rr_active_s
        );

    -- Direktes Durchreichen: RR-Grant liest die FIFOs
    rd_en_s <= rr_grant_s;

    ---------------------------------------------------------------------------
    -- Crossbar
    -- Es wird nur MUX 0 wirklich benutzt.
    -- MUX 1..3 werden mit Nullen gespeist.
    ---------------------------------------------------------------------------
    u_xbar : entity work.crossbar_switch
        port map (
            clk   => clk,
            reset => reset,

            -- MUX 0 bekommt die 4 FIFO-Daten für Output 0
            data_m0_i0 => rd_data_0_s,
            data_m0_i1 => rd_data_1_s,
            data_m0_i2 => rd_data_2_s,
            data_m0_i3 => rd_data_3_s,

            -- unbenutzt
            data_m1_i0 => (others => '0'),
            data_m1_i1 => (others => '0'),
            data_m1_i2 => (others => '0'),
            data_m1_i3 => (others => '0'),

            data_m2_i0 => (others => '0'),
            data_m2_i1 => (others => '0'),
            data_m2_i2 => (others => '0'),
            data_m2_i3 => (others => '0'),

            data_m3_i0 => (others => '0'),
            data_m3_i1 => (others => '0'),
            data_m3_i2 => (others => '0'),
            data_m3_i3 => (others => '0'),

            -- nur sel_0 kommt vom RR
            sel_0 => rr_sel_s,
            sel_1 => "00",
            sel_2 => "00",
            sel_3 => "00",

            out_data_0 => out_data_0,
            out_data_1 => out1_dummy,
            out_data_2 => out2_dummy,
            out_data_3 => out3_dummy
        );

    ---------------------------------------------------------------------------
    -- Debug-Ausgänge
    ---------------------------------------------------------------------------
    rr_sel        <= rr_sel_s;
    rr_grant      <= rr_grant_s;
    rr_active     <= rr_active_s;

    frame_rdy_dbg <= frame_rdy_s;
    rd_eof_dbg    <= rd_eof_s;
    full_dbg      <= full_s;
    empty_dbg     <= empty_s;

end architecture rtl;