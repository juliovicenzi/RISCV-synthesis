library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;

entity Forward_unit is
	port
	(
		RegFile_W_MEM: in std_logic;							-- regfile write enable, at stage MEM
		RegFile_W_WB : in std_logic;							-- regfile write enable, at stage WB
		rs1_EX		 : in std_logic_vector(n_reg-1 downto 0); 	-- rs1 at EX
		rs2_EX		 : in std_logic_vector(n_reg-1 downto 0); 	-- rs2 at EX
		rs2_MEM		 : in std_logic_vector(n_reg-1 downto 0);	-- rs2 at MEM
		rd_MEM		 : in std_logic_vector(n_reg-1 downto 0);	-- rd at MEM
		rd_WB		 : in std_logic_vector(n_reg-1 downto 0);	-- rd at WB
		-- Output flags (control MUX along the datapath)
		Forward_A	 : out std_logic_vector(1 downto 0);
		Forward_B	 : out std_logic_vector(1 downto 0);
		Forward_S	 : out std_logic;
		Forward_S_EX : out std_logic
	);
end Forward_unit;

architecture Behavioral of Forward_unit is

begin
	Forward_A <=	"10"	when 	(RegFile_W_MEM = '1' AND rs1_EX = rd_MEM) else
					"01"	when	(RegFile_W_WB =  '1' AND rs1_EX = rd_WB)  else
					"00";

	Forward_B <= 	"10"	when 	(RegFile_W_MEM = '1' AND rs2_EX = rd_MEM) else
					"01"	when	(RegFile_W_WB =  '1' AND rs2_EX = rd_WB)  else
					"00";

	Forward_S <= 	'1'		when	(RegFile_W_WB = '1' AND rs2_MEM = rd_WB) else
					'0';	--	when	(RegFile_W_WB  = '1' AND rs2_MEM \= rd_WB);

	Forward_S_EX <=	'1'		when	(RegFile_W_WB = '1' AND rs2_EX = rd_WB) else
					'0';	--	when	(RegFile_W_WB  = '1' AND rs2_MEM \= rd_WB);

end Behavioral;
