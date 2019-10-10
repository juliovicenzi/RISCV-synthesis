library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.core_pkg.all;

entity ALU is
	port
	(
		opr_A	 : in std_logic_vector(n-1 downto 0);
		opr_B	 : in std_logic_vector(n-1 downto 0);
		ALU_ctrl : in std_logic_vector(3 downto 0);		-- alu op control signal
		-------------------
		ALU_out	 : out std_logic_vector(n-1 downto 0);	-- alu operation output
		ALU_zero : out std_logic						-- output = 0 when 'opr_A - opr_B = 0'
	);
end entity ALU;

architecture behavior of ALU is

	-- constant 0 for comparation
	constant zero_value	:	std_logic_vector(n-1 downto 0) := (others => '0');
	alias	zero_slt	is	zero_value(n-1 downto 1);

	-- result
	signal	result		:	std_logic_vector(n-1 downto 0);

	-- unsigned comparator output
	signal	less_U	:	std_logic; -- '1' when opr_A < opr_B, unsigned

	-- shift amount
	signal	shamt	: integer range 0 to 31;

	-- set less than flag
	signal	slt_flag:	std_logic;

	-- full adder/subtractor signals, with overflow detection
	signal	add_B			:	std_logic_vector(n-1 downto 0);	-- opr_B XOR carry_in(0)
	signal	carry			:	std_logic_vector(n downto 0);	-- carry bit (n+1)
	signal	adder_u_overflow:	std_logic;						-- unsigned adder overflow
	signal	adder_s_overflow:	std_logic;						-- signed adder overflow

	-- operation type
	signal	op_ARITH:	std_logic_vector(n-1 downto 0);
	signal	op_LOGIC:	std_logic_vector(n-1 downto 0);
	signal	op_SHIFT:	std_logic_vector(n-1 downto 0);

	-- operation
	signal	op_ADD	:	std_logic_vector(n-1 downto 0);
	alias	op_SUB	:	std_logic_vector(n-1 downto 0)	is	op_ADD;
	signal	op_XOR	:	std_logic_vector(n-1 downto 0);
	signal	op_AND	:	std_logic_vector(n-1 downto 0);
	signal	op_OR 	:	std_logic_vector(n-1 downto 0);
	-- signal	op_SLL	:	std_logic_vector(n-1 downto 0);
	signal	op_SRL	:	std_logic_vector(n-1 downto 0);
	signal	op_SRA	:	std_logic_vector(n-1 downto 0);
	-- signal	op_SLTS	:	std_logic_vector(n-1 downto 0);
	signal	op_SLTU	:	std_logic_vector(n-1 downto 0);

	signal	op_MUX	:	std_logic_vector(n-1 downto 0);	-- MUX to output SLL or SLTS

begin

	--
	shamt <= to_integer(unsigned(opr_B(4 downto 0)));

	-- unsigned compare, used with 'Set Less Than Unsigned'
    less_U <= '1' when (opr_A < opr_B) else
              '0';

	-------------------------------------------------------------------
	-- arith operations

	-- full adder/subtractor, with overflow detection
	adder_u_overflow<=	carry(n);
	adder_s_overflow<=	carry(n) XOR carry(n-1);
	carry(0)		<=	ALU_ctrl(0);	--	when '0' = add;	when '1' = sub
	full_addsub: for i in 0 to n-1 generate
		add_B(i)	<=	opr_B(i) XOR carry(0);
		op_ADD(i)	<=	(opr_A(i) XOR add_B(i) XOR carry(i));
		carry(i+1) 	<=	(opr_A(i) AND add_B(i)) OR (op_ADD(i) AND carry(i));
	end generate full_addsub;

	-- op_SLTS	<=	zero_slt & op_SUB(n-1);	-- msb of the sub tell us if opr_A < opr_B, SIGNED,
	-- unless we have an overflow
	slt_flag <=	op_SUB(n-1)	when	(adder_s_overflow = '0')	else
				NOT(op_SUB(n-1));

	with ALU_ctrl(0) select
		op_MUX	<=	to_stdlogicvector(to_bitvector(opr_A)  SLL shamt)	when	'0',	-- op_SLL
					zero_slt & slt_flag									when	others;	-- op_SLTS

	with ALU_ctrl(1) select
		op_ARITH <=	op_ADD	when	'0',
					op_MUX	when	others;

	-------------------------------------------------------------------
	-- logic operations
	op_OR	<=	opr_A OR opr_B;
	op_AND	<=	opr_A AND opr_B;
	op_XOR	<=	opr_A XOR opr_B;
	op_SLTU	<=	zero_slt & less_U;

	with ALU_ctrl(1 downto 0) select
		op_LOGIC <=	op_OR	when	"00",
					op_AND	when	"01",
					op_XOR	when	"10",
					op_SLTU	when	others;	-- "11"

	-------------------------------------------------------------------
	-- shift right operations
	op_SRL	<= to_stdlogicvector(to_bitvector(opr_A)  SRL shamt);
	op_SRA	<= to_stdlogicvector(to_bitvector(opr_A)  SRA shamt);

	with ALU_ctrl(0) select
		op_SHIFT <=	op_SRL	when	'0',
					op_SRA	when	others;	-- '1'

	-------------------------------------------------------------------
	-- result
	ALU_out <= result;

	with ALU_ctrl(3 downto 2) select
		result <=	op_ARITH		when	"00",
					op_LOGIC		when	"01",
					op_SHIFT		when	"10",
					(others => '-')	when	others;	--	"11"

	-- compare the subtraction to 0, used with BEQ and BNE instructions, the actual op
	-- doesnt matter (since the result wont be stored in the register file)
	ALU_zero <= '1' when (op_SUB = zero_value AND adder_u_overflow = '0') else
			    '0';

end architecture behavior;
