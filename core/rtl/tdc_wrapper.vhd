library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unimacro;
use unimacro.vcomponents.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.tdc_pkg.all;

entity tdc_wrapper is
    port (
        clk         : in std_logic;
        ce          : in std_logic;
        CLK_PIN     : in std_logic;
        RST         : in std_logic;

        -- CLK260_OUT  : out std_logic;

        START       : in std_logic;
        STOP        : in std_logic;
        CALIB_EN    : in std_logic;
        READY       : out std_logic;

        time_fifo_RDEN   : in std_logic;
        time_fifo_DO     : out std_logic_vector(31 downto 0);
        time_fifo_EMPTY  : out std_logic;
        time_fifo_RDERR  : out std_logic;

        period_fifo_WREN : in std_logic;
        period_fifo_DI   : in std_logic_vector(31 downto 0)

        -- dbg_up      : out r_dbg_up;
        -- dbg_down    : in r_dbg_down
    );
end entity;

architecture tdc_wrapper_arch of tdc_wrapper is
    type r is record
        ready       : std_logic;
        rst         : std_logic;
        rst_cnt     : unsigned(2 downto 0);
        calib_en    : std_logic;
    end record;

    signal s    : r;

    signal clk260           : std_logic;
    signal clk260_p90       : std_logic;
    signal clk260_temp      : std_logic;
    signal clk260_p90_temp  : std_logic;
    signal mmcm_feedback    : std_logic;

    signal ro_en        : std_logic;
    signal ro_clk       : std_logic;
    signal tdc_rdst     : std_logic;
    signal tdc_ready    : std_logic;
    signal tdc_time     : std_logic_vector(30 downto 0);
    signal tdc_id       : std_logic;
    signal tdc_rst      : std_logic;
    signal tdc_valid    : std_logic;
    signal time_fifo_di      : std_logic_vector(31 downto 0);


    signal period_fifo_DO       : std_logic_vector(31 downto 0);
    signal period_fifo_EMPTY    : std_logic;
    signal period_fifo_RDERR    : std_logic;
    signal period_fifo_RDEN     : std_logic;

    signal tdc_period           : unsigned(12 downto 0);
    signal tdc_period_valid     : std_logic;

    signal unused0      : std_logic_vector(3 downto 0);
    signal unused1      : std_logic_vector(8 downto 0);
    signal unused2      : std_logic_vector(8 downto 0);


    signal unused3      : std_logic_vector(3 downto 0);
    signal unused4      : std_logic_vector(8 downto 0);
    signal unused5      : std_logic_vector(8 downto 0);

    signal unused : std_logic_vector(18 downto 0);
    signal do_unused : std_logic_vector(15 downto 0);

