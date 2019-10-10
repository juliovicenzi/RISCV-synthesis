library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;

entity stage5_WB is
	port
	(
		wb_data_rd	: out std_logic_vector(n-1 downto 0);
		memwb		: in regs_memwb
	);
end entity stage5_WB;

architecture behavior of stage5_WB is

begin

	-- MUX 5 : choose the input data to the register file
	wb_data_rd	<=	memwb.data_0 when	(memwb.regfile_src1 = '0') else
                	memwb.data_1;  -- when	(RegFile_Src_1 = '1');

end architecture behavior;
