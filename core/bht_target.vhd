library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bht_target is
	generic( n_addr : integer ;
			n_data  : integer);
	port
	(
		clk 	: in std_logic;
		stall	: in std_logic;
		we	 	: in std_logic;
		-------------------------
		r_addr	: in std_logic_vector(n_addr-1 downto 0);
		w_addr	: in std_logic_vector(n_addr-1 downto 0);
		d_in	: in std_logic_vector(n_data-1 downto 0);
		d_out	: out std_logic_vector(n_data-1 downto 0)
	);
end entity bht_target;

architecture behavior of bht_target is

	-----------------------------
	-- Array with: target
	type bht_target_type is ARRAY ((2**n_addr)-1 DOWNTO 0) of std_logic_vector(n_data-1 downto 0);
	signal bht_target : bht_target_type := (others => (others => '0'));

begin

	process (clk)
	begin
		if (rising_edge(clk)) then
			if (we = '1') then
				bht_target(to_integer(unsigned(w_addr))) <= d_in;

			end if;

			if (stall = '0') then
				d_out <= bht_target(to_integer(unsigned(r_addr)));

			end if;
		end if;
	end process;

end architecture behavior;
