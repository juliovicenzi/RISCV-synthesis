library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

use work.cache_pkg.all;
use work.map_pkg.all;
use work.ihex_init_pkg.all;

entity dcache is
    generic(
		n_data : integer;
		n_addr : integer
		);
	port(
		en_r	: in std_logic;
		clk		: in std_logic;
		col		: in std_logic;
		web		: in std_logic_vector(3 downto 0);
		addra	: in std_logic_vector(n_addr-1 downto 0);
		douta	: out std_logic_vector(n_data-1 downto 0);
		addrb	: in std_logic_vector(n_addr-1 downto 0);
		dinb	: in std_logic_vector(n_data-1 downto 0)
		);
end entity dcache;

architecture behavior of dcache is

	------------------------------------
	-- cache type
	type cache_type is ARRAY (0 to (2**n_addr)-1) of std_logic_vector(n_data-1 downto 0);

	------------------------------------
	-- cache initial value through a function in 'ihex_init_pkg.utils',
	-- it reads a ihex file	
	impure function InitCacheFromFile return cache_type is
		-- mem type
		variable	mem_word	:	std_logic_vector(mem_n-1 downto 0);
		variable	mem_valid	:	std_logic;
		variable	mem_addr	:	std_logic_vector(mem_naddr-1 downto 0);
		variable	mem_byte	:	std_logic_vector(7 downto 0);
		-- others
		variable	index1		:	integer := 0;
		variable	index2		:	integer := 0;
		-- output
		constant	offset		:	integer := 2;
		variable	cache		:	cache_type := (others => (others => '0'));
		variable	cache_index	:	std_logic_vector(n_addr-1 downto 0);
		constant	n_tag		:	integer := 32-n_addr-offset;	-- 2 bits offset address
		variable	cache_tag	:	std_logic_vector(n_tag-1 downto 0);
		variable	cache_word	:	std_logic_vector(n_data-1 downto 0) := (others => '0');
	begin
		for i in mem_type'range loop

			mem_word := (others => '0');	-- empty first
			mem_word := ihex_mem(i);
			mem_valid:= mem_word(mem_n-1);
			mem_addr := mem_word(mem_n-2 downto 8);
			mem_byte := mem_word(7 downto 0);

			-- if (mem_valid = '1' AND mem_addr >= SDATA_start) then
			if (mem_valid = '1' AND mem_addr < SDATA_start) then
				cache_index	:=	mem_addr(n_addr-1+offset downto 0+offset);
				cache_tag	:=	mem_addr(n_tag+n_addr-1+offset downto n_addr+offset);

				index1		:= to_integer(unsigned(cache_index));
				index2		:= to_integer(unsigned(mem_addr(1 downto 0)));

				cache(index1)(7+index2*8 downto 0+index2*8) := mem_byte;
			else
				null;
			end if;
		
		end loop;
	
        return cache;
    end function;
	
	signal	cache	:	cache_type	:=	InitCacheFromFile;

	-- bypass signal to avoid wrong read from the execution sequence: SW -> LW
	-- with the same address
	signal bypass		: std_logic;
	signal web_t		: std_logic_vector(3 downto 0);
	signal dinb_t		: std_logic_vector(n_data-1 downto 0);
	signal douta_port	: std_logic_vector(n_data-1 downto 0);
			
begin

	douta(31 downto 24) <=	dinb_t(31 downto 24)	when (bypass = '1' AND web_t(3) = '1') else
							douta_port(31 downto 24);

	douta(23 downto 16) <=	dinb_t(23 downto 16)	when (bypass = '1' AND web_t(2) = '1') else
							douta_port(23 downto 16);

	douta(15 downto 8) <=	dinb_t(15 downto 8)		when (bypass = '1' AND web_t(1) = '1') else
							douta_port(15 downto 8);

	douta(7 downto 0) <=	dinb_t(7 downto 0)		when (bypass = '1' AND web_t(0) = '1') else
							douta_port(7 downto 0);							
	

	----------------------------------------------------------
	-- bypass logic
	----------------------------------------------------------
	-- bypass flag
	process(clk)
	begin
		if(rising_edge(clk)) then
			if (col = '1') then	-- addra = addrb, two mem access at the same addr
				bypass <= '1';
			else
				bypass <= '0';
			end if;

		end if;
	end process;

	-- port B temp signals
	process(clk)
	begin
		if(rising_edge(clk)) then
			web_t	<= web;
			dinb_t	<= dinb;
		
		end if;
	end process;

	----------------------------------------------------------
	--	port A, read, 32 bits port
	----------------------------------------------------------
    process(clk)
    begin
		if(rising_edge(clk)) then
			
			if (en_r = '1') then
				douta_port <= cache(to_integer(unsigned(addra)));
			end if;
			
        end if;
    end process;

	----------------------------------------------------------	
	-- 	port B, write with byte enable, 32 bits port
	----------------------------------------------------------
    process(clk)
    begin
        if(rising_edge(clk)) then
			if(web(3) = '1') then
				cache(to_integer(unsigned(addrb)))(31 downto 24) <= dinb(31 downto 24);
			end if;
			if(web(2) = '1') then
				cache(to_integer(unsigned(addrb)))(23 downto 16) <= dinb(23 downto 16);
			end if;
			if(web(1) = '1') then
				cache(to_integer(unsigned(addrb)))(15 downto 8) <= dinb(15 downto 8);
			end if;
			if(web(0) = '1') then
				cache(to_integer(unsigned(addrb)))(7 downto 0) <= dinb(7 downto 0);
			end if;

        end if;
    end process;

end architecture;
