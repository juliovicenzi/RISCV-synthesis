library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;

-- Control unit: decode the instruction opcode (6:2) for the control signals through the datapath, and
-- also detects invalid instructions, checking the instr. 2 lsb.
-- All opcode fields are inside the 'core_pkg'
entity Ctrl_unit is
	port
	(
		id_opcode	: in std_logic_vector(6 downto 0);
		-- control output
		regfile_w	: out std_logic;
		regfile_src0: out std_logic;
		branch_unc	: out std_logic;
		branch		: out std_logic;
		branch_src	: out std_logic;
		mem_r		: out std_logic;
		mem_w		: out std_logic;
		csr_en		: out std_logic;
		alu_op		: out std_logic_vector(1 downto 0);
		instr_excp	: out std_logic
	);
end entity Ctrl_unit;

architecture behavior of Ctrl_unit is

	alias	opcode	:	std_logic_vector(4 downto 0) is	id_opcode(6 downto 2);
	alias	lsb_op	:	std_logic_vector(1 downto 0) is	id_opcode(1 downto 0);
	
	-- instruction type
	signal	instr_name : string (1 to 6);
	
	-- control signals to be disabled if detected a invalid instruction
	signal	inv_regfile_w	:	std_logic;
	signal	inv_branch_unc	:	std_logic;
	signal	inv_branch		:	std_logic;
	signal	inv_mem_r		:	std_logic;
	signal	inv_mem_w		:	std_logic;
	signal	inv_csr_en		:	std_logic;
	signal	val_instr		:	std_logic;
	
begin
	------------------------------
    -- Invalid Instruction Logic
	------------------------------
	val_instr	<=	'1'	when (lsb_op = "11") else
					'0';
	instr_excp	<=	NOT(val_instr);

    ------------------------------
    -- Stage WB
	------------------------------
	with opcode(3 downto 0) select
		inv_regfile_w	<=	'0'	when	"1000",	-- store_op[3:0] = branch_op[3:0] = "1000"
							'1'	when	others;
		regfile_w	<=	inv_regfile_w AND val_instr;

    ------------------------------
    -- Stage MEM
	------------------------------
	with opcode select
		regfile_src0<=	'0'	when	jalr_op | jal_op | auipc_op | lui_op | system_op,
						'1'	when	others;

	with opcode select
		inv_branch_unc	<=	'1'	when	jal_op | jalr_op,
							'0'	when	others;
		branch_unc	<=	inv_branch_unc AND val_instr;				

	with opcode select
		inv_branch	<=	'1'	when	branch_op,
						'0'	when	others;
		branch	<=	inv_branch AND val_instr;

	with opcode select
		branch_src	<=	'1'	when	jalr_op,
						'0'	when	others;

	with opcode select
		inv_mem_r	<=	'1'	when	load_op,	-- funct3 define LW/LH/LB, in MEM stage
						'0'	when	others;
		mem_r	<=	inv_mem_r AND val_instr;

	with opcode select
		inv_mem_w	<=	'1'	when	store_op,	-- funct3 define SW/SH/SB, in MEM stage
						'0'	when	others;
		mem_w	<=	inv_mem_w AND val_instr;

    ------------------------------
    -- Stage EX
	------------------------------
	with opcode select
		inv_csr_en	<=	'1'	when	system_op,	-- funct3 define the atomic operation above the CSRegister
						'0'	when	others;
		csr_en	<=	inv_csr_en AND val_instr;

	with opcode select
		alu_op 	<=	alu_misr	when	opreg_op,	-- ALU-funct3 => reg to reg op
					alu_misi	when	opimm_op,	-- ALU-funct3 => reg to imm op
					alu_branch	when	branch_op,	-- branch-funct3
					alu_add		when	others;		-- ADD

    ------------------------------
    -- String (SIM only)
	------------------------------
	with opcode select
		instr_name <=	"SYSTEM"    when    system_op,
                        "LUI___"	when	lui_op,
						"AUIPC_"	when	auipc_op,
						"JAL___"	when	jal_op,
						"JALR__"	when	jalr_op,
						"BRANCH"	when	branch_op,
						"LOAD__"	when	load_op,
						"STORE_"	when	store_op,
						"REGIMM"	when	opimm_op,
						"REGREG"	when	opreg_op,
						"___INV"	when	others;


end architecture behavior;
