library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cache_pkg.all;
use work.map_pkg.all;

entity dcache_ctrl is
	port(
		clk			: in std_logic;
		rst_cache	: in std_logic;
		rst_index	: in std_logic_vector(11 downto 0);
		-- connections with the core, data cache
		valid_addr	: in std_logic;
		wait_d		: out std_logic;
		we			: in std_logic;
		sh_en		: in std_logic;
		sb_en		: in std_logic;
		-- addr and data bus from the core
		addr		: in std_logic_vector(n-1 downto 0);	-- address used to access the cache
		addr_reg	: in std_logic_vector(n-1 downto 0);	-- address registered (addr) to control de cache access
		data_i		: in std_logic_vector(n-1 downto 0);	-- data bus input
		data_o		: out std_logic_vector(n-1 downto 0);	-- data bus output
		-- ctrl signals to/from the main memory
		miss_dcache	: out std_logic;						-- cache miss
		wb_en		: out std_logic;						-- write back to memory
		addr_wb		: out std_logic_vector(n-1 downto 0);	-- write back address
		din			: in std_logic_vector(n-1 downto 0);	-- data input from the main memory
		dout		: out std_logic_vector(n-1 downto 0);	-- data output to the main memory
		ready_dr	: in std_logic							-- data request from main memory done when '1' (read or write)
	);
end entity dcache_ctrl;

architecture behavior of dcache_ctrl is

	-- verify if the address input of the data cache is inside the memory region of data
	alias	 SEC_addr is addr(31 downto 0);

	---------------------
	-- Finite State Machine
	-- O:	do nothing
	-- CA:	cache access
	-- MA:	memory access (load op)
	-- WB:	write back (write op)
	type	state_m is (O , CA , MA , WB);
	signal	state_dcache	: state_m := O;

	signal	w_ma		:	std_logic;
	signal	wb_done 	:	std_logic;
	signal	web			:	std_logic_vector(3 downto 0);
	signal	en_cache_r	:	std_logic;
	signal	cache_access:	std_logic;
	signal	oe			:	std_logic;
	signal	miss_tag	:	std_logic;
	signal	miss_w		:	std_logic;
	signal	miss_hb		:	std_logic;
	signal	miss_r		:	std_logic;
	signal	miss		:	std_logic;
	signal	col			:	std_logic;	-- when '1', it means there is two cache access at the same
										-- address

	---------------------
	-- D CACHE
	constant n_cache	:	integer := 32;
	constant n_addr		:	integer := 12;	-- 2^12 words of 32 bits, 8kB

	signal	byte_sel	:	std_logic_vector(1 downto 0);
	signal	web_t		:	std_logic_vector(3 downto 0);
	signal	index_access:	std_logic_vector(n_addr-1 downto 0);
	signal	index_op	:	std_logic_vector(n_addr-1 downto 0);
	signal	douta		:	std_logic_vector(n_cache-1 downto 0);
	signal	dinb		:	std_logic_vector(n_cache-1 downto 0);
	signal	dinb_t		:	std_logic_vector(n_cache-1 downto 0);

	---------------------
	-- D CACHE - INFO
	constant ntag	:	integer := n2-n_addr;
	constant ninfo	:	integer := ntag+2;		-- tag + valid bit + modified bit

	signal	web_info:	std_logic;
	signal	tag_in	:	std_logic_vector(ntag-1 downto 0);
	signal	tag_out	:	std_logic_vector(ntag-1 downto 0);
	signal	v_in	:	std_logic;
	signal	v_out	:	std_logic;
	signal	mod_in	:	std_logic;
	signal	mod_out	:	std_logic;
	signal	info_in	:	std_logic_vector(ninfo-1 downto 0);
	signal	info_out:	std_logic_vector(ninfo-1 downto 0);

begin

	-- address of the write back operation, in to the main memory
	addr_wb <= tag_out&index_op&"00";

