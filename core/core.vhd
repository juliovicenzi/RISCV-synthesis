library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;

entity core is
	port
	(
		clk     	: in std_logic;
		rst		 	: in std_logic;
		intr		: in std_logic;
		-- cache to core stall signals
		wait_i		: in std_logic;		-- wait for instr.
		wait_d		: in std_logic;		-- wait for data
		-- core to cache stall/valid signals
		stall_icache: out std_logic;
		valid_iaddr	: out std_logic;							-- sinal de validade do endereo da icache
		valid_daddr	: out std_logic;							-- indica a vlidade do end. de dados, ativo em '1'
		sb_en	 	: out std_logic;							-- store byte enable
		sh_en	 	: out std_logic;							-- store enable enable
		we	     	: out std_logic;							-- write enable
		-- cache bus: data and address
		addr_dcache : out std_logic_vector(n-1 downto 0);		-- data address
		addr_icache : out std_logic_vector(n-1 downto 2);		-- instr. address
		data_icache : in std_logic_vector(n-1 downto 0);		-- instr. input
		data_dcache : inout std_logic_vector(n-1 downto 0)		-- data input/output
	);
end entity core;

architecture behavior of core is

	-- Reset, Flush and Stall flags
	signal	rst_core	:	std_logic := '0';
	signal	flush_branch:	std_logic;	-- flush from branch/jump
	signal	stall_id_if	:	std_logic;	-- stall from load-stall
	signal	bht_ready	:	std_logic;

	-- Exceptions signals/flags
	signal	flush_excp	:	std_logic;						-- flush from exception/interrupt
	signal	jalr_excp	:	std_logic;						-- flush flag from a bad instr. address created in a jalr
	signal	iaddr_excp	:	std_logic;						-- flush flag from a bad instr. address created in a jal or branch
	signal	daddr_excp	:	std_logic;						-- flush flag from a bad data address created in a load or store
	signal	m_tvec_base	:	std_logic_vector(n-1 downto 2);	-- trap handler address

	-- note: all record types are inside 'core_pkg.all'
	--- Pipeline Registers
	signal	ifid	:	regs_ifid;
	signal	idex	:	regs_idex;
	signal	exmem	:	regs_exmem;
	signal	memwb	:	regs_memwb;

	-- Data between stages
	signal	mem2if	:	data_mem2if;
	signal	ex2id	:	data_ex2id;
	signal	wb2id	:	data_wb2id;

	-- Data from stages
	signal	wb_data_rd		:	std_logic_vector(n-1 downto 0);
	signal	mem_pc_src		:	std_logic;
	signal	mem_branch_addr	:	std_logic_vector(n-1 downto 2);
	signal	mem_data_rd		:	std_logic_vector(n-1 downto 0);
	signal	mem_pc_offset	:	std_logic_vector(n-1 downto 2);

	--- Forward
	signal Forward_A	: std_logic_vector(1 downto 0);
	signal Forward_B	: std_logic_vector(1 downto 0);
	signal Forward_S	: std_logic;
	signal Forward_S_EX	: std_logic;
	signal fw_data_MEM	: std_logic_vector(n-1 downto 0);
	signal fw_data_WB	: std_logic_vector(n-1 downto 0);

	-- Core inputs and outputs
	signal	pc_fetch	:	std_logic_vector(n-1 downto 2);
	signal	instr_fetch	:	std_logic_vector(n-1 downto 0);
	signal	addr_data	:	std_logic_vector(n-1 downto 0);

begin

--------------------------
-- Core Reset Logic
--------------------------
-- wait for the BHT to be invalid before start running
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				rst_core <= '1';
			elsif (rst_core = '1' AND bht_ready = '1') then
				rst_core <= '0';
			end if;
		end if;
	end process;

--------------------------
-- Core inputs/outputs
--------------------------
	------------------------
	-- Instruction
	-- instr. fetched
	instr_fetch <= data_icache(n-1 downto 0);

	-- address
	addr_icache	<= pc_fetch;

	------------------------
	-- Data
	-- address
	addr_dcache	<= addr_data;

	-- write enable
	we <= exmem.mem_w AND (NOT(flush_excp));

	-- valid address flag
	valid_daddr <= (idex.mem_w OR idex.mem_r) AND (NOT(flush_excp OR flush_branch));

--------------------------
-- Flush/Stall Logic
--------------------------
	-- flush 		<= from stage1_IF
	-- stall_id_if	<= from stage2_ID
	process(clk , rst_core , flush_branch , flush_excp)
	begin
		if (rising_edge(clk) AND rst_core = '0' AND (flush_branch = '1' OR flush_excp = '1')) then
			-- report "Pipeline Flush" severity warning;
		end if;
	end process;

	-----------------------
	-- Exception/Interrupt Flush
	-- generated only in the Stage4 (MEM)
	jalr_excp	<=	'1'	when	(exmem.alu_result(1 downto 0) /= "00" AND exmem.branch_unc = '1' AND exmem.branch_src = '1') else
					'0';

	-- exception caused by bad instr. address (created in a branch or jump)
	iaddr_excp	<=	jalr_excp OR exmem.branch_excp;

	-- excpetion caused by bad data address (created in a load or store)
	daddr_excp	<=	exmem.mem_excp;

	-- output exception flag
	flush_excp	<=	((iaddr_excp OR daddr_excp OR exmem.instr_excp) AND exmem.excp_en) OR exmem.intr;

