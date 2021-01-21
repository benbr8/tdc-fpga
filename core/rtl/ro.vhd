
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity ro is
    generic(
        LENGTH: positive    -- ungerade
    );
    port(
         en     : in std_logic;
         ro_clk : out std_logic
    );
end entity;

architecture ro_arch of ro is
    attribute dont_touch: string;

    signal path : std_logic_vector(LENGTH downto 0);
    attribute dont_touch of path: signal is "True";
begin

    path(0) <= path(LENGTH);
    ro_clk  <= path(LENGTH);

    lut_gen: for i in 0 to LENGTH-1 generate
        lut_0: if i = 0 generate
            cmp_LUT: LUT2
                generic map( INIT => "0100" )
                port map(
                    I0 => path(i),
                    I1 => en,
                    O => path(i+1)
                );
        end generate;
        lut_n: if i > 0 generate
            cmp_LUT: LUT1
                generic map( INIT => "01" )
                port map(
                    I0 => path(i),
                    O => path(i+1)
                );
         end generate;
    end generate;
end architecture;
