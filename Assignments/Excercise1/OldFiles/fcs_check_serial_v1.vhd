library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs_check_serial_v1 is
    port (
        clk            : in  std_logic;
        reset          : in  std_logic;
        start_of_frame : in  std_logic;
        end_of_frame   : in  std_logic;
        data_in        : in  std_logic;
        fcs_error      : out std_logic
    );
end fcs_check_serial_v1;

architecture rtl of fcs_check_serial_v1 is

    signal crc_reg    : std_logic_vector(31 downto 0) := (others => '1');
    signal feedback   : std_logic;
    signal active     : std_logic := '0';

    -- Counter: counts the 32 FCS bits after end_of_frame
    signal fcs_count  : unsigned(5 downto 0) := (others => '0');
    signal in_fcs     : std_logic := '0';

begin

    feedback <= data_in xor crc_reg(31);

    process(clk, reset)
    begin
        if reset = '1' then
            crc_reg   <= (others => '1');
            active    <= '0';
            in_fcs    <= '0';
            fcs_count <= (others => '0');
            fcs_error <= '0';

        elsif rising_edge(clk) then

            -- Start of frame: initialise CRC register
            if start_of_frame = '1' then
                crc_reg   <= (others => '1');
                active    <= '1';
                in_fcs    <= '0';
                fcs_count <= (others => '0');
                fcs_error <= '0';
            end if;

            -- Serial LFSR: process one bit per clock
            if active = '1' then
                if feedback = '1' then
                    crc_reg <= (crc_reg(30 downto 0) & '0') xor x"04C11DB7";
                else
                    crc_reg <= crc_reg(30 downto 0) & '0';
                end if;
            end if;

            -- end_of_frame pulse: start counting 32 FCS bits
            -- (the LFSR keeps running — we're still active)
            if end_of_frame = '1' then
                in_fcs    <= '1';
                fcs_count <= (others => '0');
            end if;

            -- Count FCS bits while still shifting
            if in_fcs = '1' and active = '1' then
                fcs_count <= fcs_count + 1;

                -- After 32 FCS bits have been clocked in, evaluate
                if fcs_count = to_unsigned(31, 6) then
                    active <= '0';
                    in_fcs <= '0';

                    -- Check the magic residue
                    -- (use the NEXT crc value, i.e. after this cycle's shift)
                    -- But since crc_reg won't update until next delta,
                    -- we do the check on the next cycle instead:
                end if;
            end if;

            -- One cycle after we deactivated: crc_reg holds the final residue
            if active = '0' and in_fcs = '0' and fcs_count = to_unsigned(32, 6) then
                if crc_reg = x"C704DD7B" then
                    fcs_error <= '0';
                else
                    fcs_error <= '1';
                end if;
                fcs_count <= (others => '0');  -- prevent re-triggering
            end if;

        end if;
    end process;

end architecture rtl;