begin

    -- clk260_out <= clk260;

    -- CLK_ext --> CLK
    process(CLK260)
    begin
        if rising_edge(CLK260) then
            -- defaults
            tdc_period_valid <= '0';
            period_fifo_rden <= '0';

            -- guarantee 8 reset cycles
            if s.rst_cnt /= "111" then
                s.rst_cnt <= s.rst_cnt + 1;
                tdc_rst <= '1';
            else
                tdc_rst <= '0';
            end if;
            s.rst <= RST;
            if s.rst = '1' then
                s.rst_cnt <= (others => '0');
            end if;
            s.calib_en <= CALIB_EN;

            -- period_fifo handling
            if period_fifo_empty = '0' and tdc_period_valid = '0' then
                period_fifo_rden <= '1';
                tdc_period_valid <= '1';
                tdc_period <= resize(unsigned(period_fifo_do),13);
            end if;

        end if;
    end process;

    -- CLK260 --> clk100
    process(clk)
    begin
        if rising_edge(clk) then
            if RST = '1' then
                READY <= '0';
            else
                s.ready <= tdc_ready;
                READY <= s.ready;
            end if;
        end if;
    end process;

    tdc_inst: entity work.tdc(tdc_arch)
    port map (
        CLK     => CLK260,
        CLK_P90 => CLK260_P90,
        RST     => tdc_rst,

        START   => START,
        STOP    => STOP,
        CALIB_EN => s.calib_en,
        READY   => tdc_ready,

        TIME    => tdc_time,
        VALID   => tdc_valid,
        ID      => tdc_id,

        PERIOD  => tdc_period,
        PERIOD_VALID => tdc_period_valid

        -- dbg_up  => dbg_up,
        -- dbg_down => dbg_down
    );

    -- Taktsynchronisierung der TDC-Ausgangswerte
    time_fifo_di <= tdc_id & tdc_time;
    out_fifo: FIFO_DUALCLOCK_MACRO
    generic map (
        DATA_WIDTH              => 32,
        FIFO_SIZE               => "18Kb",
        FIRST_WORD_FALL_THROUGH => True
    ) port map (
        WRCLK   => CLK260,
        RDCLK   => clk,
        RST     => RST,
        DI      => time_fifo_di,
        WREN    => tdc_valid,

        DO      => time_fifo_DO,
        EMPTY   => time_fifo_EMPTY,
        RDERR   => time_fifo_RDERR,
        RDEN    => time_fifo_RDEN,

        ALMOSTEMPTY => unused0(0),
        ALMOSTFULL  => unused0(1),
        FULL        => unused0(2),
        RDCOUNT     => unused1,
        WRCOUNT     => unused2,
        WRERR       => unused0(3)
    );

    -- Taktsynchronisierung fuer die Anpassung der Taktperiode
    in_fifo: FIFO_DUALCLOCK_MACRO
    generic map (
        DATA_WIDTH              => 32,
        FIFO_SIZE               => "18Kb",
        FIRST_WORD_FALL_THROUGH => True
    ) port map (
        WRCLK   => clk,
        RDCLK   => clk260,
        RST     => RST,
        DI      => period_fifo_di,
        WREN    => period_fifo_wren,

        DO      => period_fifo_DO,
        EMPTY   => period_fifo_EMPTY,
        RDERR   => period_fifo_RDERR,
        RDEN    => period_fifo_RDEN,

        ALMOSTEMPTY => unused3(0),
        ALMOSTFULL  => unused3(1),
        FULL        => unused3(2),
        RDCOUNT     => unused4,
        WRCOUNT     => unused5,
        WRERR       => unused3(3)
    );

    -- Generiere 260 MHz Takt bei 0 und 90 Grad Phase
    -- 100 -> 260 MHz: M=52, D=5, O=4
    -- 200 -> 260 MHz: M=26, D=5, O=4
    mmcm: mmcme2_adv
    generic map (
        BANDWIDTH           => "OPTIMIZED",
        COMPENSATION        => "ZHOLD",
        CLKFBOUT_MULT_F     => 52.0,
        CLKIN1_PERIOD       => 10.0,
        DIVCLK_DIVIDE       => 5,
        CLKOUT0_DIVIDE_F    => 4.0,
        CLKOUT1_DIVIDE      => 4,
        CLKOUT1_PHASE       => 90.0,
        REF_JITTER1         => 0.01
    ) port map (
        CLKFBIN     => mmcm_feedback,
        CLKFBOUT    => mmcm_feedback,
        CLKFBOUTB   => unused(0),
        CLKOUT0     => CLK260_temp,
        CLKOUT0B    => unused(1),
        CLKOUT1     => CLK260_P90_temp,
        CLKOUT1B    => unused(2),
        CLKOUT2     => unused(17),
        CLKOUT2B    => unused(4),
        CLKOUT3     => unused(5),
        CLKOUT3B    => unused(6),
        CLKOUT4     => unused(7),
        CLKOUT5     => unused(8),
        CLKOUT6     => unused(9),
        CLKIN1      => CLK_PIN,
        CLKIN2      => '0',
        CLKINSEL    => '1',
        DADDR       => (others => '0'),
        DCLK        => '0',
        DEN         => '0',
        DI          => (others => '0'),
        DO          => do_unused,
        DRDY        => unused(11),
        DWE         => '0',
        psclk       => unused(18),
        psen        => unused(14),
        psincdec    => unused(15),
        psdone      => unused(16),
        clkinstopped=> unused(12),
        clkfbstopped=> unused(13),
        PWRDWN      => '0',
        RST         => '0',
        LOCKED      => unused(10)
    );
    clk260_buf: BUFR generic map (
        BUFR_DIVIDE => "BYPASS",
        SIM_DEVICE  => "7SERIES"
    ) port map (
        I   => CLK260_temp,
        O   => CLK260,
        CE  => '1',
        CLR => '0'
    );
    clk220p90_buf: BUFR generic map (
        BUFR_DIVIDE => "BYPASS",
        SIM_DEVICE  => "7SERIES"
    ) port map (
        I   => CLK260_P90_temp,
        O   => CLK260_P90,
        CE  => '1',
        CLR => '0'
    );
end architecture;
