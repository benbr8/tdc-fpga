-- TAPPED DELAY LINE
-- Instanziiert die TDL. Die Phase wird gemaess PHASE gewaehlt.

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.tdc_pkg.all;


entity delay_line is
    generic(
        PHASE   : string;
        CH      : string
    );
    port (
        CLK     : in std_logic;
        CLK_P90 : in std_logic;
        D       : in r_dl_in;
        Q       : out r_dl_out
    );
end entity;




architecture delay_line_arch of delay_line is

    attribute rloc          : string;
    attribute dont_touch    : string;

    type r is record
        bins_sync   : std_logic_vector(DEPTH*4-1 downto 0);
    end record;
    signal bins         : std_logic_vector(DEPTH*4-1 downto 0);
    signal co0          : std_logic_vector(3 downto 0);
    signal sensor_reg   : std_logic;

    signal s            : r;

    signal clk_pol      : std_logic;
    signal clk_sim      : std_logic := '0';
begin

    -- Waehle Abtasttakt
    pol_0: if PHASE = "0" generate
        clk_pol <= CLK;
    end generate;

    pol_90: if PHASE = "90" generate
        clk_pol <= CLK_P90;
    end generate;

    pol_180: if PHASE = "180" generate
        clk_pol <= not CLK;
    end generate;

    pol_270: if PHASE = "270" generate
        clk_pol <= not CLK_P90;
    end generate;

    -- Ausgabe Daten
    q.bins <= s.bins_sync;

    -- Erstes Carryelement. Wird nicht abgetastet
    carry_0: if (not SIM) generate
        attribute rloc of carry4_inst : label is "X0Y0";
        attribute rloc of fdce_inst : label is "X0Y0";
    begin
        carry4_inst: CARRY4 port map (
            O       => open,
            CO      => co0,
            DI      => "0000",
            S       => "1111",
            CYINIT  => sensor_reg,
            CI      => '0'
        );

        -- Trigger Flipflop mit asynchronem Clear
        fdce_inst: FDCE generic map (
            INIT => '0'
        ) port map (
            D   => '1',
            C   => d.sensor,
            CE  => '1',
            CLR => bins(DEPTH*4-1),
            Q   => sensor_reg
        );
    end generate;

    -- CARRY CHAIN
    carry_logic: for i in 0 to DEPTH-1 generate
        -- Platzierung relativ zu carry_0.carry4_inst
        attribute rloc of dff0 : label is "X0Y"&integer'image(i+1);
        attribute rloc of dff1 : label is "X0Y"&integer'image(i+1);
        attribute rloc of dff2 : label is "X0Y"&integer'image(i+1);
        attribute rloc of dff3 : label is "X0Y"&integer'image(i+1);
    begin
        carry_1: if i = 0 and (not SIM) generate
            attribute dont_touch of carry4_inst : label is "True";
        begin
            carry4_inst: CARRY4 port map (
                O       => open,
                CO      => bins(4*(i+1)-1 downto 4*i),
                DI      => "0000",
                S       => "1111",
                CYINIT  => '0',
                CI      => co0(3)
            );
        end generate;

        carry_n: if i > 0 and (not SIM) generate
            attribute dont_touch of carry4_inst : label is "True";
        begin
            carry4_inst: CARRY4 port map (
                O       => open,
                CO      => bins(4*(i+1)-1 downto 4*i),
                DI      => "0000",
                S       => "1111",
                CYINIT  => '0',
                CI      => bins(4*i-1)
            );
        end generate;

        -- Simuliert TDL
        sim_g: if i = 0 and SIM generate
            clk_sim <= not clk_sim after 7 ps;

            process(clk_sim)
                variable v_bins     : std_logic_vector(DEPTH*4-1 downto 0) := (others => '0');
                variable v_sensor   : std_logic := '0';
                variable cnt        : integer := 0;
                variable offset     : integer := 0;
            begin
                if rising_edge(clk_sim) then
                    if CH = "ch2" then
                        offset := SIM_OFFSET;
                    end if;

                    v_bins := prop(v_bins);
                    v_bins(0) := v_sensor;
                    if cnt = 6000 + offset then
                        v_sensor := not v_sensor;
                        cnt := offset;
                    else
                        cnt := cnt + 1;
                    end if;
                    bins <= v_bins;
                end if;
            end process;
        end generate;

        -- Abtastflipflops
        dff0: FDRE port map (
            Q   => s.bins_sync(4*i),
            C   => clk_pol,
            CE  => '1',
            R   => '0',
            D   => bins(4*i) );
        dff1: FDRE port map (
            Q   => s.bins_sync(4*i+1),
            C   => clk_pol,
            CE  => '1',
            R   => '0',
            D   => bins(4*i+1) );
        dff2: FDRE port map (
            Q   => s.bins_sync(4*i+2),
            C   => clk_pol,
            CE  => '1',
            R   => '0',
            D   => bins(4*i+2) );
        dff3: FDRE port map (
            Q   => s.bins_sync(4*i+3),
            C   => clk_pol,
            CE  => '1',
            R   => '0',
            D   => bins(4*i+3) );

    end generate;

end architecture;
