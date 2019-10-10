library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cache_pkg.all;

entity cache_ctrl is
	port(
		clk				: in std_logic;
		-- request status, connection with icache and dcache
		rst_cache		: in std_logic;		-- rst cache flag
		cancel_ir		: in std_logic;		-- cancel cache ctrl actual work
		ir_cache		: out std_logic;	-- cache ctrl working on inst request
		dr_cache		: out std_logic;	-- cache ctrl working on data read request
		drw_cache		: out std_logic;	-- cache ctrl working on data write request
		ready_cache		: out std_logic;	-- cache ctrl work is done for the respective signal (ir_cache / dr_cache / drw_cache)
		ir_miss			: in std_logic;		-- inst request from the cache
		dr_miss			: in std_logic;		-- data request from the cache
		dr_miss_hold	: out std_logic;	-- data request from the cache in hold, due to another one (ir_miss) already running
		wb_en			: in std_logic;		-- write back enable
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
end entity cache_ctrl;

architecture behavior of cache_ctrl is

	-----------
	-- FINITE STATE MACHINE
	type	state_m is (INIT , O , IR , DR , DR_W);
	signal	state_cache : state_m := INIT;

	signal	dr_miss_hold_t	:	std_logic;	-- hold a request from dcache, if another for icache is already on the run
	signal	ready_cache_t	:	std_logic;

	-- stop the running request from main memory, due to a pipeline flush (discard the current PC at IF stage, inside the core),
	-- or a memory page/burst mode running ahead from the desired address access
	signal	stop_req_dr		:	std_logic;
	signal	stop_req_ir		:	std_logic;
	signal	stop_req_ir_hold:	std_logic;
	signal	change_req		:	std_logic;

begin

---------------------------------------------
---------------------------------------------
---- FSM

	---- Cancel a ram operation
	-- since the data cache dont use page/burst access (for now), it will always stop the ram operation
	-- at the end of a read access (for data cache only)
	process(clk)
	begin
		if (rising_edge(clk)) then
			CASE state_cache is
				----------------------------------
				when DR =>
					if (ready_req = '1') then
						stop_req_dr <= '1';
					end if;
				----------------------------------
				when others =>
					stop_req_dr <= '0';
				----------------------------------
			end CASE;
		end if;
	end process;
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            CASE state_cache is
                when IR =>
                    if (ready_req = '1' AND dr_miss_hold_t = '1') then
                        change_req <= '1';
                    end if;
                when others =>
                    change_req <= '0';
            end CASE;
        end if;
	end process;

	-- wait for 1 cycle to see if another request happens
	process(clk)
		variable	hold	:	std_logic := '0';
		variable	count	:	integer range 0 to 3 := 0;
	begin
		if (rising_edge(clk)) then
			if (state_cache = IR AND ready_req = '1') then
				hold := '1';
			elsif (state_cache = O and hold = '1' AND count = 2) then
				hold  := '0';
				count := 0;
				stop_req_ir_hold <= '1';
			elsif (state_cache = O AND hold = '1' AND count /= 2) then
				count := count + 1;
			else
				hold := '0';
				count:= 0;
				stop_req_ir_hold <= '0';
			end if;
		end if;
	end process;
                        
    stop_req_ir <=  '1' when ((cancel_ir = '1' AND (state_cache = O OR state_cache = IR)) OR change_req = '1' OR stop_req_ir_hold = '1') else
                    '0';

	stop_req <= stop_req_dr OR stop_req_ir OR rst_cache;

	---- Hold a data request, in case of another one, for a instruction is already on the run
	process(clk)
	begin
		if (rising_edge(clk)) then
			CASE state_cache is
				---------------------------
				when IR =>
					if (dr_miss = '1') then
						dr_miss_hold_t <= '1';
					end if;
				---------------------------
				when DR | DR_W =>
					if (ready_req = '1') then
						dr_miss_hold_t <= '0';
					end if;
				----------------------------
				when INIT =>
					dr_miss_hold_t <= '0';
				----------------------------
				when others =>
					null;
				----------------------------
			end CASE;
		end if;
	end process;

	dr_miss_hold <= dr_miss_hold_t;

	with state_cache select
		request <=	'1' when IR | DR | DR_W,
					'0'	when others;

	-- RAM Addr Bus and Data Bus, and WE
	with state_cache select
		addr_bus <=	addr_ir		when	IR,
					addr_dr_drw	when	others;

	data_bus <=	din_cachectl when (state_cache = DR_W) else
				(others => 'Z');

	dout_cachectl <= data_bus;

	we_req	<=	'1' when (state_cache = DR_W) else
				'0';

	-- status output, to instr cache and data cache
	ir_cache	<= '1' when (state_cache = IR)	else '0';
	dr_cache	<= '1' when (state_cache = DR)	else '0';
	drw_cache	<= '1' when (state_cache = DR_W)else '0';

	with state_cache select
		ready_cache_t <= '1' when	IR | DR | DR_W,
						 '0' when	others;
	ready_cache	<=	ready_cache_t AND ready_req;

	-- FSM Process
	process(clk)
	begin
		if (rising_edge(clk)) then
			CASE state_cache is
				-------------------------------------
				when INIT =>
					if (rst_cache = '1') then
						null;
					else
						state_cache <= O;
					end if;
				-------------------------------------				
				when O =>
					if (rst_cache = '1') then
						null;
					
					elsif (dr_miss = '1') then	-- miss data cache takes priority over inst cache
						if (wb_en = '0') then
							state_cache <= DR;
						else
							state_cache <= DR_W;
						end if;

					elsif (ir_miss = '1') then
						state_cache <= IR;

					else
						state_cache <= O;

					end if;
				-------------------------------------
				when DR =>
					if (rst_cache = '1') then
						state_cache <= O;

					elsif (ready_req = '1') then

						if (ir_miss = '1') then
							state_cache <= IR;
						else
							state_cache <= O;
						end if;

					end if;
				-------------------------------------
				when DR_W =>
					if (rst_cache = '1') then
						state_cache <= O;

					elsif (ready_req = '1') then

						if (dr_miss = '1') then
							state_cache <= DR;
						elsif (ir_miss = '1') then
							state_cache <= IR;
						else
							state_cache <= O;
						end if;
						
					end if;
				-------------------------------------
				when IR =>
					if (rst_cache = '1') then
						state_cache <= O;

					elsif (cancel_ir = '1' OR ready_req = '1') then
						
						if (dr_miss_hold_t = '1') then
							if (wb_en = '0') then
								state_cache <= DR;
							else
								state_cache <= DR_W;
							end if;
						else
							state_cache <= O;
						end if;

					end if;
				-------------------------------------
			end CASE;
		end if;
	end process;

end architecture behavior;
