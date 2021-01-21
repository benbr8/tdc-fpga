library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unimacro;
use unimacro.vcomponents.all;

library work;
use work.tdc_pkg.all;


entity lut is
    generic (CH : string);
    port (
        CLK     : in std_logic;
        RST     : in std_logic;
        D       : in r_lut_in;
        Q       : out r_lut_out
    );
end entity;


architecture lut_arch of lut is
    type t_state is (CLEAR,RUN,CONFIG);
    type r_confpipe is record
        cnt         : unsigned(8 downto 0);
        valid       : std_logic;
    end record;
    type a_confpipe is array (2 downto 0) of r_confpipe;
    constant c_confpipe_0 : r_confpipe := ((others => '0'),'0');


    type r is record
        state       : t_state;
        hit_cnt     : unsigned(17 downto 0);
        clear_cnt   : unsigned(9 downto 0);
        mempage     : std_logic;
        init        : std_logic;
        wait1       : std_logic;
        confpipe    : a_confpipe;
        sum         : unsigned(17 downto 0);
        ap0,ap1     : std_logic_vector(9 downto 0); -- address pipe
        -- dbg_en      : std_logic;
    end record;

    signal s        : r;
    signal hist,lut : r_bram;

begin
    lut.ra <= s.mempage & std_logic_vector(d.bin);
    lut.re <= d.valid;
    q.data <= unsigned(lut.do);
    q.init <= s.init;

    process(CLK)
    begin
        if rising_edge(CLK) then
            -- defaults
            hist.we <= '0';
            hist.re <= '0';
            lut.we  <= '0';
            s.sum   <= (s.sum'range => '0');
            s.clear_cnt <= (others => '0');
            s.wait1 <= '0';

            -- DEBUG
            -- q.dbg.hist_valid <= '0';

            if RST = '1' then
                s.state     <= CLEAR;
                s.confpipe  <= (others => c_confpipe_0);
                s.init <= '0';
                s.mempage   <= '0';
                s.ap0 <= (others => '0');
                s.ap1 <= (others => '0');

                -- DEBUG
                -- s.dbg_en <= '0';
            else
                case s.state is
                    -- leere Histogrammspeicher
                    when CLEAR =>
                        s.hit_cnt   <= (others => '0');
                        hist.wa <= std_logic_vector(s.clear_cnt);
                        hist.di <= (hist.di'range => '0');
                        hist.we <= '1';

                        if s.clear_cnt = DEPTH*4*4 then
                            s.state <= RUN;
                        else
                            s.clear_cnt <= s.clear_cnt+1;
                        end if;

                    -- Akkumulation des Histogramms
                    when RUN =>

                        -- only use RO for calibration, only when Histpipe empty
                        if d.valid = '1' and d.calib_flag = '1' and hist.re = '0' and s.wait1 = '0' then
                            hist.ra <= '0' & std_logic_vector(d.bin);
                            s.ap0   <= '0' & std_logic_vector(d.bin);
                            hist.re <= '1';
                        end if;

                        s.wait1 <= hist.re;
                        s.ap1   <= s.ap0;

                        if s.wait1 = '1' then
                            hist.we <= '1';
                            hist.wa <= s.ap1;
                            hist.di <= std_logic_vector(unsigned(hist.do)+1);
                            if s.hit_cnt = HIST_SIZE-2 then
                                s.state       <= CONFIG;
                                s.hit_cnt   <= (others => '0');
                                s.confpipe  <= (others => c_confpipe_0);

                                -- DEBUG
                                -- s.dbg_en <= d.dbg.hist_en;
                            else
                                s.hit_cnt <= s.hit_cnt+1;
                            end if;
                        end if;

                    -- generiere LUT
                    when CONFIG =>
                        s.confpipe(0).cnt   <= s.confpipe(0).cnt+1;
                        s.confpipe(0).valid <= '1';
                        hist.ra             <= '0' & std_logic_vector(s.confpipe(0).cnt);
                        hist.re <= '1';

                        s.confpipe(1) <= s.confpipe(0);
                        s.confpipe(2) <= s.confpipe(1);
                        if s.confpipe(2).valid = '1' then
                            s.sum   <= s.sum + unsigned(hist.do);
                            lut.di  <= std_logic_vector(s.sum + shift_right(unsigned(hist.do),1));
                            lut.wa  <= (not s.mempage) & std_logic_vector(s.confpipe(2).cnt); -- Schreibe an nicht lesbare Seite des LUT-Speichers
                            lut.we  <= '1';

                            -- DEBUG: Ausgabe des Histogramms
                            -- if s.dbg_en = '1' then
                            --     q.dbg.hist_data <= hist.do;
                            --     q.dbg.hist_valid <= '1';
                            -- end if;
                        end if;

                        if s.confpipe(2).cnt = DEPTH*4*4 then
                            s.state <= CLEAR;
                            s.mempage <= not s.mempage; -- Alterniere MSB der LUT-Leseaddresse
                            s.init <= '1';

                            -- DEBUG
                            -- s.dbg_en <= '0';
                        end if;

                    when others =>
                        s.state <= CLEAR;
                end case;
            end if;
        end if;
    end process;


    hist_inst: BRAM_SDP_MACRO
    generic map (
        BRAM_SIZE   => "18Kb",
        DEVICE      => "7SERIES",
        DO_REG      => 0,
        READ_WIDTH  => 18,
        WRITE_WIDTH => 18
    ) port map (
        DO      => hist.do,
        DI      => hist.di,
        WRADDR  => hist.wa,
        RDADDR  => hist.ra,
        WE      => "11",
        WREN    => hist.we,
        RDEN    => hist.re,
        RST     => RST,
        REGCE   => '1',
        WRCLK   => CLK,
        RDCLK   => CLK
    );

    lut_inst: BRAM_SDP_MACRO
    generic map (
        BRAM_SIZE   => "18Kb",
        DEVICE      => "7SERIES",
        DO_REG      => 0,
        READ_WIDTH  => 18,
        WRITE_WIDTH => 18
    ) port map (
        DO      => lut.do,
        DI      => lut.di,
        WRADDR  => lut.wa,
        RDADDR  => lut.ra,
        WE      => "11",
        WREN    => lut.we,
        RDEN    => lut.re,
        RST     => RST,
        REGCE   => '1',
        WRCLK   => CLK,
        RDCLK   => CLK
    );

end architecture;
