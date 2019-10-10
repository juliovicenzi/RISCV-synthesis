library ieee;
use ieee.std_logic_1164.all;

package core_pkg is

-----------------------------------------------------------------
--- Instruction info
-----------------------------------------------------------------
	constant n_alig		: integer := 2;			-- instr. align, 4 bytes boundary
	constant n          : integer := 32;		-- core word size, 4 bytes
	constant n_pc		: integer:= n-n_alig;	-- pc length without the byte offset
	constant n_reg      : integer := 5;			-- register file size => 2^(n_reg) = 32

	-- Instr. opcode => instr[6:2]
	constant lui_op		: std_logic_vector(6 downto 2) := "01101";
	constant auipc_op	: std_logic_vector(6 downto 2) := "00101";
	constant jal_op		: std_logic_vector(6 downto 2) := "11011";
	constant jalr_op	: std_logic_vector(6 downto 2) := "11001";
	constant branch_op	: std_logic_vector(6 downto 2) := "11000";
	constant load_op	: std_logic_vector(6 downto 2) := "00000";
	constant store_op	: std_logic_vector(6 downto 2) := "01000";
	constant opimm_op	: std_logic_vector(6 downto 2) := "00100";
	constant opreg_op	: std_logic_vector(6 downto 2) := "01100";
	constant system_op	: std_logic_vector(6 downto 2) := "11100";

	---------------------------------------------
	-- CSR location, and operation
	constant mstatus_op	: std_logic_vector(3 downto 0) := "0000";
	constant mie_op		: std_logic_vector(3 downto 0) := "0100";
	constant mtvec_op	: std_logic_vector(3 downto 0) := "0101";
	constant mepc_op	: std_logic_vector(3 downto 0) := "1001";
	constant mcause_op	: std_logic_vector(3 downto 0) := "1010";

	constant csr_RW		: std_logic_vector(2 downto 0) := "001";
	constant csr_RS		: std_logic_vector(2 downto 0) := "010";
	constant csr_RC		: std_logic_vector(2 downto 0) := "011";

	---------------------------------------------
	-- ALU opcode and funct3 arith/logic codification
	constant alu_misr	:	std_logic_vector(1 downto 0) := "00";
	constant alu_misi	:	std_logic_vector(1 downto 0) := "01";
	constant alu_branch	:	std_logic_vector(1 downto 0) := "10";
	constant alu_add	:	std_logic_vector(1 downto 0) := "11";

	-- instr. funct3 arith/logic op
	constant  funct3_add	:	std_logic_vector(2 downto 0) := "000";
	constant  funct3_sll	:	std_logic_vector(2 downto 0) := "001";
	constant  funct3_slt	:	std_logic_vector(2 downto 0) := "010";
	constant  funct3_sltu	:	std_logic_vector(2 downto 0) := "011";
	constant  funct3_xor	:	std_logic_vector(2 downto 0) := "100";
	constant  funct3_srl	:	std_logic_vector(2 downto 0) := "101";
	constant  funct3_or		:	std_logic_vector(2 downto 0) := "110";
	constant  funct3_and	:	std_logic_vector(2 downto 0) := "111";

