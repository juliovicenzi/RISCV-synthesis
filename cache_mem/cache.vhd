library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cache_pkg.all;

entity cache is
	port(
		clk			: in std_logic;
		rst			: in std_logic;
		-- icache ports
		stall_icache: in std_logic;
		valid_iaddr	: in std_logic;
		addr_icache	: in std_logic_vector(n-1 downto 2);
		data_icache	: out std_logic_vector(n-1 downto 0);
		wait_i		: out std_logic;
		-- dcache ports
		valid_daddr	: in std_logic;
		we 			: in std_logic;
		sh_en		: in std_logic;
		sb_en		: in std_logic;
		addr_dcache	: in std_logic_vector(n-1 downto 0);
		data_dcache_i : in std_logic_vector(n-1 downto 0);
		data_dcache_o : out std_logic_vector(n-1 downto 0);
		wait_d		: out std_logic;
		-- cache control
		rst_cache	: out std_logic;
		cancel_ir	: out std_logic;
		ir_cache	: in std_logic;
		dr_cache	: in std_logic;
		drw_cache	: in std_logic;
		ready_cache	: in std_logic;
		ir_miss		: out std_logic;
		dr_miss		: out std_logic;
		dr_miss_hold: in std_logic;
		wb_en		: out std_logic;
		addr_ir		: out std_logic_vector(n-1 downto 0);
		addr_dr_drw	: out std_logic_vector(n-1 downto 0);
		din_cache	: in std_logic_vector(n-1 downto 0);
		dout_cache	: out std_logic_vector(n-1 downto 0)
	);
end entity cache;

architecture behavior of cache is

	---------------------
	-- ICACHE
	signal	miss_icache		:	std_logic;						-- '1' means a miss in the icache
	signal	ready_ir		:	std_logic;						-- '1' means the load request from the main mem to the icache is ready
	signal	addr_icache_reg	:	std_logic_vector(n2-1 downto 0);-- registered instr cache address
	signal	en_icache		:	std_logic;

---------------------
	-- DCACHE
	signal	miss_dcache		:	std_logic;						-- '1' means a miss in the dcache
	signal	ready_dr		:	std_logic;						-- '1' means the load request from the main mem to the dcache is ready
	signal	wb_en_t			:	std_logic;						-- '1' means a write back to the main memory
	signal	addr_wb			:	std_logic_vector(n-1 downto 0);	-- write back address, from cache to main memory
	signal	addr_dcache_reg	:	std_logic_vector(n-1 downto 0);	-- registered data cache address
	signal	wait_dcache		:	std_logic;

	---------------------
	-- FSM to reset the cache valid bit
	type state_fsm is (O_s , RST_s);
	signal rst_fsm		:	state_fsm := O_s;
	signal rst_cache_t	:	std_logic;
	signal rst_done		:	std_logic := '1';
	signal rst_index	:	std_logic_vector(12-1 downto 0) := (others => '0');
	signal we_req		:	std_logic;
	constant last_index	:	std_logic_vector(12-1 downto 0) := (others => '1');

begin

---------------------------------------------
---- Cancel Instruction Request in case of a invalid address (which only happens on pipeline flush inside the core)
	cancel_ir <=	'1' when (valid_iaddr = '0') else
					'0';

---------------------------------------------
---- Main Cache Control
	wb_en <= wb_en_t;

	-- addr used for data read request is equal to the registered one, except by the 2lsb,
	--since the data cache stores blocks of 32 bits (one word of the proc)
	-- obs1.: instructions are 32 bits long, so 2lsb of iaddr is (should) always be "00"
	addr_ir		<=	addr_icache_reg&"00";
	addr_dr_drw	<=	addr_wb		when (wb_en_t = '1') else
					addr_dcache_reg(n-1 downto 2)&"00";

---------------------------------------------
---- Instruction Cache
	ir_miss <=	miss_icache;

	ready_ir	<=	'1' when (ready_cache ='1' AND ir_cache = '1') else
					'0';

	en_icache	<=	'1'	when (stall_icache = '0' AND wait_dcache = '0') else
					'0';

---------------------------------------------
---- Data Cache
	dr_miss <=	miss_dcache;

	wait_d	<= wait_dcache;

	-- process to register the address
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (miss_dcache = '0' AND dr_cache = '0' AND drw_cache = '0' AND dr_miss_hold = '0') then
				addr_dcache_reg <= addr_dcache;

			end if;
		end if;
	end process;

	ready_dr	<=	'1' when (ready_cache = '1' AND (dr_cache = '1' OR drw_cache = '1')) else
					'0';

---------------------------------------------
---- Reset Cache
	we_req <= ready_dr OR ready_ir;

	process(clk)
	begin
		if (rising_edge(clk)) then
			CASE rst_fsm is
				---------------------
				when O_s =>
					if (rst = '1' AND rst_done = '0') then
						rst_fsm <= RST_s;
					elsif (we_req = '1' AND rst_done = '1') then
						rst_done <= '0';
					end if;
				---------------------
				when RST_s =>
					if (rst_index = last_index) then
						rst_done	<= '1';
						rst_index	<=	(others => '0');
						rst_fsm		<= O_s;
					else
						rst_index	<= std_logic_vector(unsigned(rst_index) + 1);
					end if;
				---------------------
			end CASE;
		end if;
	end process;

	rst_cache	<=	rst_cache_t;
	rst_cache_t <=	'1' when	(rst_fsm = RST_s) else
					'0';

---------------------------------------------
---------------------------------------------
-- port map

	-- Instruction Cache
	icache_ctrl_i: icache_ctrl
	port map(
		clk			=> clk,
		valid_addr	=> valid_iaddr,
		en			=> en_icache,
		------------------------------
		rst_cache	=> rst_cache_t,
		rst_index	=> rst_index,
		------------------------------
		wait_i		=> wait_i,
		addr		=> addr_icache(n-1 downto 2),
		addr_reg_out=> addr_icache_reg,
		dout		=> data_icache,
		------------------------------
		miss		=> miss_icache,
		ready_ir	=> ready_ir,
		din			=> din_cache
	);

	-- Data Cache
	dcache_ctrl_i: dcache_ctrl
	port map(
		clk			=> clk,
		valid_addr	=> valid_daddr,
		wait_d		=> wait_dcache,
		------------------------------
		rst_cache	=> rst_cache_t,
		rst_index	=> rst_index,
		------------------------------
		we			=> we,
		sh_en		=> sh_en,
		sb_en		=> sb_en,
	 	addr		=> addr_dcache,
		addr_reg	=> addr_dcache_reg,
		data_i		=> data_dcache_i,
		data_o 		=> data_dcache_o,
		--------------------------------
		miss_dcache	=> miss_dcache,
		wb_en		=> wb_en_t,
		addr_wb		=> addr_wb,
		din			=> din_cache,
		dout		=> dout_cache,
		ready_dr	=> ready_dr
	);

end architecture behavior;
