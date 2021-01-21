library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.tdc_pkg.all;

entity dl_sync is
    generic (CH     : string);
    port (
        CLK     : in std_logic;
        CLK_P90 : in std_logic;
        RST     : in std_logic;
        D       : in r_dls_in;
        Q       : out r_dls_out
    );
end entity;

architecture dl_sync_arch of dl_sync is

    type r_m is record
        dl : r_dl_in;
    end record;
    type r_mo is record
        dl0,dl90,dl180,dl270    : r_dl_out;
        pe0,pe90,pe180,pe270    : r_pe_out;
    end record;

    type r is record
        bin         : unsigned(PE_INTBITS-1 downto 0);
        bin270_prev : unsigned(PE_INTBITS-1 downto 0);
        valid       : std_logic;
        calib_en    : std_logic;
    end record;

    signal m    : r_m;
    signal mo   : r_mo;
    signal s    : r;
begin

    process(CLK)
        variable v_deadtime : integer range 0 to CALIB_DEADTIME;
    begin
        if rising_edge(CLK) then
            -- defaults
            s.valid <= '0';
            q.valid <= '0';
            s.bin270_prev <= (others => '1');

            s.calib_en <= d.calib_en;

            if RST = '1' then
                v_deadtime := 0;
            else

                if mo.pe0.valid = '1' and mo.pe0.bin < s.bin270_prev then           -- prevent double booking
                    s.bin           <= resize(mo.pe0.bin,PE_INTBITS) + 3*DEPTH*4;
                    s.valid         <= '1';
                elsif mo.pe90.valid = '1' then
                    s.bin           <= resize(mo.pe90.bin,PE_INTBITS) + 2*DEPTH*4;
                    s.valid         <= '1';
                elsif mo.pe180.valid = '1' then
                    s.bin           <= resize(mo.pe180.bin,PE_INTBITS) + DEPTH*4;
                    s.valid         <= '1';
                elsif mo.pe270.valid = '1' then
                    s.bin           <= resize(mo.pe270.bin,PE_INTBITS);
                    s.valid         <= '1';
                    s.bin270_prev   <= resize(mo.pe270.bin,PE_INTBITS);
                end if;

                -- detektiere Aenderung von calib_en und initialisiere Totzeit
                if s.calib_en /= d.calib_en then
                    v_deadtime := 0;
                end if;

                -- Ausgabe wenn Totzeit nicht aktiv. calib_flag = calib_en nach Totzeit
                if v_deadtime = CALIB_DEADTIME then
                    q.valid         <= s.valid;
                    q.calib_flag    <= s.calib_en;
                else
                    v_deadtime := v_deadtime + 1;
                end if;
            end if;

            q.bin <= s.bin;
        end if;
    end process;



    -- Instanziiere TDLs und Priority Encoder
    m.dl.sensor <= d.sensor;
    dl_0: entity work.delay_line(delay_line_arch)
    generic map (
        PHASE   => "0",
        CH      => CH
    ) port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        D       => m.dl,
        Q       => mo.dl0
    );
    dl_90: entity work.delay_line(delay_line_arch)
    generic map (
        PHASE   => "90",
        CH      => CH
    ) port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        D       => m.dl,
        Q       => mo.dl90
    );
    dl_180: entity work.delay_line(delay_line_arch)
    generic map (
        PHASE   => "180",
        CH      => CH
    ) port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        D       => m.dl,
        Q       => mo.dl180
    );
    dl_270: entity work.delay_line(delay_line_arch)
    generic map (
        PHASE   => "270",
        CH      => CH
    ) port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        D       => m.dl,
        Q       => mo.dl270
    );

    pe_0: entity work.priority_encoder(priority_encoder_arch)
    generic map ( PHASE => "0" )
    port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        RST     => RST,
        D       => mo.dl0,
        Q       => mo.pe0
    );

    pe_90: entity work.priority_encoder(priority_encoder_arch)
    generic map ( PHASE => "90" )
    port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        RST     => RST,
        D       => mo.dl90,
        Q       => mo.pe90
    );

    pe_180: entity work.priority_encoder(priority_encoder_arch)
    generic map ( PHASE => "180" )
    port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        RST     => RST,
        D       => mo.dl180,
        Q       => mo.pe180
    );

    pe_270: entity work.priority_encoder(priority_encoder_arch)
    generic map ( PHASE => "270" )
    port map (
        CLK     => CLK,
        CLK_P90 => CLK_P90,
        RST     => RST,
        D       => mo.dl270,
        Q       => mo.pe270
    );
end architecture;
