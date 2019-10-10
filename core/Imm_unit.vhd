library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;

-- All opcodes are inside the 'core_pkg';
-- The immediate signal is extended through its MSb, to a 32 bits data

-- Types of immediate:
-- -> I - type, Register to Immediate instructions;
-- -> S - type, Store instructions;
-- -> B - type, Conditional Branch instructions;
-- -> U - type, LUI and AUIPC instructions;
-- -> J - type, JAL instructions;
entity Imm_unit is
	port
	(
		opcode		: in std_logic_vector(4 downto 0);		-- opcode field from the instruction
		imm_field	: in std_logic_vector(n-1 downto 7);	-- all instr. fields with possible immediate bits
		imm_out		: out std_logic_vector(n-1 downto 0)	-- immediate output
	);
end entity Imm_unit;

architecture behavior of Imm_unit is

begin
------------------------------------------
-- Decoder
------------------------------------------
	with opcode select
		imm_out(31 downto 20) <=	imm_field(31 downto 20)		when	lui_op | auipc_op,	-- U_type
									(others => imm_field(31))	when	others;				-- J_type ; I_type ; B_type ; S_type

	with opcode select
		imm_out(19 downto 12) <=	imm_field(19 downto 12)		when	lui_op | auipc_op | jal_op,-- U_type ; J_type
									(others => imm_field(31))	when	others;-- I_type ; B_type ; S_type

	with opcode select
		imm_out(11)	<=	'0'				when	lui_op | auipc_op,	-- U_type
						imm_field(20)	when	jal_op,				-- J_type
						imm_field(7)	when	branch_op,			-- B_type
						imm_field(31)	when	others;				-- I_type ; S_type

	with opcode select
		imm_out(10 downto 5) <=		(others => '0')				when	lui_op | auipc_op,	-- U_type
									imm_field(30 downto 25)		when	others;				-- I_type ; B_type ; S_type ; J_type

	with opcode select
		imm_out(4 downto 1)	<=		(others => '0')				when	lui_op | auipc_op,		-- U_type
									imm_field(11 downto 8)		when	branch_op | store_op,	-- B_type ; S_type
									imm_field(24 downto 21)		when	others;					-- I_type ; J_type

	with opcode select
		imm_out(0)	<=	imm_field(20)	when	jalr_op | opimm_op | load_op | system_op,	-- I_type
						imm_field(7)	when	store_op,									-- S_type
						'0'				when	others;										-- U_type , B_type , J_type

end architecture behavior;
