library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.core_pkg.all;

entity stage3_EX is
	port
	(
		rst			: in std_logic;
		clk			: in std_logic;
		-- cache signals
		wait_d		: in std_logic;
		-- interrupt flag
		intr		: in std_logic;
		-- stall/flush flags, and exceptions data
		flush_branch: in std_logic;
		flush_excp	: in std_logic;
		iaddr_excp	: in std_logic;
		daddr_excp	: in std_logic;
		instr_excp	: in std_logic;
		ext_intr	: in std_logic;
		m_epc_in	: in std_logic_vector(n-1 downto 2);
		m_tvec_base	: out std_logic_vector(n-1 downto 2);
		-- foward signals
		Forward_B	: in std_logic_vector(1 downto 0);		-- MUX B control signal
		Forward_A	: in std_logic_vector(1 downto 0);		-- MUX A control signal
		Forward_S_EX: in std_logic;							-- MUX S control signal
		fw_data_MEM	: in std_logic_vector(n-1 downto 0);	-- data from stage MEM
		fw_data_WB	: in std_logic_vector(n-1 downto 0);	-- data from stage WB
		-- stage pipeline register, ID/EX and EX/MEM
		addr_data	: out std_logic_vector(n-1 downto 0);	-- data memory address
		idex		: in regs_idex;
		exmem		: out regs_exmem
	);
end entity stage3_EX;

architecture behavior of stage3_EX is

	-- stage flush flag
	signal flush_ex	:	std_logic;

	-- temporary signal so we can read the data address to be used
	signal addr_data_t	:	std_logic_vector(n-1 downto 0);
	alias  addr_data_lsb:	std_logic_vector(1 downto 0) is addr_data_t(1 downto 0);

	-- ALU Opr B control signal is equal to ALU Op [0]
	alias idex_alu_oprb	:	std_logic	is	idex.alu_op(0);

	-- PC signals
	signal ex_pc_imm	: std_logic_vector(n-1 downto 0);
	alias  ex_pc_imm_lsb: std_logic_vector(1 downto 0) is ex_pc_imm(1 downto 0);
	signal ex_pc_t	 	: std_logic_vector(n-1 downto 0);

	-- ALU input and output
	signal opr_B		: std_logic_vector(n-1 downto 0);
	signal ex_alu_out	: std_logic_vector(n-1 downto 0);
	signal ex_alu_zero	: std_logic;
	-- ALU control signals
	signal fct3_dec		: std_logic_vector(2 downto 0);
	signal alu_ctrl		: std_logic_vector(3 downto 0);
	signal fct			: std_logic;                        -- instr. bit [30], decode ALU operations

	-- MUX A: select ALU input opr_A
	-- MUX B: select ALU input opr_B
	-- MUX S: select data to be stored on a STORE instr.
	-- MUX EXCP: select data to between pc+imm and a CSR (control/status register)
	signal MA_out	: std_logic_vector(n-1 downto 0);
	signal MB_out	: std_logic_vector(n-1 downto 0);
	signal MS_EX	: std_logic_vector(n-1 downto 0);
	signal M_EXCP	: std_logic_vector(n-1 downto 0);

	-- exception/interrupt registers and flags
	constant csr_in_zero:	std_logic_vector(n-1 downto 5) := (others => '0');
	signal	csr_in		:	std_logic_vector(n-1 downto 0);
	signal	csr_out		:	std_logic_vector(n-1 downto 0);
	signal	csr_sel		:	std_logic_vector(3 downto 0);
	signal	ex_excp_en	:	std_logic;
	signal	ex_intr_en	:	std_logic;
	signal	ex_intr		:	std_logic;
	signal	branch_excp	:	std_logic;
	signal	mem_w_excp	:	std_logic;
	signal	mem_h_excp	:	std_logic;
	signal	mem_excp	:	std_logic;

	-- control signals created due to the MRET instruction
	signal	ex_mret			:	std_logic;
	signal	ex_branch_unc	:	std_logic;