-----------------------------------------------------------------
--- Pipeline info => group pipeline register signals with 'record'
-----------------------------------------------------------------

	-- IF/ID Pipeline Register
	type regs_ifid	is	record
		branch_stt	:	std_logic_vector(2 downto 0);
		pipe_fill	:	std_logic;
		pc			:	std_logic_vector(n-1 downto 2);
		instr		:	std_logic_vector(n-1 downto 0);
	end record regs_ifid;

	-- ID/EX Pipeline Register
	type regs_idex	is	record
		branch_stt	:	std_logic_vector(2 downto 0);
		pipe_fill	:	std_logic;
		regfile_w	:	std_logic;
		regfile_src0:	std_logic;
		branch_unc	:	std_logic;
		branch		:	std_logic;
		branch_src	:	std_logic;
		mem_r		:	std_logic;
		mem_w		:	std_logic;
		csr_en		:	std_logic;
		instr_excp	:	std_logic;
		alu_op		:	std_logic_vector(1 downto 0);
		pc			:	std_logic_vector(n-1 downto 2);
		data_rs1	:	std_logic_vector(n-1 downto 0);
		data_rs2	:	std_logic_vector(n-1 downto 0);
		imm			:	std_logic_vector(n-1 downto 0);
		funct3		:	std_logic_vector(2 downto 0);
		rs1			:	std_logic_vector(n_reg-1 downto 0);
		rs2			:	std_logic_vector(n_reg-1 downto 0);
		rd			:	std_logic_vector(n_reg-1 downto 0);
	end record regs_idex;

	-- EX/MEM Pipeline Register
	type regs_exmem	is	record
		branch_stt	:	std_logic_vector(2 downto 0);
		regfile_w	:	std_logic;
		regfile_src0:	std_logic;
		branch_unc	:	std_logic;
		branch		:	std_logic;
		branch_src	:	std_logic;
		mem_r		:	std_logic;
		mem_w		:	std_logic;
		excp_en		:	std_logic;
		intr		:	std_logic;
		branch_excp	:	std_logic;
		mem_excp	:	std_logic;
		instr_excp	:	std_logic;
		data_reg	:	std_logic_vector(n-1 downto 0);
		pc			:	std_logic_vector(n-1 downto 2);
		alu_result	:	std_logic_vector(n-1 downto 0);
		alu_zero	:	std_logic;
		funct3		:	std_logic_vector(2 downto 0);
		data_rs2	:	std_logic_vector(n-1 downto 0);
		rs2			:	std_logic_vector(n_reg-1 downto 0);
		rd			:	std_logic_vector(n_reg-1 downto 0);
	end record regs_exmem;

	-- MEM/WB Pipeline Register
	type regs_memwb	is	record
		regfile_w	:	std_logic;
		regfile_src1:	std_logic;
		data_0		:	std_logic_vector(n-1 downto 0);
		data_1		:	std_logic_vector(n-1 downto 0);
		rd			:	std_logic_vector(n_reg-1 downto 0);
	end record regs_memwb;

	-- Data from stage MEM to stage IF
	type data_mem2if	is	record
		branch_stt	:	std_logic_vector(2 downto 0);
		branch		:	std_logic;
		pc_src		:	std_logic;
		branch_addr	:	std_logic_vector(n-1 downto 2);
		pc_offset	:	std_logic_vector(n-1 downto 2);
		pc			:	std_logic_vector(n-1 downto 2);
	end record data_mem2if;

	-- Data from stage EX to stage ID
	type data_ex2id	is	record
		mem_r		:	std_logic;
		rd			:	std_logic_vector(n_reg-1 downto 0);
	end record data_ex2id;

	-- Data from stage WB to stage ID
	type data_wb2id	is	record
		regfile_w	:	std_logic;
		data_rd		:	std_logic_vector(n-1 downto 0);
		rd			:	std_logic_vector(n_reg-1 downto 0);
	end record data_wb2id;