--------------------------------
--------------------------------
------ Finite State Machine

	-- FSM inputs and outpus
	en_cache_r	<=	'1'	when	((cache_access = '1' AND (state_dcache = O OR state_dcache = CA)) AND miss = '0') else
					'0';

	cache_access <=	'1' when	(SEC_addr <= SDATA_end AND valid_addr = '1') else
					'0';

	oe 	<=	'1' when (state_dcache = CA AND we = '0') else
			'0';

	miss_dcache	<= miss when (state_dcache = CA)									else
					'1'	when (wb_done = '1' AND (miss_hb = '1' OR miss_r = '1'))	else
					'0';

	wait_d	<=	'1' when ((state_dcache = CA AND miss = '1') OR state_dcache = MA OR state_dcache = WB)	else
				'0';

	w_ma 	<=	'1' when (state_dcache = MA AND ready_dr = '1') else	-- write from the main memory to cache enable
				'0';

	wb_en 	<=	'1' when (state_dcache = WB OR (state_dcache = CA AND miss = '1' AND mod_out = '1')) else	-- write back to main mem enable
				'0';
	wb_done	<=	'1' when (state_dcache = WB AND ready_dr = '1') else	-- it says when a write back op is done
				'0';

	web		<=	"1111"	when (w_ma = '1') else	-- SW from main memory to cache
				web_t;							-- SW/SH/SB from core to cache

	web_info <= '1' when ((state_dcache = CA AND we = '1' AND miss = '0') OR w_ma = '1' OR wb_done = '1' OR rst_cache = '1') else
				'0';

	v_in	<=	'0' when (wb_done = '1' OR rst_cache = '1') else	-- the data is set to invalid when a write back is done (so we know there is nothing there now)
				'1';

	mod_in	<=	'1' when (state_dcache = CA AND we = '1') else	-- only mark as modified (dirty) if the write is on the CA state
				'0';

	-- input and output to main memory
	dinb <= din		when (state_dcache = MA) else	-- select the data from main memory if the state is MA (memory access)
			dinb_t;	-- when (state_dcache /= MA);

	dout <= douta;

	-- FSM Process
	fsm: process (clk)
	begin
		if (rising_edge(clk)) then
			CASE state_dcache is
				when O =>
					if (rst_cache = '1') then
						null;
					elsif (cache_access = '1') then
						state_dcache <= CA;
					end if;
				------------------------------------
				when CA =>
					if (rst_cache = '1') then
						state_dcache <= O;

					elsif (miss = '1') then
						if (mod_out = '0') then
							state_dcache <= MA;
						else
							state_dcache <= WB;
						end if;

					elsif (cache_access = '1') then
						state_dcache <= CA;

					else
						state_dcache <= O;

					end if;
				------------------------------------
				when MA =>
					if (rst_cache = '1') then
						state_dcache <= O;
					elsif (ready_dr = '1') then
						state_dcache <= CA;
					end if;
				------------------------------------
				when WB =>
					if (rst_cache = '1') then
						state_dcache <= O;
					elsif (ready_dr = '1') then
						if (miss_hb = '1' OR miss_r = '1') then
							state_dcache <= MA;
						elsif (miss_w = '1') then
							state_dcache <= CA;
						end if;
					end if;

			end CASE;
		end if;
	end process fsm;

	-- miss cache, ignore miss during write word, but not on write half/byte
	-- it is divided in miss during read (miss_r) and miss on a write (miss_w),
	-- while both of then use the tag comparator output (miss_tag)
	miss_tag<=	'1' when (tag_in /= tag_out) else
				'0';

	miss_w	<=	'1' when (we = '1' AND miss_tag = '1' AND v_out = '1' AND sh_en = '0' AND sb_en = '0' AND mod_out = '1') else
				'0';

		-- except when the data is already in the cache, a write half/byte always does a miss
	miss_hb	<=	'1' when (we = '1' AND (v_out = '0' OR miss_tag = '1') AND (sh_en = '1' OR sb_en = '1'))  else
				'0';

	miss_r	<=	'1' when (we = '0' AND (miss_tag = '1' OR v_out = '0'))	else
				'0';

	miss	<=	'1' when ((miss_w = '1' OR miss_hb = '1' OR miss_r = '1') AND state_dcache = CA) else
				'0';