begin

	ex_intr <= ex_intr_en AND intr AND idex.pipe_fill;

	---------
	-- Stage EX flush
	flush_ex <= flush_branch OR flush_excp;

	-------------------------------------------------------
	-------------------------------------------------------
	-- CSR Logic

	-- create the ctrl signal MRET, and set the branch_unc flag (if mret = '1'), so we can use
	-- the same logic path to realize the jump to EPC, it doesnt check for SRET/URET
	ex_mret <=	'1'	when	(idex.funct3 = "000" AND idex.imm(1 downto 0) = "10") else
				'0';

	ex_branch_unc	<=	(ex_mret AND idex.csr_en) OR idex.branch_unc;

	-- choose the data input between data_rs1 and rs1
	csr_in	<=	MA_out	when	(idex.funct3(2) = '0')	else
				csr_in_zero & idex.rs1;

	-- select EPC if the SYS instr. is a MRET
	csr_sel <=	mepc_op		when	(ex_mret = '1')	else
				idex.imm(6)&idex.imm(2 downto 0);

	-- check for exceptions, and sends to the next stage, where it will trigger
	branch_excp	<=	'1'	when (ex_pc_imm_lsb /= "00" AND idex.branch_unc = '1') else
					'0';
	
	mem_w_excp	<=	'1'	when (addr_data_lsb /= "00" AND idex.funct3(1) = '1')		else
					'0';
	mem_h_excp	<=	'1'	when (addr_data_lsb(0) = '1' AND idex.funct3(1 downto 0) = "00")	else
					'0';

	mem_excp	<=	'1'	when ((mem_w_excp = '1' OR mem_h_excp = '1') AND (idex.mem_r = '1' OR idex.mem_w = '1')) else
					'0';

	-------------------------------------------------------
	-------------------------------------------------------
	-- dedicated adder for memory address
	addr_data_t <= std_logic_vector(unsigned(MA_out) + unsigned(idex.imm));
	addr_data	<= addr_data_t;

	-- PC + immediate
	ex_pc_t		<= idex.pc&"00";
	ex_pc_imm	<= std_logic_vector(unsigned(ex_pc_t) + unsigned(idex.imm(n-1 downto 0)));

	-- MUX excp do datapath
	M_excp <=	csr_out		when	(idex.csr_en = '1') else
				ex_pc_imm;

	-------------------------------------------------------
	------- ALU
	----- MUX A, define opr_A
    MA_out <= idex.data_rs1	when (Forward_A = "00") else
              fw_data_WB	when (Forward_A = "01") else
              fw_data_MEM;	--	when (Forward_A = "10")

	----- MUX 2 and MUX B, define opr_B
	MB_out	<=	idex.data_rs2	when (Forward_B = "00") else
            	fw_data_WB		when (Forward_B = "01") else
				fw_data_MEM; -- when (Forward_B = "10");
		-- MUX2
	opr_B	<=	MB_out	when (idex_alu_oprb = '0') else
		 		idex.imm;	-- when (idex_alu_oprb = '1');

 	----- MUX S EX, define data memory input
	MS_EX <= 	idex.data_rs2	when (Forward_S_EX = '0') else
	         	fw_data_WB; --   when (Forward_S_EX = '1');

	-- ALU control unit
	fct <=	'0'	when	(idex.alu_op = alu_add OR (idex.alu_op = alu_misi AND idex.funct3(0) = '0')) else
			idex.imm(10);

	fct3_dec <= funct3_add	when	(idex.alu_op = alu_add)								else
				funct3_slt	when	(idex.alu_op = alu_branch AND idex.funct3(1) = '0')	else
				funct3_sltu	when	(idex.alu_op = alu_branch AND idex.funct3(1) = '1')	else
				idex.funct3;

	alu_ctrl <= 
				-- Arith Operations => "00--"
				"0000" when (fct3_dec = funct3_add AND fct = '0')	else -- ADD
				"0001" when	(fct3_dec = funct3_add AND fct = '1')	else -- SUB
				"0010" when (fct3_dec = funct3_sll)               	else -- SLL
				"0011" when (fct3_dec = funct3_slt)					else -- STL
				-- Logic Operations => "01--"
                "0100" when (fct3_dec = funct3_or)					else -- OR
                "0101" when (fct3_dec = funct3_and)					else -- AND
                "0110" when (fct3_dec = funct3_xor)					else -- XOR
				"0111" when (fct3_dec = funct3_sltu)				else -- STLU
				-- Shift Operations => "100-"
				"1000" when (fct3_dec = funct3_srl AND fct = '0') 	else -- SRL
				"1001" when (fct3_dec = funct3_srl AND fct = '1')	else -- SRA
				-- Dont Care
                "----";

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-------------- Pipeline Register
	-- on a reset or flush, only the control signals are used (the ones needed)
	process (clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				exmem.branch_stt	<=	(others => '0');
				exmem.regfile_w		<=	'0';
				exmem.branch_unc	<=	'0';
				exmem.branch		<=	'0';
				exmem.mem_r			<=	'0';
				exmem.mem_w			<=	'0';
				exmem.excp_en		<=	'0';
				exmem.intr			<=	'0';
				exmem.branch_excp	<=	'0';
				exmem.mem_excp		<=	'0';
				exmem.instr_excp	<=	'0';

			elsif (wait_d = '1') then
				null;

			elsif (flush_ex = '1') then
				exmem.branch_stt	<=	(others => '0');
				exmem.regfile_w		<=	'0';
				exmem.branch_unc	<=	'0';
				exmem.branch		<=	'0';
				exmem.mem_r			<=	'0';
				exmem.mem_w			<=	'0';
				exmem.excp_en       <=  '0';
				exmem.intr          <=  '0';
				exmem.branch_excp	<=	'0';
				exmem.mem_excp		<=	'0';
				exmem.instr_excp	<=	'0';

			else
				-- control signals
				exmem.branch_stt	<=	idex.branch_stt;
				exmem.regfile_w		<=	idex.regfile_w;
				exmem.regfile_src0	<=	idex.regfile_src0;
				exmem.branch_unc	<=	ex_branch_unc;
				exmem.branch		<=	idex.branch;
				exmem.branch_src	<=	idex.branch_src;
				exmem.mem_r			<=	idex.mem_r;
				exmem.mem_w			<=	idex.mem_w;
				exmem.excp_en		<=	ex_excp_en;
				exmem.intr			<=	ex_intr;
				exmem.branch_excp	<=	branch_excp;
				exmem.mem_excp		<=	mem_excp;
				exmem.instr_excp	<=	idex.instr_excp;
				-- others
				exmem.data_reg		<= M_excp;
				exmem.pc			<= idex.pc;
				exmem.alu_result	<= ex_alu_out;
				exmem.alu_zero		<= ex_alu_zero;
				exmem.funct3		<= idex.funct3;
				exmem.data_rs2  	<= MS_EX;
				exmem.rs2			<= idex.rs2;
				exmem.rd			<= idex.rd;

			end if;
		end if;
	end process;

---------------------------------------------------
---------------------------------------------------
	-- CSR unit instance
	csr_unit_i: csr_unit
	port map
	(
		rst			=> rst,
		clk			=> clk,
		-------------------
		wait_d		=> wait_d,
		flush		=> flush_ex,
		flush_excp	=> flush_excp,
		iaddr_excp	=> iaddr_excp,
		daddr_excp	=> daddr_excp,
		instr_excp	=> instr_excp,
		ext_intr	=> ext_intr,
		-------------------
		csr_en		=> idex.csr_en,
		csr_op		=> idex.funct3,
		csr_sel		=> csr_sel,
		-------------------
		m_epc_in	=> m_epc_in,
		m_tvec_base	=> m_tvec_base,
		intr_en		=> ex_intr_en,
		excp_en		=> ex_excp_en,
		csr_in		=> csr_in,
		csr_out		=> csr_out
	);

	-- ALU instance
	ALU_i: ALU
	port map
	(
		opr_A 	=> MA_out ,
		opr_B 	=> opr_B ,
		ALU_ctrl=> alu_ctrl ,
		-----------------------
		ALU_out => ex_alu_out ,
		ALU_zero=> ex_alu_zero
	);

end architecture behavior;
