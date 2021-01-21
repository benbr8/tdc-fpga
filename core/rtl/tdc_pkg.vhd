library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tdc_pkg is
    -- CONSTANTS
    constant DEPTH          : positive := 24;       -- Anzahl der Abtastbaren Carrychain
    constant HIST_SIZE      : positive := 2**18;    -- power of 2 (!)
    constant CLK_IN_PS      : positive := 3864;     -- Initialer Wert
    constant PE_INTBITS     : positive := 9;        -- do not change!
    constant CALIB_DEADTIME : positive := 8;        -- default: 8
    constant RO_LENGTH      : positive := 55;       -- ungerade!
    constant SIM            : boolean := False;
    constant SIM_OFFSET     : integer := 510;


    -- TYPES
    type r_dbg_down is record
        hist_en     : std_logic;
    end record;
    type r_dbg_up is record
        hist_data   : std_logic_vector(17 downto 0);
        hist_valid  : std_logic;
    end record;

    -- INTERFACES
    -- delay_line
    type r_dl_in is record
        sensor      : std_logic;
    end record;
    type r_dl_out is record
        bins        : std_logic_vector(DEPTH*4-1 downto 0);
    end record;

    -- priority_encoder
    -- uses r_dl_out input
    type r_pe_out is record
        bin         : unsigned(PE_INTBITS-1 downto 0);
        valid       : std_logic;
    end record;

    -- dl_sync
    type r_dls_in is record
        sensor      : std_logic;
        calib_en    : std_logic;
    end record;
    type r_dls_out is record
        bin         : unsigned(PE_INTBITS-1 downto 0);
        valid       : std_logic;
        calib_flag  : std_logic;
    end record;

    -- LUT
    type r_lut_in is record
        valid       : std_logic;
        calib_flag  : std_logic;
        bin         : unsigned(PE_INTBITS-1 downto 0);
        -- dbg         : r_dbg_down;
    end record;
    type r_lut_out is record
        data    : unsigned(17 downto 0);
        init    : std_logic;
        -- dbg     : r_dbg_up;
    end record;

    -- channel
    type r_ch_in is record
        clk_period  : unsigned(12 downto 0);
        sensor      : std_logic;
        calib_en    : std_logic;
        -- dbg         : r_dbg_down;
    end record;
    type r_ch_out is record
        ready,valid : std_logic;
        time        : unsigned(12 downto 0);
        -- dbg     : r_dbg_up;
    end record;

    -- BRAM
    type r_bram_in is record
        di      : std_logic_vector(17 downto 0);
        wa,ra   : std_logic_vector(9 downto 0);
        re,we   : std_logic;
    end record;
    type r_bram_out is record
        do      : std_logic_vector(17 downto 0);
    end record;

    type r_bram is record
        di      : std_logic_vector(17 downto 0);
        do      : std_logic_vector(17 downto 0);
        wa,ra   : std_logic_vector(9 downto 0);
        re,we   : std_logic;
    end record;

    -- FUNCTIONS
    function therm2onehot(slv : std_logic_vector) return std_logic_vector;
    function onehot2bin(slv: std_logic_vector) return unsigned;
    function find_msb(slv : std_logic_vector) return integer;
    function UtoS(U: unsigned) return signed;
    function "+" (L: signed; R: unsigned) return signed;
    function log2( i : natural) return integer;
    function prop (slv: std_logic_vector) return std_logic_vector;
end package;

package body tdc_pkg is
    -- FUNCTIONS

    function therm2onehot(slv : std_logic_vector) return std_logic_vector is
        variable v_slv      : std_logic_vector(slv'length-1 downto 0);
        variable v_return : std_logic_vector(slv'length-2 downto 0);
    begin
        v_return := (others => '0');
        v_slv := slv;
        for i in 0 to slv'length-2 loop
            if v_slv(i) = '1' and v_slv(i+1) = '0' then
                v_return(i) := '1';
            end if;
        end loop;
        return v_return;
    end function;

    function onehot2bin(slv: std_logic_vector) return unsigned is
        variable v_return : std_logic_vector(3 downto 0);
        variable v_slv : std_logic_vector(14 downto 0);
    begin
        -- v_slv := (others => '0');
        v_return := (others => '0');
        v_slv := slv;
        for i in v_slv'range loop
            if v_slv(i) = '1' then
                v_return := v_return or std_logic_vector(to_unsigned(i+1,4));
            end if;
        end loop;
        return unsigned(v_return);
    end function;

    function find_msb(slv : std_logic_vector) return integer is
        variable v_return   : integer range 0 to slv'length := 0;
        variable v_slv      : std_logic_vector(slv'length-1 downto 0);
    begin
        v_slv       := slv;
        for i in 0 to v_slv'length-1 loop
            if v_slv(i) = '1' then
                v_return := v_return+1;
            end if;
        end loop;
        return v_return;
    end function;

    function UtoS(U: unsigned) return signed is
    begin
        return signed('0'&std_logic_vector(U));
    end function;

    function "+" (L: signed; R: unsigned) return signed is
    begin
        return L + signed('0'&std_logic_vector(R));
    end function;

    function log2( i : natural) return integer is
        variable temp    : integer := i;
        variable ret_val : integer := 0;
    begin
        while temp > 1 loop
            ret_val := ret_val + 1;
            temp    := temp / 2;
        end loop;
        return ret_val;
    end function;

    function prop (slv: std_logic_vector) return std_logic_vector is
        variable v_slv : std_logic_vector(slv'length-1 downto 0);
        variable v_return : std_logic_vector(slv'length-1 downto 0);
    begin
        v_slv := slv;
        v_return := v_slv(slv'length-2 downto 0) & '0';
        return v_return;
    end function;

end package body;