--------------------------
-- Forward
--------------------------
    fw_data_MEM <= mem_data_rd;
    fw_data_WB  <= wb_data_rd;

--------------------------
-- Signals between stages
--------------------------

	-- data from MEM to IF
	mem2if.branch_stt	<= exmem.branch_stt;
	mem2if.branch		<= exmem.branch AND (NOT(flush_excp));	-- prevents from updating the BHT on a exception trigger
	mem2if.pc_src		<= mem_pc_src;
	mem2if.branch_addr	<= mem_branch_addr;
	mem2if.pc_offset	<= mem_pc_offset;
	mem2if.pc			<= exmem.pc;

	-- data from EX to ID
	ex2id.mem_r		<=	idex.mem_r;
	ex2id.rd		<=	idex.rd;

	-- data from WB to ID
	wb2id.regfile_w	<=	memwb.regfile_w;
	wb2id.data_rd	<=	wb_data_rd;
	wb2id.rd		<=	memwb.rd;

--------------------------
-- instances
--------------------------
	-- stage1 IF instance
	stage_1: stage1_IF
	port map
	(
		rst				=> rst_core ,
		clk 		    => clk ,
		----------------------------
		valid_iaddr		=> valid_iaddr,
		stall_icache	=> stall_icache,
		wait_i			=> wait_i,
		wait_d			=> wait_d,
		----------------------------
		flush_branch	=> flush_branch ,
		flush_excp		=> flush_excp,
		m_tvec_base		=> m_tvec_base,
		stall_id_if     => stall_id_if ,
		bht_ready		=> bht_ready ,
		----------------------------
		mem2if			=> mem2if,
		----------------------------
		ifid 		    => ifid ,
		instr_fetch		=> instr_fetch ,
		pc_fetch	    => pc_fetch
	);

	-- stage2 ID instance
	stage_2: stage2_ID
	port map
	(
		rst			=>	rst_core,
		clk			=>	clk,
		--------------------------
		wait_d		=>	wait_d,
		--------------------------
		flush_branch=>	flush_branch,
		flush_excp	=>	flush_excp,
		stall_id_if	=>	stall_id_if,
		--------------------------
		ex2id		=>	ex2id,
		wb2id		=>	wb2id,
		--------------------------
		ifid		=>	ifid,
		idex		=>	idex
	);

	-- stage3 EX instance
	stage_3: stage3_EX
	port map
	(
		rst 		=> rst_core ,
		clk 		=> clk ,
		--------------------------
		wait_d		=> wait_d,
		--------------------------
		intr		=> intr,
		--------------------------
		flush_branch=> flush_branch,
		flush_excp	=> flush_excp,
		iaddr_excp	=> iaddr_excp,
		daddr_excp	=> daddr_excp,
		instr_excp	=> exmem.instr_excp,
		ext_intr	=> exmem.intr,
		m_epc_in	=> exmem.pc,
		m_tvec_base	=> m_tvec_base,
		--------------------------
		Forward_A 	=> Forward_A ,
		Forward_B 	=> Forward_B ,
		Forward_S_EX=> Forward_S_EX ,
		fw_data_MEM => fw_data_MEM ,
		fw_data_WB 	=> fw_data_WB ,
		--------------------------
		addr_data	=> addr_data ,
		idex 		=> idex ,
		exmem		=> exmem
	);

	-- stage4 instance
	stage_4: stage4_MEM
	port map
	(
		rst 		    => rst_core ,
		clk 		    => clk ,
		--------------------------
		wait_d			=> wait_d,
		--------------------------
		flush_excp		=> flush_excp,
		--------------------------
		Forward_S 	    => Forward_S ,
		fw_data_WB 	    => fw_data_WB ,
		--------------------------
		data_bus		=> data_dcache ,
		sb_en 		    => sb_en ,
		sh_en 		    => sh_en ,
		mem_pc_src		=> mem_pc_src,
		mem_branch_addr	=> mem_branch_addr,
		mem_data_rd		=> mem_data_rd,
		mem_pc_offset	=> mem_pc_offset,
		exmem 		    => exmem ,
		memwb 		    => memwb
	);

	-- stage5 instance
	stage_5: stage5_WB
	port map
	(
		wb_data_rd	=> wb_data_rd,
		memwb		=> memwb
	);

	-- forward unit instance
	forward: Forward_unit
	port map
	(
		RegFile_W_MEM 	 => exmem.regfile_w ,
		RegFile_W_WB 	 => memwb.regfile_w ,
		rs1_EX		     => idex.rs1 ,
		rs2_EX 		     => idex.rs2 ,
		rs2_MEM 	     => exmem.rs2 ,
		rd_MEM 		     => exmem.rd ,
		rd_WB 		     => memwb.rd ,
		-------------------------------
		Forward_A 	     => Forward_A ,
		Forward_B 	     => Forward_B ,
		Forward_S 	     => Forward_S ,
		Forward_S_EX     => Forward_S_EX
	);

end architecture behavior;
