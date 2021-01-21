library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.tdc_pkg.all;

entity priority_encoder is
    generic (PHASE  : string := "0");
    port (
        CLK         : in std_logic;
        CLK_P90     : in std_logic;
        RST         : in std_logic;
        D           : in r_dl_out;
        Q           : out r_pe_out
    );
end entity;

architecture priority_encoder_arch of priority_encoder is

    type r is record
        valid1          : std_logic_vector(1 downto 0);
        valid2          : std_logic;
        valid_out       : std_logic;

        bins            : std_logic_vector(d.bins'range);
        bin             : unsigned(PE_INTBITS-1 downto 0);
        bin_out         : unsigned(PE_INTBITS-1 downto 0);
        sslv            : std_logic_vector(11 downto 0);
        cpos            : unsigned(3 downto 0);
        cpos2           : unsigned(3 downto 0);
    end record;

    signal s        : r;
    signal clk_pol  : std_logic;

begin


    process(clk_pol)
        variable v_coarse : std_logic_vector(96/6-1 downto 0);
        variable bins_extended : std_logic_vector(DEPTH*4-1+12 downto 0);
    begin
        if rising_edge(clk_pol) then
            for i in 0 to 96/6-1 loop
                -- Thermometercode -> One-Hot-Code fuer Grobe Flankenbestimmung
                if d.bins(i*6+5 downto i*6) = "111111" then
                    v_coarse(i) := '1';
                else
                    v_coarse(i) := '0';
                end if;
            end loop;
            s.bins      <= d.bins;
            s.cpos      <= onehot2bin(therm2onehot(v_coarse)); -- grobe Flankenposition
            -- cycle
            bins_extended := x"000" & s.bins;
            s.sslv      <= bins_extended(to_integer(s.cpos)*6+12-1 downto to_integer(s.cpos)*6); -- speichere 12 Bit mit Signalflanke in Register
            s.valid1    <= s.bins(DEPTH*4-1) & s.bins(0);    -- Datum Valid
            s.cpos2     <= s.cpos;
            -- cycle
            s.bin       <= resize(s.cpos2*6 + find_msb(s.sslv),PE_INTBITS); -- Zaehlen der Einsen und generierung der Gesamtposition
            s.valid2    <= s.valid1(0) and (not s.valid1(1));

        end if;
    end process;


    -- sync PHASE to channel logic
    -- output synchronous to channel logic
    process(CLK)
    begin
        if rising_edge(CLK) then
            q.bin           <= s.bin_out;
            q.valid         <= s.valid_out;
        end if;
    end process;

    pol_0: if PHASE = "0" generate
        clk_pol <= CLK;
        process(CLK)
        begin
            if rising_edge(CLK) then
                s.bin_out <= s.bin;
                s.valid_out <= s.valid2;
            end if;
        end process;
    end generate;
    pol_90: if PHASE = "90" generate
        clk_pol <= CLK_P90;
        process(CLK)
        begin
            if rising_edge(CLK) then
                s.bin_out <= s.bin;
                s.valid_out <= s.valid2;
            end if;
        end process;
    end generate;
    pol_180: if PHASE = "180" generate
        clk_pol <= not CLK;
        process(CLK_P90)
        begin
            if rising_edge(CLK_P90) then
                s.bin_out <= s.bin;
                s.valid_out <= s.valid2;
            end if;
        end process;
    end generate;
    pol_270: if PHASE = "270" generate
        clk_pol <= not CLK_P90;
        process(CLK)
        begin
            if falling_edge(CLK) then
                s.bin_out <= s.bin;
                s.valid_out <= s.valid2;
            end if;
        end process;
    end generate;

end architecture;