-----------------------------------------------------------------
--- Component
-----------------------------------------------------------------
	COMPONENT stage1_IF
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
	end COMPONENT stage1_IF;

	COMPONENT stage2_ID
		port
		(
			rst			: in std_logic;
			clk			: in std_logic;
			-- cache signals
			wait_d		: in std_logic;
			-- stage stall/flush flag
			flush_branch: in std_logic;
			flush_excp	: in std_logic;
			stall_id_if	: out std_logic;
			-- signals from stage EX and WB
			ex2id		: in data_ex2id;
			wb2id		: in data_wb2id;
			-- stage pipeline register, IF/ID and ID/EX
			ifid		: in regs_ifid;
			idex		: out regs_idex
		);
	end COMPONENT stage2_ID;

	COMPONENT stage3_EX
		port
		(
			rst			: in std_logic;
			clk			: in std_logic;
			-- interrupt flag
			intr		: in std_logic;
			-- cache signals
			wait_d		: in std_logic;		-- sinal de espera pelo dado da cache
			-- stall/flush flags, and also exceptions data
			flush_branch: in std_logic;
			flush_excp	: in std_logic;
			iaddr_excp	: in std_logic;
			daddr_excp	: in std_logic;
			instr_excp	: in std_logic;
			ext_intr	: in std_logic;
			m_epc_in	: in std_logic_vector(n-1 downto 2);
			m_tvec_base	: out std_logic_vector(n-1 downto 2);
			-- foward signals
			Forward_B	: in std_logic_vector(1 downto 0);
			Forward_A	: in std_logic_vector(1 downto 0);
			Forward_S_EX: in std_logic;
			fw_data_MEM	: in std_logic_vector(n-1 downto 0);
			fw_data_WB	: in std_logic_vector(n-1 downto 0);
			-- stage pipeline register, ID/EX and EX/MEM
			addr_data	: out std_logic_vector(n-1 downto 0);
			idex		: in regs_idex;
			exmem		: out regs_exmem
		);
	end COMPONENT stage3_EX;

	COMPONENT stage4_MEM
		port
		(
			rst				: in std_logic;
			clk 			: in std_logic;
			-- cache signals
			wait_d			: in std_logic;
			-- flush signal
			flush_excp		: in std_logic;
			-- forward signals
			Forward_S		: in std_logic;
			fw_data_WB		: in std_logic_vector(n-1 downto 0);
			-- stage pipeline register, EX/MEM and MEM/WB
			data_bus 		: inout std_logic_vector(n-1 downto 0);
			sb_en			: out std_logic;
			sh_en			: out std_logic;
			mem_pc_src		: out std_logic;
			mem_branch_addr	: out std_logic_vector(n-1 downto 2);
			mem_data_rd		: out std_logic_vector(n-1 downto 0);
			mem_pc_offset	: out std_logic_vector(n-1 downto 2);
			exmem			: in regs_exmem;
			memwb			: out regs_memwb
		);
	end COMPONENT stage4_MEM;

	COMPONENT stage5_WB
		port
		(
			wb_data_rd	: out std_logic_vector(n-1 downto 0);
			memwb		: in regs_memwb
		);
	end COMPONENT stage5_WB;

------------------------------------------------------------------------
	COMPONENT RegFile
		port
		(
			clk			: in std_logic;
            rst			: in std_logic;
			RegFile_W	: in std_logic;
            rs1			: in std_logic_vector(n_reg-1 downto 0);
            rs2 		: in std_logic_vector(n_reg-1 downto 0);
            rd			: in std_logic_vector(n_reg-1 downto 0);
            data_rd		: in std_logic_vector(n-1 downto 0);
            data_rs1	: out std_logic_vector(n-1 downto 0);
			data_rs2	: out std_logic_vector(n-1 downto 0)
		);
	end COMPONENT RegFile;

	COMPONENT Imm_unit
		port
		(
			opcode   : in std_logic_vector(4 downto 0);
			imm_field : in std_logic_vector(n-1 downto 7);
			imm_out   : out std_logic_vector(n-1 downto 0)
		);
	end COMPONENT Imm_unit;

	COMPONENT Ctrl_unit
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
	end COMPONENT Ctrl_unit;

	COMPONENT csr_unit
		port
		(
			rst			: in std_logic;
			clk			: in std_logic;
			-- cache signals
			wait_d		: in std_logic;	
			-- stall/flush flags
			flush		: in std_logic;
			flush_excp	: in std_logic;
			iaddr_excp	: in std_logic;
			daddr_excp	: in std_logic;
			instr_excp	: in std_logic;
			ext_intr	: in std_logic;
			-- ctrl signals
			csr_en		: in std_logic;
			csr_op		: in std_logic_vector(2 downto 0);
			csr_sel		: in std_logic_vector(3 downto 0);
			-- stage pipeline register, ID/EX and EX/MEM
			m_epc_in	: in std_logic_vector(n-1 downto 2);
			m_tvec_base	: out std_logic_vector(n-1 downto 2);
			intr_en		: out std_logic;
			excp_en		: out std_logic;
			csr_in		: in std_logic_vector(n-1 downto 0);
			csr_out		: out std_logic_vector(n-1 downto 0)
		);
	end COMPONENT csr_unit;

	COMPONENT ALU
		port
		(
			opr_A	 : in std_logic_vector(n-1 downto 0);
			opr_B	 : in std_logic_vector(n-1 downto 0);
			ALU_ctrl : in std_logic_vector(3 downto 0);
			ALU_out	 : out std_logic_vector(n-1 downto 0);
			ALU_zero : out std_logic
		);
	end COMPONENT ALU;

