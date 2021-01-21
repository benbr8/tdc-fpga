library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.tdc_pkg.all;

entity channel is
    generic (CH     : string);
    port (
        CLK     : in std_logic;
        CLK_P90 : in std_logic;
        RST     : in std_logic;
        D       : in r_ch_in;
        Q       : out r_ch_out
    );
end entity;


architecture channel_arch of channel is
    attribute mark_debug : string;

    type r_m is record
        dl      : r_dls_in;
        lut     : r_lut_in;
    end record;
    type r_mo is record
        dl      : r_dls_out;
        lut     : r_lut_out;
    end record;
    type r is record
        lut_init    : std_logic;
        valid       : std_logic_vector(3 downto 0);
        lut_data    : unsigned(17 downto 0);
        time        : unsigned(30 downto 0);
        deadtime    : integer range 0 to CALIB_DEADTIME;
    end record;

    signal m    : r_m;
    signal mo   : r_mo;
    signal s    : r;


begin
    process(CLK)
    begin

        if rising_edge(CLK) then
            -- defaults
            m.lut.valid <= '0';
            s.valid     <= (others => '0');
            q.valid     <= '0';

            if RST = '1' then
                q.ready     <= '0';
                s.valid     <= (others => '0');
                s.lut_init  <= '0';
            else
                if mo.lut.init = '1' then
                    q.ready <= '1';
                end if;

                -- Gebe valide Daten in die Berechnungspipeline und and das LUT-Modul
                s.valid <= prop(s.valid);   -- propagiere validpipeline mit jedem takt
                if mo.dl.valid = '1' then
                    s.lut_init   <= mo.lut.init;
                    m.lut.bin   <= mo.dl.bin;
                    m.lut.valid <= '1';
                    m.lut.calib_flag <= mo.dl.calib_flag;

                    -- disgregard calibration
                    if mo.dl.calib_flag = '0' then
                        s.valid(0)  <= '1';
                    end if;
                end if;

                if s.valid(1) = '1' and s.lut_init = '1' then
                    s.lut_data <= mo.lut.data;
                end if;

                -- T = LUT(POS) * CLK_IN_PS / HIST_SIZE
                if s.valid(2) = '1' and s.lut_init = '1' then
                    s.time <= resize(s.lut_data*d.clk_period,31);
                end if;

                if s.valid(3) = '1' and s.lut_init = '1' then
                    q.time  <= resize(shift_right(s.time,log2(HIST_SIZE)),13);
                    q.valid <= '1';
                end if;

            end if;
        end if;
    end process;

    m.dl.sensor     <= d.sensor;
    m.dl.calib_en   <= d.calib_en;
    dl_inst: entity work.dl_sync(dl_sync_arch)
    generic map ( CH => CH )
    port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        RST     => RST,
        D       => m.dl,
        Q       => mo.dl
    );

    -- m.lut.dbg <= d.dbg;
    -- q.dbg.hist_data <= mo.lut.dbg.hist_data;
    -- q.dbg.hist_valid <= mo.lut.dbg.hist_valid;
    lut_inst: entity work.lut(lut_arch)
    generic map ( CH => CH )
    port map (
        CLK     => CLK,
        RST     => RST,
        D       => m.lut,
        Q       => mo.lut
    );
end architecture;
