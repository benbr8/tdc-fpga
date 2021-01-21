library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.tdc_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity tdc is
    port (
        CLK     : in std_logic;
        CLK_P90 : in std_logic;
        RST     : in std_logic;

        START       : in std_logic;
        STOP        : in std_logic;
        CALIB_EN    : in std_logic;
        READY       : out std_logic;

        TIME        : out std_logic_vector(30 downto 0);
        VALID       : out std_logic;
        ID          : out std_logic;

        PERIOD      : in unsigned(12 downto 0);
        PERIOD_VALID: in std_logic

        -- dbg_up      : out r_dbg_up;
        -- dbg_down    : in r_dbg_down
    );
end entity;

architecture tdc_arch of tdc is
    type r_mo is record
        ch1,ch2     : r_ch_out;
    end record;
    type r_m is record
        ch1,ch2     : r_ch_in;
    end record;
    type r_ch1_data is record
        time        : unsigned(12 downto 0);
    end record;
    type r_ch2_data is record
        time        : unsigned(12 downto 0);
        ccnt        : unsigned(9 downto 0);
    end record;
    type r is record
        id              : std_logic_vector(1 downto 0);
        ch1             : r_ch1_data;
        ch2             : r_ch2_data;
        t_coarse        : signed(30 downto 0);
        t_fine          : signed(13 downto 0);
        valid           : std_logic_vector(1 downto 0);
        ready           : std_logic;
        clk_period      : unsigned(12 downto 0);
    end record;

    signal m        : r_m;
    signal mo       : r_mo;
    signal s        : r;
    signal calib_cond : std_logic;
    signal start_mux : std_logic;
    signal start_bufr : std_logic;
    signal stop_mux  : std_logic;
    signal stop_bufr : std_logic;
    signal ro_en    : std_logic;
    signal ro_clk   : std_logic;
begin

    READY   <= s.ready;

    process(CLK)
        variable v_id : std_logic;
        variable v_ccnt : unsigned(9 downto 0);
    begin
        if rising_edge(CLK) then
            -- defaults
            s.valid     <= (others => '0');
            VALID     <= '0';

            if rst = '1' then
                s.ready <= '0';
                v_id    := '0';
                s.clk_period <= to_unsigned(CLK_IN_PS,13);
            else
                -- manage clock PERIOD
                if PERIOD_VALID = '1' then
                    s.clk_period <= PERIOD;
                end if;

                -- manage channels and measurements
                if mo.ch1.ready = '1' and mo.ch2.ready = '1' then
                    s.ready <= '1';
                else
                    s.ready <= '0';
                end if;

                s.valid <= prop(s.valid);
                s.id    <= prop(s.id);
                v_ccnt  := v_ccnt+1;

                -- capture start signal
                if mo.ch1.valid = '1' then
                    s.ch1.time  <= mo.ch1.time;
                    v_ccnt      := (others => '0');
                    v_id        := not v_id;
                end if;

                -- capture stop signal
                if mo.ch2.valid = '1' then
                    s.ch2.time  <= mo.ch2.time;
                    s.ch2.ccnt  <= v_ccnt;
                    s.id(0)     <= v_id;
                    s.valid(0)  <= '1';
                end if;

                -- calculate time in two steps
                if s.valid(0) = '1' then
                    s.t_coarse  <= resize(utos(s.ch2.ccnt) * utos(s.clk_period),31);
                    s.t_fine    <= resize(utos(s.ch1.time) - utos(s.ch2.time),14);
                end if;
                if s.valid(1) = '1' then
                    TIME  <= std_logic_vector(resize(s.t_coarse + s.t_fine,31));
                    VALID <= '1';
                    ID    <= s.id(1);
                end if;

            end if;
        end if;
    end process;


    -- bedingtes Weitergeben von calib_en. '1' wenn erste LUT-Kalibrierung nicht abgeschlossen
    calib_cond <= CALIB_EN when s.ready = '1' else '1';

    m.ch1.sensor    <= start_mux;
    m.ch1.calib_en  <= calib_cond;
    m.ch1.clk_period    <= s.clk_period;
    -- m.ch1.dbg       <= dbg_down;
    -- dbg_up          <= mo.ch1.dbg;
    channel1: entity work.channel(channel_arch)
    generic map ( CH => "ch1" )
    port map (
        CLK         => CLK,
        CLK_P90     => CLK_P90,
        RST         => rst,
        D           => m.ch1,
        Q           => mo.ch1
    );

    m.ch2.sensor    <= stop_mux;
    m.ch2.calib_en  <= calib_cond;
    m.ch2.clk_period    <= s.clk_period;
    channel2: entity work.channel(channel_arch)
    generic map ( CH => "ch2" )
    port map (
        CLK         => CLK,
        CLK_P90     => CLK_P90,
        RST         => rst,
        D           => m.ch2,
        Q           => mo.ch2
    );

    ro_en <= not RST;
    ro: entity work.ro(ro_arch)
    generic map ( LENGTH => RO_LENGTH )
    port map (
        en      => ro_en,
        ro_clk   => ro_clk
    );

    -- Multiplexer zum Umschalten zwischen Mess- und Kalibrierungssignal
    -- start_mux <= START when calib_cond = '0' else ro_clk;
    -- stop_mux <= STOP when calib_cond = '0' else ro_clk;
    bufg_start: BUFGCTRL
    port map (
        CE0 => (not calib_cond),
        CE1 => calib_cond,
        IGNORE1 => '1',
        IGNORE0 => '1',
        I0 => START_bufr,
        I1 => ro_clk,
        S0 => '1',
        S1 => '1',
        O => start_mux
    );
    bufg_stop: BUFGCTRL
    port map (
        CE0 => (not calib_cond),
        CE1 => calib_cond,
        IGNORE1 => '1',
        IGNORE0 => '1',
        I0 => STOP_bufr,
        I1 => ro_clk,
        S0 => '1',
        S1 => '1',
        O => stop_mux
    );

    -- BUFRs um START-/Stopsignale ueber Taktleitungen zu den Multiplexern zu transportieren
    -- start_bufr  <= START;
    -- stop_bufr   <= STOP;
    START_buf: BUFR generic map (
        BUFR_DIVIDE => "BYPASS",
        SIM_DEVICE  => "7SERIES"
    ) port map (
        I   => START,
        O   => start_bufr,
        CE  => '1',
        CLR => '0'
    );
    STOP_buf: BUFR generic map (
        BUFR_DIVIDE => "BYPASS",
        SIM_DEVICE  => "7SERIES"
    ) port map (
        I   => STOP,
        O   => STOP_bufr,
        CE  => '1',
        CLR => '0'
    );

end architecture;