---------------------------------------------------------
    COMPONENT Forward_unit
		port
		(
			RegFile_W_MEM: in std_logic;
			RegFile_W_WB : in std_logic;
			rs1_EX		 : in std_logic_vector(n_reg-1 downto 0);
			rs2_EX		 : in std_logic_vector(n_reg-1 downto 0);
			rs2_MEM		 : in std_logic_vector(n_reg-1 downto 0);
			rd_MEM		 : in std_logic_vector(n_reg-1 downto 0);
			rd_WB		 : in std_logic_vector(n_reg-1 downto 0);
			------------------
			Forward_A	 : out std_logic_vector(1 downto 0);
			Forward_B	 : out std_logic_vector(1 downto 0);
			Forward_S	 : out std_logic;
			Forward_S_EX : out std_logic
		);
	end COMPONENT Forward_unit;

---------------------------------------------------------
    COMPONENT Predict_unit
		port
		(
			rst			: in std_logic;
			clk			: in std_logic;
			stall		: in std_logic;
			-- branch ctrl signals from MEM stage
			Branch		: in std_logic;
			PC_Src		: in std_logic;
			-- predict unit ctrl output
			taken		: out std_logic;
			miss_taken	: out std_logic;
			miss_predict: out std_logic;
			bht_ready	: out std_logic;
			-- predict unit address input/output
			state_read	: out std_logic_vector(2 downto 0);
			state_write	: in std_logic_vector(2 downto 0);
			pc_read		: in std_logic_vector(n_pc-1 downto 0);
			pc_write	: in std_logic_vector(n_pc-1 downto 0);
			target_in	: in std_logic_vector(n_pc-1 downto 0);
			target_out	: out std_logic_vector(n_pc-1 downto 0)
		);
	end COMPONENT Predict_unit;
	
	COMPONENT bht_info is
        generic( n_addr : integer ;
                n_data  : integer);
		port
		(
			rst		: in std_logic;
			clk 	: in std_logic;
			stall	: in std_logic;
			we	 	: in std_logic;
			ready	: out std_logic;
			-------------------------
            r_addr	: in std_logic_vector(n_addr-1 downto 0);
            w_addr	: in std_logic_vector(n_addr-1 downto 0);
            d_in	: in std_logic_vector(n_data-1 downto 0);
			d_out	: out std_logic_vector(n_data-1 downto 0)
		);
    end COMPONENT bht_info;

	COMPONENT bht_target is
		generic(n_addr  : integer ;
				n_data  : integer);
		port
		(
			clk 	: in std_logic;
			we	 	: in std_logic;
			stall	: in std_logic;
			-------------------------
			r_addr	: in std_logic_vector(n_addr-1 downto 0);
			w_addr	: in std_logic_vector(n_addr-1 downto 0);
			d_in	: in std_logic_vector(n_data-1 downto 0);
			d_out	: out std_logic_vector(n_data-1 downto 0)
		);
	end COMPONENT bht_target;

end package core_pkg;
