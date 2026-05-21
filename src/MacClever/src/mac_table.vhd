library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

entity mac_table is
    generic (
        ADDR_WIDTH : POSITIVE := 13;
        DATA_WIDTH : POSITIVE := 8;
        FORGET_CNT : POSITIVE := 16
    );
    port (
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;

        src_mac0   : in STD_LOGIC_VECTOR(47 downto 0);
        src_req0   : in STD_LOGIC;
        fcs_ok0 : in STD_LOGIC;
        fcs_err0   : in STD_LOGIC;
        src_mac1   : in STD_LOGIC_VECTOR(47 downto 0);
        src_req1   : in STD_LOGIC;
        fcs_ok1 : in STD_LOGIC;
        fcs_err1   : in STD_LOGIC;
        src_mac2   : in STD_LOGIC_VECTOR(47 downto 0);
        src_req2   : in STD_LOGIC;
        fcs_ok2 : in STD_LOGIC;
        fcs_err2   : in STD_LOGIC;
        src_mac3   : in STD_LOGIC_VECTOR(47 downto 0);
        src_req3   : in STD_LOGIC;
        fcs_ok3 : in STD_LOGIC;
        fcs_err3   : in STD_LOGIC;

        dst_mac0 : in STD_LOGIC_VECTOR(47 downto 0);
        dst_req0 : in STD_LOGIC;
        dst_mac1 : in STD_LOGIC_VECTOR(47 downto 0);
        dst_req1 : in STD_LOGIC;
        dst_mac2 : in STD_LOGIC_VECTOR(47 downto 0);
        dst_req2 : in STD_LOGIC;
        dst_mac3 : in STD_LOGIC_VECTOR(47 downto 0);
        dst_req3 : in STD_LOGIC;

        dst0       : out STD_LOGIC_VECTOR(3 downto 0);
        dst_valid0 : out STD_LOGIC;
        dst1       : out STD_LOGIC_VECTOR(3 downto 0);
        dst_valid1 : out STD_LOGIC;
        dst2       : out STD_LOGIC_VECTOR(3 downto 0);
        dst_valid2 : out STD_LOGIC;
        dst3       : out STD_LOGIC_VECTOR(3 downto 0);
        dst_valid3 : out STD_LOGIC
    );
end mac_table;

architecture rtl of mac_table is

    -- Hash outputs and ready signals
    signal src_hash0, src_hash1, src_hash2, src_hash3 : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal src_ready0, src_ready1, src_ready2, src_ready3 : STD_LOGIC;
    signal src_ack0, src_ack1, src_ack2, src_ack3 : STD_LOGIC;
    signal dst_hash0, dst_hash1, dst_hash2, dst_hash3 : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal dst_ready0, dst_ready1, dst_ready2, dst_ready3 : STD_LOGIC;
    signal dst_ack0, dst_ack1, dst_ack2, dst_ack3 : STD_LOGIC;

    -- BRAM signals
    signal bram_addr_a, bram_addr_b : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal bram_data_b : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
    signal bram_q_a, bram_q_b : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
    signal bram_rden_a, bram_rden_b : STD_LOGIC;
    signal bram_wren_b : STD_LOGIC;

    -- mac_read outputs
    signal dest0_sig, dest1_sig, dest2_sig, dest3_sig : STD_LOGIC_VECTOR(3 downto 0);
    signal valid0_sig, valid1_sig, valid2_sig, valid3_sig : STD_LOGIC;