--------------------------------
--------------------------------
	-----
	-- colision detection, it only matters when theres is a store, and then a load
	-- in the same address, the store signal (write) is verified inside the cache, since
	-- it need temporary register to save useful data
	-- osb.1: in a MA state, its set high so we can bypass to the output the new data from main memory, saving
	-- one cycle of read
	col <=	'1' when ((index_access = index_op AND state_dcache = CA) OR w_ma = '1' OR wb_done = '1') else
			'0';

	------
	-- Info cache input and output
	v_out	<= info_out(ninfo-1);
	mod_out <= info_out(ninfo-2);
	tag_out <= info_out(ntag-1 downto 0);

	--
	tag_in	<=	addr_reg(n-1 downto n_addr+2);
				
	info_in	<= v_in & mod_in & tag_in;

	------
	-- Index (line access) and byte select (from the 2 lsb)
	index_access<=	addr(n_addr-1+2 downto 2);
	index_op 	<=	addr_reg(n_addr-1+2 downto 2)	when	(rst_cache = '0') else
					rst_index;

	byte_sel <= addr_reg(1 downto 0);

	------
	-- Data input
	dinb_t(31 downto 24)<=	data_i(31 downto 24)	when (byte_sel = "00") else
							data_i(15 downto 8)	when (byte_sel = "10") else
							data_i(7 downto 0);

	dinb_t(23 downto 16)<=	data_i(23 downto 16)	when (byte_sel = "00") else
							data_i(7 downto 0);

	dinb_t(15 downto 8)	<=	data_i(15 downto 8) 	when (byte_sel(0) = '0') else
							data_i(7 downto 0);

	dinb_t(7 downto 0) 	<=	data_i(7 downto 0);

	-----
	-- Data output, with 'byte_sel' based on the 2lsb of 'addr_reg'
	-- obs1.: output is disabled in case of a write or miss
	-- obs2.: output to ram is equal to output dcache in the state WB, so we can save the data to the main memory

	data_o(31 downto 16)	<=	douta(31 downto 16) when (oe = '1') else
							(others => 'Z');

	data_o(15 downto 8)	<=	douta(31 downto 24) when (oe = '1' AND byte_sel(1) = '1') else
							douta(15 downto 8)  when (oe = '1' AND byte_sel(1) = '0') else
							(others => 'Z');

	data_o(7 downto 0)	<=	douta(7 downto 0)   when (oe = '1' AND byte_sel = "00") else
							douta(15 downto 8)  when (oe = '1' AND byte_sel = "01") else
							douta(23 downto 16) when (oe = '1' AND byte_sel = "10") else
							douta(31 downto 24) when (oe = '1' AND byte_sel = "11") else
							(others => 'Z');

	------
	-- Write enable, with 'byte_sel' based on the 2lsb of 'addr_reg'
	web_t<=	"0000"	when (state_dcache /= CA OR  we = '0' OR (miss_w = '1' OR miss_hb = '1'))	else
			"1111"	when (sb_en = '0' AND sh_en = '0')							else -- SW
			"0001"	when (sb_en = '1' AND sh_en = '0' AND byte_sel = "00")		else -- SB
			"0010"	when (sb_en = '1' AND sh_en = '0' AND byte_sel = "01")		else -- SB
			"0100"	when (sb_en = '1' AND sh_en = '0' AND byte_sel = "10")		else -- SB
			"1000"	when (sb_en = '1' AND sh_en = '0' AND byte_sel = "11")		else -- SB
			"0011"	when (sb_en = '0' AND sh_en = '1' AND byte_sel(1) = '0')	else -- SH
			"1100"	when (sb_en = '0' AND sh_en = '1' AND byte_sel(1) = '1')	else -- SH			
			"0000";

	-- Data Cache
	dcache_i: dcache
	generic map(
		n_data => n_cache,
		n_addr => n_addr
	)
	port map(
		en_r	=> en_cache_r,
		clk		=> clk,
		col		=> col,
		web		=> web,
		addra	=> index_access,
		douta	=> douta,
		addrb	=> index_op,
		dinb	=> dinb
	);

	dcache_info_i: dcache_info
	generic map(
		n_data	=> ninfo,
		n_addr	=> n_addr
	)
	port map(
		en_r	=> en_cache_r,
		clk		=> clk,
		col		=> col,
		web		=> web_info,
		addra	=> index_access,
		douta	=> info_out,
		addrb	=> index_op,
		dinb	=> info_in
	);

end architecture behavior;
