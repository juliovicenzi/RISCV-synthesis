library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;

entity core_tb is
end entity;

architecture test of core_tb is

	-- RV32I Core
	COMPONENT core
		port(
			clk			: in std_logic;
			rst			: in std_logic;
			intr		: in std_logic;
			we			: out std_logic;
			stall_icache: out std_logic;
			valid_iaddr	: out std_logic;
			valid_daddr	: out std_logic;
			wait_i		: in std_logic;
			wait_d		: in std_logic;
			sb_en		: out std_logic;
			sh_en		: out std_logic;
			addr_icache	: out std_logic_vector(n-1 downto 2);
			data_icache	: in std_logic_vector(n-1 downto 0);
			addr_dcache	: out std_logic_vector(n-1 downto 0);
			data_dcache_i	: in std_logic_vector(n-1 downto 0);
            data_dcache_o	: out std_logic_vector(n-1 downto 0)
		);
	end COMPONENT core;
    
	-- Instruction and Data Cache top module
	COMPONENT cache is
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
	end COMPONENT cache;

	-- Cache Memory Control
	COMPONENT cache_ctrl is
		port(
			clk				: in std_logic;
			-- request status, connection with icache and dcache
			rst_cache		: in std_logic;
			cancel_ir		: in std_logic;
			ir_cache		: out std_logic;
			dr_cache		: out std_logic;
			drw_cache		: out std_logic;
			ir_miss			: in std_logic;
			dr_miss			: in std_logic;
			dr_miss_hold	: out std_logic;
			wb_en			: in std_logic;
			ready_cache		: out std_logic;
			addr_ir			: in std_logic_vector(n-1 downto 0);
			addr_dr_drw		: in std_logic_vector(n-1 downto 0);
			din_cachectl	: in std_logic_vector(n-1 downto 0);
			dout_cachectl	: out std_logic_vector(n-1 downto 0);
			-- connections with the main mem
			stop_req		: out std_logic;
			we_req			: out std_logic;
			ack_req			: in std_logic;
			ready_req		: in std_logic;
			request			: out std_logic;
			addr_bus		: out std_logic_vector(n-1 downto 0);
			data_bus		: inout std_logic_vector(n-1 downto 0)
		);
    end COMPONENT cache_ctrl;
    
	signal rst : std_logic := '1';
	signal clk : std_logic := '0';
	signal intr : std_logic := '0';
	
    	-- System reset
	signal	rst_int	:	std_logic := '1';
	signal	rst_db	:	std_logic;
	signal	rst		:	std_logic;

	-- Core control to/from Cache
	signal	stall_icache:	std_logic;
	signal	valid_iaddr	:	std_logic;
	signal	wait_i		:	std_logic;
	signal	valid_daddr	:	std_logic;
	signal	wait_d		:	std_logic;
	signal	sb_en		:	std_logic;
	signal	sh_en		:	std_logic;
	signal	we			:	std_logic;

	-- Cache
	signal	addr_icache	:	std_logic_vector(n-1 downto 2);
	signal	data_icache	:	std_logic_vector(n-1 downto 0);
	signal	addr_dcache	:	std_logic_vector(n-1 downto 0);
	signal	data_dcache	:	std_logic_vector(n-1 downto 0);

	-- Cache Control
	signal	rst_cache	:	std_logic;
	signal	cancel_ir	:	std_logic;
	signal	ir_cache	:	std_logic;
	signal	ir_miss		:	std_logic;
	signal	addr_ir		:	std_logic_vector(n-1 downto 0);

	signal	dr_cache	:	std_logic;
	signal	drw_cache	:	std_logic;
	signal	dr_miss		:	std_logic;
	signal	dr_miss_hold:	std_logic;
	signal	wb_en		:	std_logic;
	signal	addr_dr_drw	:	std_logic_vector(n-1 downto 0);

	signal	ready_cache	:	std_logic;
	signal	din_cache	:	std_logic_vector(n-1 downto 0);
	signal	dout_cache	:	std_logic_vector(n-1 downto 0);
	
    -------------------------------------------------------
    --clock period 
	constant clk_half_period: time:= 5 ns;
    constant clk_period: time := 2*clk_half_period;
    
begin
	rst <= '0' after 4*clk_half_period;
	clk <= not clk after clk_half_period;
	
	core_i:	core
	port map(
		rst 	   	=> rst ,
		clk 	   	=> clk ,
		intr		=> io_intr,
		we 		   	=> we ,
		stall_icache=> stall_icache,
		valid_iaddr	=> valid_iaddr,
		valid_daddr	=> valid_daddr,
		wait_i		=> wait_i,
		wait_d		=> wait_d,
		sb_en 	   	=> sb_en ,
		sh_en	   	=> sh_en ,
		addr_icache	=> addr_icache ,
		data_icache	=> data_icache ,
		addr_dcache	=> addr_dcache , 
		data_dcache_i => data_dcache_i,
        data_dcache_o => data_dcache_o
	);
    
    	-- instruction and data cache top module instance
	cache_i: cache
	port map(
		clk		=> clk,
		rst		=> rst,
		-------------------
		stall_icache=> stall_icache,
		valid_iaddr	=> valid_iaddr,
		addr_icache	=> addr_icache,
		data_icache	=> data_icache,
		wait_i		=> wait_i,
		-------------------
		valid_daddr	=> valid_daddr,
		we 			=> we,
		sh_en		=> sh_en,
		sb_en		=> sb_en,
		addr_dcache	=> addr_dcache,
		data_dcache_i	=> data_dcache_i,
        data_dcache_o => data_dcache_o,
		wait_d		=> wait_d,
		-------------------
		rst_cache	=> rst_cache,
		cancel_ir	=> cancel_ir,
		ir_cache	=> ir_cache,
		dr_cache	=> dr_cache,
		drw_cache	=> drw_cache,
		ir_miss		=> ir_miss,
		dr_miss		=> dr_miss,
		dr_miss_hold=> dr_miss_hold,
		wb_en		=> wb_en,
		ready_cache	=> ready_cache,
		addr_ir		=> addr_ir,
		addr_dr_drw	=> addr_dr_drw,
		din_cache	=> din_cache,
		dout_cache	=> dout_cache
	);

	-- cache ctrl instance
	cache_ctrl_i: cache_ctrl
	port map(
		clk 	   	=> clk ,
		-----------------------------
		rst_cache	=> rst_cache,
		cancel_ir	=> cancel_ir,
		ir_cache	=> ir_cache,
		dr_cache	=> dr_cache,
		drw_cache	=> drw_cache,
		ir_miss		=> ir_miss,
		dr_miss		=> dr_miss,
		dr_miss_hold=> dr_miss_hold,
		wb_en		=> wb_en,
		ready_cache	=> ready_cache,
		addr_ir		=> addr_ir,
		addr_dr_drw	=> addr_dr_drw,
		din_cachectl=> dout_cache,
		dout_cachectl=>din_cache,
		-----------------------------
		stop_req	=> stop_req,
		ack_req		=> ack_req,
		ready_req	=> ready_req,
		request		=> request,
		we_req		=> we_req,
		addr_bus	=> addr_bus,
		data_bus	=> data_bus
	);
    
end architecture;