begin

    -- Source MAC Hash instances
    src_hash_0 : entity work.mac_hash
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk      => clk,
            rst      => rst,
            en       => src_req0,
            mac_in   => src_mac0,
            ack      => src_ack0,
            hash_out => src_hash0,
            ready    => src_ready0
        );
    src_hash_1 : entity work.mac_hash
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk      => clk,
            rst      => rst,
            en       => src_req1,
            mac_in   => src_mac1,
            ack      => src_ack1,
            hash_out => src_hash1,
            ready    => src_ready1
        );
    src_hash_2 : entity work.mac_hash
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk      => clk,
            rst      => rst,
            en       => src_req2,
            mac_in   => src_mac2,
            ack      => src_ack2,
            hash_out => src_hash2,
            ready    => src_ready2
        );
    src_hash_3 : entity work.mac_hash
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk      => clk,
            rst      => rst,
            en       => src_req3,
            mac_in   => src_mac3,
            ack      => src_ack3,
            hash_out => src_hash3,
            ready    => src_ready3
        );

    -- Destination MAC Hash instances
    dst_hash_0 : entity work.mac_hash
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk      => clk,
            rst      => rst,
            en       => dst_req0,
            mac_in   => dst_mac0,
            ack      => dst_ack0,
            hash_out => dst_hash0,
            ready    => dst_ready0
        );
    dst_hash_1 : entity work.mac_hash
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk      => clk,
            rst      => rst,
            en       => dst_req1,
            mac_in   => dst_mac1,
            ack      => dst_ack1,
            hash_out => dst_hash1,
            ready    => dst_ready1
        );
    dst_hash_2 : entity work.mac_hash
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk      => clk,
            rst      => rst,
            en       => dst_req2,
            mac_in   => dst_mac2,
            ack      => dst_ack2,
            hash_out => dst_hash2,
            ready    => dst_ready2
        );
    dst_hash_3 : entity work.mac_hash
        generic map(
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk      => clk,
            rst      => rst,
            en       => dst_req3,
            mac_in   => dst_mac3,
            ack      => dst_ack3,
            hash_out => dst_hash3,
            ready    => dst_ready3
        );

    -- BRAM instance (shared by mac_read and mac_write)
    mac_bram : entity work.bram
        generic map(
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            address_a => bram_addr_a,
            address_b => bram_addr_b,
            clock     => clk,
            data_a => (others => '0'),
            data_b    => bram_data_b,
            rden_a    => bram_rden_a,
            rden_b    => bram_rden_b,
            wren_a    => '0',
            wren_b    => bram_wren_b,
            q_a       => bram_q_a,
            q_b       => bram_q_b
        );

    -- mac_read instance (reads from BRAM port A using destination hashes)
    mac_read_inst : entity work.mac_read
        generic map(
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clk    => clk,
            rst    => rst,
            addr0  => dst_hash0,
            req0   => dst_ready0,
            ack0   => dst_ack0,
            addr1  => dst_hash1,
            req1   => dst_ready1,
            ack1   => dst_ack1,
            addr2  => dst_hash2,
            req2   => dst_ready2,
            ack2   => dst_ack2,
            addr3  => dst_hash3,
            req3   => dst_ready3,
            ack3   => dst_ack3,
            dest0  => dest0_sig,
            valid0 => valid0_sig,
            dest1  => dest1_sig,
            valid1 => valid1_sig,
            dest2  => dest2_sig,
            valid2 => valid2_sig,
            dest3  => dest3_sig,
            valid3 => valid3_sig,
            rdata  => bram_q_a,
            raddr  => bram_addr_a,
            ren    => bram_rden_a
        );

    -- Connect mac_read outputs to entity outputs
    dst0 <= dest0_sig;
    dst1 <= dest1_sig;
    dst2 <= dest2_sig;
    dst3 <= dest3_sig;
    dst_valid0 <= valid0_sig;
    dst_valid1 <= valid1_sig;
    dst_valid2 <= valid2_sig;
    dst_valid3 <= valid3_sig;

    -- mac_write instance (writes to BRAM port B using source hashes)
    mac_write_inst : entity work.mac_write
        generic map(
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH,
            FORGET_CNT => FORGET_CNT
        )
        port map(
            clk      => clk,
            rst      => rst,
            addr0    => src_hash0,
            req0     => src_ready0,
            fcs_ok0  => fcs_ok0,
            fcs_err0 => fcs_err0,
            ack0     => src_ack0,
            addr1    => src_hash1,
            req1     => src_ready1,
            fcs_ok1  => fcs_ok1,
            fcs_err1 => fcs_err1,
            ack1     => src_ack1,
            addr2    => src_hash2,
            req2     => src_ready2,
            fcs_ok2  => fcs_ok2,
            fcs_err2 => fcs_err2,
            ack2     => src_ack2,
            addr3    => src_hash3,
            req3     => src_ready3,
            fcs_ok3  => fcs_ok3,
            fcs_err3 => fcs_err3,
            ack3     => src_ack3,
            addr     => bram_addr_b,
            wen      => bram_wren_b,
            wdata    => bram_data_b,
            ren      => bram_rden_b,
            rdata    => bram_q_b
        );
end rtl;
