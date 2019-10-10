library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.core_pkg.all;

entity stage4_MEM is
	port
	(
		rst				: in std_logic;
		clk 			: in std_logic;
		-- cache signals
		wait_d			: in std_logic;
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
end entity stage4_MEM;

architecture behavior of stage4_MEM is

    -- Branch unit signals
    signal zero_valid : std_logic;
    signal slt_valid  : std_logic;
	signal B_valid    : std_logic;

	-- Load unit signals
	signal L_ext   :   std_logic;						-- bit ext, used with load half/byte
    signal L_upper :   std_logic_vector(31 downto 16);	-- 2 MSByte from the load data
    signal L_lower :   std_logic_vector(15 downto 0);	-- 2 LSByte from the load data

	-- PC offset
	signal	mem_pc_offset_t	:	std_logic_vector(n-1 downto 2);

	-- MUX L, 3, 4 and S from datapath
	signal	ML_out	:	std_logic_vector(n-1 downto 0);
	signal	M3_out	: 	std_logic_vector(n-1 downto 2);
    signal	M4_out 	:	std_logic_vector(n-1 downto 0);
	signal	MS_out	: 	std_logic_vector(n-1 downto 0);

begin

	-- MUX 3 : define the target adress
	M3_out	<=	exmem.data_reg(n-1 downto 2) when (exmem.branch_src = '0') else
				exmem.alu_result(n-1 downto 2);  -- when (exmem.branch_src = '1');

	mem_branch_addr	<= M3_out;
	
	-- MUX 4 : define the register file data input
	M4_out		<= 	exmem.data_reg	when	(exmem.regfile_src0 = '0') else
					exmem.alu_result; --	when	(exmem.regfile_src0 = '1');
	
	mem_data_rd <= M4_out;

	-- PC offset
	mem_pc_offset_t	<=	std_logic_vector(unsigned(exmem.pc) + 1);
	mem_pc_offset	<=	mem_pc_offset_t;

	-- MUX L: define the data to be store in the regsfile, it doesnt appear in the forward path
	ML_out	<=	M4_out	when	(exmem.branch_unc = '0') else
				mem_pc_offset_t&"00";

	-- MUX S: define data to be stored in memory
	MS_out	<=	fw_data_WB  when (Forward_S = '1') else
				exmem.data_rs2;	-- when (Forward_S = '0');

	-- internal data bus
	data_bus<=	MS_out when (exmem.mem_w = '1' AND flush_excp = '0') else
				(others => 'Z');

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-------------- Store Unit: decode a store instruction type in to a STORE:
--------------		Word, Half word or Byte.

	-- store byte and store half enable
	sb_en  <= '1' when (exmem.funct3(1) = '0' AND exmem.funct3(0) = '0') else '0';
	sh_en  <= '1' when (exmem.funct3(1) = '0' AND exmem.funct3(0) = '1') else '0';

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-------------- Branch Unit: decode a branch instruction type in to a:
--------------		Branch if equal, Branch if not equal, Branch if greater
--------------		signed/unsigned, and Branch if less signed/unsigned

    zero_valid	<= (exmem.alu_zero XOR exmem.funct3(0) ) AND NOT(exmem.funct3(2));
    slt_valid	<= (exmem.alu_result(0) XOR exmem.funct3(0) ) AND exmem.funct3(2);
	B_valid		<= zero_valid OR slt_valid;

	-- control signal PC_Src, defines the MUX 0 (from stage1 IF) output
	mem_pc_src <= exmem.branch_unc OR (B_valid AND exmem.branch);
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-------------- Load Unit: decode a load instruction type in to a LOAD:
--------------		Word, Half word signed, Half word unsigned,
--------------		Byte signed or Byte unsigned.

	L_ext <=	'0'			 when (exmem.funct3(2) = '1') else
				data_bus(15) when (exmem.funct3(0) = '1') else
				data_bus(7)  when (exmem.funct3(0) = '0') else
				'0';

	L_upper <=  data_bus(31 downto 16) when (exmem.funct3(1) = '1') else
			   (others => L_ext);

	L_lower(15 downto 8) <= data_bus(15 downto 8) when (exmem.funct3(1) = '1' OR exmem.funct3(0) = '1') else
							(others => L_ext);   --  when (exmem.funct3(0) = '0');

	L_lower(7 downto 0)  <= data_bus(7 downto 0);

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-------------- Pipeline Register
	-- on a reset, only the control signals are used (the ones needed)
	process (clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1' OR flush_excp = '1') then
				memwb.regfile_w		<=	'0';

			elsif (wait_d = '1') then
				null;

			else
				memwb.regfile_w		<=	exmem.regfile_w;
				memwb.regfile_src1	<=	exmem.mem_r;	-- RegFile_Src_1 <= Mem_R
				memwb.data_0		<= ML_out;
				memwb.data_1 		<= L_upper&L_lower;
				memwb.rd 			<= exmem.rd;

			end if;
		end if;
	end process;

end architecture behavior;
