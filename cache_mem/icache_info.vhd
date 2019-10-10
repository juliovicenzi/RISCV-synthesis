library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

use work.cache_pkg.all;
use work.map_pkg.all;
use	work.ihex_init_pkg.all;

entity icache_info is
    generic(n_data : integer;
            n_addr : integer);
    port(
		clk		: in std_logic;
		en		: in std_logic;
		we		: in std_logic;
		addr	: in std_logic_vector(n_addr-1 downto 0);
		din		: in std_logic_vector(n_data-1 downto 0);
        dout	: out std_logic_vector(n_data-1 downto 0));
end entity icache_info;

architecture behavior of icache_info is

	------------------------------------
	-- cache type
    type cache_type is ARRAY (0 to (2**n_addr)-1) of std_logic_vector(n_data-1 downto 0);

	------------------------------------
	-- cache initial value through a function in 'ihex_init_pkg.utils',
	-- it reads a ihex file
	impure function InitCacheFromFile return cache_type is
		-- mem type, inside the ihex read package
		variable	mem_word	:	std_logic_vector(mem_n-1 downto 0);
		variable	mem_valid	:	std_logic;
		variable	mem_addr	:	std_logic_vector(mem_naddr-1 downto 0);
		-- others
		variable	index1		:	integer := 0;
		-- output
		constant	offset		:	integer := 2;
		variable	cache		:	cache_type := (others => (others => '0'));
		variable	cache_index	:	std_logic_vector(n_addr-1 downto 0);
		constant	n_tag		:	integer := 32-n_addr-offset;	-- 2 bits offset address
		variable	cache_tag	:	std_logic_vector(n_tag-1 downto 0);
    begin
		for i in mem_type'range loop

			mem_word := (others => '0');		-- empty first
			mem_word := ihex_mem(i);
			mem_valid:= mem_word(mem_n-1);
			mem_addr := mem_word(mem_n-2 downto 8);
			if (mem_valid = '1' AND mem_addr <= TEXT_end) then
				cache_index	:=	mem_addr(n_addr-1+offset downto 0+offset);
				cache_tag	:=	mem_addr(n_tag+n_addr-1+offset downto n_addr+offset);

				index1		:=	to_integer(unsigned(cache_index));
				cache(index1) := '1'&cache_tag;
			else
				null;
			end if;

		end loop;
        return cache;
    end function;

	signal cache : cache_type := InitCacheFromFile;

begin

	process(clk)
	begin
		if(rising_edge(clk)) then
			if (en = '1') then
				-------------------------------
				-- write first
				if (we = '1') then
					cache(to_integer(unsigned(addr))) <= din;
					dout <= din;
				else
					dout <= cache(to_integer(unsigned(addr)));
				end if;
				-------------------------------
			end if;
		end if;
	end process;

end architecture behavior;
