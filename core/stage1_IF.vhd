library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.core_pkg.all;

entity stage1_IF is
	port
	(
		rst			: in std_logic;
		clk			: in std_logic;
		-- cache signals
		valid_iaddr	: out std_logic;	
		stall_icache: out std_logic;
		wait_i		: in std_logic;
		wait_d		: in std_logic;
		-- stage stall/flush flag, and also exceptions data
		flush_branch: out std_logic;
		flush_excp	: in std_logic;
		m_tvec_base	: in std_logic_vector(n-1 downto 2);
		stall_id_if	: in std_logic;
		bht_ready	: out std_logic;
		-- signals from stage MEM
		mem2if		: in data_mem2if;
		-- stage pipeline register, and currente pc/instr values
		ifid		: out regs_ifid;	-- pipeline register
		instr_fetch	: in std_logic_vector(n-1 downto 0);
		pc_fetch	: out std_logic_vector(n-1 downto 2)
	);
end entity stage1_IF;

architecture behavior of stage1_IF is

	-- Pipeline empty flag: '0' = empty
	signal pipeline_fill : std_logic;

	-- 12 lsb from the NOP instr.
    constant NOP_instr : std_logic_vector(11 downto 0) := x"013";

	-- MUX 0: define the PC input
	-- MUX P: define the instr. fetch address
	-- MUX PC: define the PC input as the CSR MTVEC output in case of a exception/interrupt
	signal M0_out	: std_logic_vector(n-1 downto 2);
	signal MP_out	: std_logic_vector(n-1 downto 2);
	signal M_PC		: std_logic_vector(n-1 downto 2);
	alias  pc_next	: std_logic_vector(n-1 downto 2) is M_PC;	-- PC input

	-- Program Counter
	signal	PC			: std_logic_vector(n-1 downto 2);	-- PC register
	signal	pc_offset	: std_logic_vector(n-1 downto 2);	-- PC + 4
	signal	pc_we		: std_logic;						-- PC write enable
	signal	pc_temp		: std_logic_vector(n-1 downto 2);	-- PC temporary register (save the instr fetch address from the previous clk cycle)

	-- Predic Unit
	signal if_branch_stt	:	std_logic_vector(2 downto 0);	-- predict output, send to MEM stage for verification
	signal taken_t			: std_logic;						-- temp signal, disabled through 'pipeline_fill' flag
	signal taken	   		: std_logic;						-- '1' means a taken action from the branch predict unit
	signal miss_predict		: std_logic;						-- '1' means the predict unit make a wrong predict
	signal miss_taken		: std_logic;						-- verify if the <miss_predict='1'> was upon a <taken='1> OR <taken='0'>
	signal taken_target		: std_logic_vector(n-1 downto 2);	-- predict target, used when <taken = '1'>

	-- flush and stall flags
	signal flush_branch_t	: std_logic;
	signal flush_if			: std_logic;
	signal stall			: std_logic;

	-- simulation only
	signal pc_sim : std_logic_vector(n-1 downto 0);

begin

	-- predict taken flag
	taken	<=	taken_t when (pipeline_fill = '1') else
				'0';

------------------------------------------------------------------------------
------------------------------------------------------------------------------
	-- cache valid/stall flag
	valid_iaddr		<=	'0' when (flush_if = '1' OR pipeline_fill = '0') else
						'1';
	stall_icache	<=	'0'	when (stall_id_if = '0') else
						'1';

	-- stage stall/flush flags
	flush_branch	<=	flush_branch_t;
	flush_branch_t	<=	miss_predict;
	flush_if 		<=	flush_branch_t OR flush_excp;

	stall	<= stall_id_if OR wait_d;

	-- instr. fetch address
	MP_out	<=	taken_target when (taken = '1')	else
				PC;
	pc_fetch<=	MP_out;

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-------------- Program Counter
	-- Program Counter write enable
	-- note: pc_we must not be disable when 'wait_i = '1'' (miss instr cache), as it's possible
	-- to have a branch/jump on the MEM stage, wich would write into it
	pc_we <=	'0' when (stall = '1' OR (wait_i = '1' AND flush_if = '0')) else
				'1';

	pc_offset <= std_logic_vector(unsigned(MP_out) + 1);	-- +4 (2 lsb ignored)

	-- MUX 0 :	choose the PC input between PC+4, branch target from MEM stage, or
	-- PC+4 from stage MEM (needed if the predict unit miss)
	-- Jumps are always predicted as not_taken, and as a result, will trigger a miss_predict (value '1')
	M0_out	<=  mem2if.pc_offset	when (miss_predict = '1' AND miss_taken = '1') else
				mem2if.branch_addr	when (miss_predict = '1' AND miss_taken = '0') else
				pc_offset;

	--
	M_PC	<=	M0_out		when	(flush_excp = '0') else
				m_tvec_base;

	-- Program Counter Register
	ProgramCounter:	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				PC <= (others => '0');

			elsif (pc_we = '1') then
				PC <= pc_next;

			end if;
		end if;
	end process ProgramCounter;

	-- Program Counter Temporary Register
	ProgramCounter_Temp:process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				pc_temp <= (others => '0');

			elsif (stall = '0' AND wait_i = '0') then
				pc_temp <= MP_out;

			end if;
		end if;
	end process ProgramCounter_Temp;

	----------------------------------------------------------------------
	----------------------------------------------------------------------
	----------------------------------------------------------------------
	-- IGNORED BY SYNTHESIS
	-- synthesis translate_off
	pc_sim <=  pc&"00";
	-- synthesis translate_on
	----------------------------------------------------------------------
	----------------------------------------------------------------------
	----------------------------------------------------------------------

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-------------- Pipeline Register
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				ifid.branch_stt			<= (others => '0');
				ifid.pipe_fill			<= '0';
				ifid.pc 				<= (others => '0');
				ifid.instr(n-1 downto 0)<=	x"0000_0"&NOP_instr;

			elsif (stall = '1') then
				null;

			elsif (flush_if = '1' OR pipeline_fill = '0' OR wait_i = '1') then
				ifid.branch_stt			<= (others => '0');
				ifid.pipe_fill			<= '0';
				ifid.instr(11 downto 0) <= NOP_instr;

			else
				ifid.branch_stt	<= if_branch_stt;
				ifid.pipe_fill	<=	'1';
				ifid.pc			<= pc_temp(n-1 downto 2);
				ifid.instr		<= instr_fetch;

			end if;
		end if;
	end process;

	-- pipeline empty flag, when '0' it means nothing is running in the moment
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1' OR flush_if = '1') then
				pipeline_fill <= '0';
			else
				pipeline_fill <= '1';
			end if;
		end if;
	end process;

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
	-- prediction_unit instance
	Predict_unit_i: Predict_unit
	port map
	(
		rst			=> rst ,
		clk			=> clk ,
		stall		=> stall,
		--------------------------------
		Branch		=> mem2if.branch ,
		PC_Src		=> mem2if.pc_src ,
		--------------------------------
		taken		=> taken_t ,
		miss_taken	=> miss_taken ,
		miss_predict=> miss_predict ,
		bht_ready	=> bht_ready,
		--------------------------------
		state_read	=> if_branch_stt,
		state_write	=> mem2if.branch_stt,
		pc_read		=> MP_out ,
		pc_write	=> mem2if.pc ,
		target_in	=> mem2if.branch_addr ,
		target_out	=> taken_target
	);

end architecture behavior;
