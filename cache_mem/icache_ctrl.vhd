library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cache_pkg.all;

entity icache_ctrl is
	port
	(
		clk			: in std_logic;
		valid_addr	: in std_logic;
		en			: in std_logic;
		-- cache reset
		rst_cache	: in std_logic;
		rst_index	: in std_logic_vector(11 downto 0);
		-- connections with the core, instruction cache
		wait_i		: out std_logic;
		dout		: out std_logic_vector(n-1 downto 0);
		addr		: in std_logic_vector(n2-1 downto 0);
		addr_reg_out: out std_logic_vector(n2-1 downto 0);
		-- connections with the main cache ctrl
		miss		: out std_logic;	-- miss instruction cache
		ready_ir	: in std_logic;		-- '1' means the instruction is ready to be writen into the cache
		din			: in std_logic_vector(n-1 downto 0)
	);
end entity icache_ctrl;

architecture behavior of icache_ctrl is

	---------------------
	-- I CACHE
	constant n_icache	:	integer := 32;
	constant n_addr		:	integer := 12;

	signal	index	:	std_logic_vector(n_addr-1 downto 0);
	signal	we		: 	std_logic;
	signal	miss_tag	:	std_logic;
	signal	miss_t	:	std_logic;
	signal	miss_bit:	std_logic;	-- ff to hold miss value, so we dont create a delay path like:
									-- icache_info => tag_out == tag_in (?) => miss_t => MUX index => icache ADDR

		-- I CACHE - INFO
	constant ntag	:	integer := n2-n_addr;
	constant ninfo	:	integer := ntag+1;	-- tag + valid bit

	signal	we_info		:	std_logic;
	signal	tag_in		:	std_logic_vector(ntag-1 downto 0);
	signal	tag_out		:	std_logic_vector(ntag-1 downto 0);
	signal 	v_in		:	std_logic;
	signal	v_out		:	std_logic;
	signal	din_info	:	std_logic_vector(ninfo-1 downto 0);
	signal	dout_info	:	std_logic_vector(ninfo-1 downto 0);

	-- temporary address regs.
	signal	addr_reg	:	std_logic_vector(n2-1 downto 0) := (others => '0'); 

	-- enable access flag
	signal	en_cache	:	std_logic;

begin

	-- cache access enable
	en_cache <= '0'	when	(en = '0' OR (miss_t = '1' AND ready_ir = '0')) else
				'1';

	-- Temporary regs. holding the access address, so we can compare with the
	-- output tag in the next cycle
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (miss_t = '0') then
				addr_reg <= addr;
			end if;
		end if;
	end process;
	addr_reg_out <= addr_reg;

	-- Instruction Cache Ctrl Signals
	wait_i	<=	'1' when (miss_t = '1') else
				'0';
	------
	-- Instruction input and output, on the 'port map'
	-- dout <= dout;
	-- din <= din;
	index <=	rst_index					when	(rst_cache = '1')	else
				addr(n_addr-1 downto 0)		when	(miss_bit = '0')	else
				addr_reg(n_addr-1 downto 0);

	------
	-- Tag input and output, on the 'port map'
	tag_in 	<=	addr_reg(n2-1 downto n_addr);
	tag_out	<=	dout_info(ntag-1 downto 0);

	v_in		<=	'0'	when	(rst_cache = '1') else
					'1';
	v_out		<= dout_info(ninfo-1);

	din_info	<= v_in & tag_in;

	------
	-- Miss Instruction Cache
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (miss_bit = '1' AND ready_ir = '1') then
				miss_bit <= '0';
			elsif (miss_bit = '0' OR valid_addr = '0') then
				miss_bit <= miss_t;
			end if;
		end if;
	end process;

	miss	<=	miss_bit;

	miss_tag<=	'1'	when	(tag_in /= tag_out OR v_out = '0')	else
				'0';
	miss_t 	<=	'1'	when	((miss_tag = '1' OR miss_bit = '1') AND valid_addr = '1' AND rst_cache = '0') else
				'0';

	we		<=	ready_ir when (rst_cache = '0') else
				'0';
	we_info	<=	ready_ir when (rst_cache = '0') else
				'1';

--------------------------------
--------------------------------
-- port map

	-- Instruction Cache
	icache_i: icache
	generic map(
		n_data => n_icache,
		n_addr => n_addr
	)
	port map(
		clk		=> clk,
		en		=> en_cache,
		we		=> we,
		addr	=> index,
		din		=> din,
		dout	=> dout
	);

	icache_info_i: icache_info
	generic map(
		n_data => ninfo,
		n_addr => n_addr
	)
	port map(
		clk		=> clk,
		en		=> en_cache,
		we		=> we_info,
		addr	=> index,
		din		=> din_info,
		dout	=> dout_info
	);

end architecture behavior;
