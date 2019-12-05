library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- changes: since BHT will be synthesized to an array of registers
-- the valid bit reset information has been changed to a single rst signal
entity bht_info is
	generic( n_addr : integer ;
			n_data  : integer);
	port
	(
		clk 	: in 	std_logic;
		rst		: in	std_logic;
		stall	: in	std_logic;
		we	 	: in 	std_logic;
		----------------------------
		r_addr	: in 	std_logic_vector(n_addr-1 downto 0);
		w_addr	: in 	std_logic_vector(n_addr-1 downto 0);
		d_in	: in 	std_logic_vector(n_data-1 downto 0);
		d_out	: out std_logic_vector(n_data-1 downto 0)
	);
end entity bht_info;

architecture behavior of bht_info is

	-----------------------------
	-- Array with: 2 bit state & tag
	type bht_stag_type is ARRAY ((2**n_addr)-1 DOWNTO 0) of std_logic_vector(n_data-2 downto 0);
	signal bht_stag : bht_stag_type; -- := (others => (others => '0'));

	-- output register
	signal bht_stag_out : std_logic_vector(n_data-2 downto 0);

	-----------------------------
	-- Array with: valid bit
	type bht_v_type is ARRAY ((2**n_addr)-1 DOWNTO 0) of std_logic;

	signal	bht_v	:	bht_v_type; 

	-- input data/address
	signal addr_v:	std_logic_vector(n_addr-1 downto 0);
	signal d_in_v:	std_logic;

	-- output register
	signal bht_v_out : std_logic;
	
begin

	d_out <= bht_v_out & bht_stag_out;

	----- 2bit state & tag
	process (clk)
	begin
		if (rising_edge(clk)) then
			if (we = '1') then
				bht_stag(to_integer(unsigned(w_addr))) <= d_in(n_data-2 downto 0);
			end if;

			if (stall = '0') then
				bht_stag_out <= bht_stag(to_integer(unsigned(r_addr)));

			end if;
		end if;
	end process;

	----- valid bit
	addr_v	<=	w_addr;
	d_in_v	<=	d_in(n_data-1);

	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				bht_v <= (others => (others => '0'));
			else
				if we = '1' then
					bht_v(to_integer(unsigned(addr_v))) <= d_in_v;
				end if;

				if stall = '0' then
					bht_v_out <= bht_v(to_integer(unsigned(r_addr)));

				end if;
			end if;
		end if;
	end process;

end architecture behavior;
