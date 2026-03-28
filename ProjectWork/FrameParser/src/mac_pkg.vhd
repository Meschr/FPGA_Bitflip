library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mac_pkg is

    -- Standard Ethernet MAC address is 48 bits (6 bytes)
    subtype mac_addr_t is std_logic_vector(47 downto 0);

    -- Define the width of your source/destination port vectors
    -- (Adjust this number if your design uses a different port width, e.g., 4 or 8)
    constant PORT_WIDTH : integer := 8; 

end package mac_pkg;

-- You can optionally include a package body if you plan to add functions/procedures later
package body mac_pkg is
end package body mac_pkg;
