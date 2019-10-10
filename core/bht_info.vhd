library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bht_info is
	generic( n_addr : integer ;
			n_data  : integer);
	port
	(
		clk 	: in 	std_logic;
		rst		: in	std_logic;
		stall	: in	std_logic;
		we	 	: in 	std_logic;
		ready	: out	std_logic;
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
	signal bht_stag : bht_stag_type := (others => (others => '0'));

	-- output register
	signal bht_stag_out : std_logic_vector(n_data-2 downto 0);

	-----------------------------
	-- Array with: valid bit
	type bht_v_type is ARRAY ((2**n_addr)-1 DOWNTO 0) of std_logic;
	-- signal bht_v : bht_v_type := (others => '0');
	signal	bht_v	:	bht_v_type := (others => '0');	-- put to '0' to test the BHT Valid bit reset process
														-- and also the signal 'rst_done'

	-- input data/address
	signal addr_v:	std_logic_vector(n_addr-1 downto 0);
	signal d_in_v:	std_logic;

	-- output register
	signal bht_v_out : std_logic;

	-----------------------------
	-- FSM to reset the bht valid bit
	type state_fsm is (O_s , RST_s);
	signal rst_fsm		:	state_fsm := O_s;
	signal rst_bht		:	std_logic;
	signal rst_done		:	std_logic := '1';
	signal rst_index	:	std_logic_vector(n_addr-1 downto 0) := (others => '0');
	constant last_index	:	std_logic_vector(n_addr-1 downto 0) := (others => '1');

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
	addr_v	<=	w_addr			when (rst_bht = '0') else
				rst_index;
	d_in_v	<=	d_in(n_data-1)	when (rst_bht = '0') else
				'0';

	process (clk)
	begin
		if (rising_edge(clk)) then
			if (we = '1' OR rst_bht = '1') then
				bht_v(to_integer(unsigned(addr_v))) <= d_in_v;
			end if;

			if (stall = '0') then
				bht_v_out <= bht_v(to_integer(unsigned(r_addr)));

			end if;
		end if;
	end process;

	---------------------------------------------
	---- Reset BHT
	process(clk)
	begin
		if (rising_edge(clk)) then
			CASE rst_fsm is
				---------------------
				when O_s =>
					if (rst = '1' AND rst_done = '0') then
						rst_fsm	<= RST_s;
					elsif (we = '1' AND rst_done = '1') then
						rst_done <= '0';
					end if;
				---------------------
				when RST_s =>
					if (rst_index = last_index) then
						rst_done	<= '1';
						rst_index	<= (others => '0');
						rst_fsm		<= O_s;
					else
						rst_index	<= std_logic_vector(unsigned(rst_index) + 1);
					end if;
				---------------------
			end CASE;
		end if;
	end process;
	ready	<=	rst_done;
	rst_bht	<=	'1' when	(rst_fsm = RST_s) else
				'0';

end architecture behavior;
