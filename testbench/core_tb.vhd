library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;

entity core_tb is
end entity;

architecture test of core_tb is
	signal rst : std_logic := '1';
	signal clk : std_logic := '0';
	signal intr : std_logic := '0';
	signal stall_icache, valid_iaddr, valid_daddr, sb_en, sh_en, we : std_logic;
	signal addr_dcache, data_icache, data_dcache :  std_logic_vector(n-1 downto 0);
	signal addr_icache : std_logic_vector(n-1 downto 2);
	
	constant clk_half_period: time:= 5 ns;
begin
	rst <= '0' after 2 ns;
	clk <= not clk after clk_half_period;
	
	data_icache <= x"00100293";
	data_dcache <= x"00000003";
	
	DUV: entity work.core
	port map
	(
		clk     	=> clk,
		rst		 	=> rst,
		intr		=> intr,
		wait_i		=> '0',
		wait_d		=> '0',
		stall_icache => stall_icache,
		valid_iaddr	=> valid_iaddr,
		valid_daddr	=> valid_daddr,
		sb_en	 	=> sb_en,
		sh_en	 	=> sh_en,
		we	     	=> we,
		addr_dcache => addr_dcache,
		addr_icache => addr_icache,
		data_icache => data_icache,
		data_dcache => data_dcache
	);'
end architecture;