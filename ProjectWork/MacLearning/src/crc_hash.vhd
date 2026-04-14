library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mac_hash is
    port (
        mac_in   : in  std_logic_vector(47 downto 0);
        hash_out : out std_logic_vector(12 downto 0)
    );
end mac_hash;

architecture rtl of mac_hash is
begin
    process(mac_in)
        variable c : std_logic_vector(15 downto 0);
        variable b : std_logic;
    begin
        c := x"FFFF";
        for i in 47 downto 0 loop
            b := mac_in(i) xor c(15);
            c := c(14 downto 0) & '0';
            if b = '1' then
                c := c xor x"8005";
            end if;
        end loop;
        hash_out <= c(12 downto 0);
    end process;
end rtl;