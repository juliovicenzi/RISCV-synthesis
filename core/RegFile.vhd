library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.core_pkg.all;

-- 32x4 bytes Register File:
-- 2 read ports, with data outputs of 32 bits;
-- 1 write port, with input data of 32 bits;
-- forward logic for both read ports, if a read is at the same
--		address being write, the new data is selected to the output,
--		instead of the old value;
-- register x0 (address 0) is the constant 0.
entity RegFile is
	port
	(
		clk      : in std_logic;
		rst		  : in std_logic;
		------------------------
		rs1	      : in std_logic_vector(n_reg-1 downto 0);	-- rs1 address input
		rs2 	  : in std_logic_vector(n_reg-1 downto 0);	-- rs2 address input
		rd		  : in std_logic_vector(n_reg-1 downto 0);	-- rd address input
		data_rd	  : in std_logic_vector(n-1 downto 0);		-- rd data input
		data_rs1  : out std_logic_vector(n-1 downto 0);		-- rs1 data output
		data_rs2  : out std_logic_vector(n-1 downto 0);		-- rs2 data output
		RegFile_W : in std_logic							-- write enable
	);
end entity RegFile;

architecture behavior of RegFile is

	-- type array, 32x4bytes, register file
	type reg_array is ARRAY(1 to (2**n_reg)-1) of std_logic_vector(n-1 downto 0);
	signal regs_file : reg_array := (others => (others => '0'));

	-- reset register, each bit say when a data in the register file (at the same index
	-- as the bit position) is valid
	signal rst_data : std_logic_vector((2**n_reg)-1 downto 0) := (others => '0');

	signal rs1_i: integer range 0 to (2**n_reg)-1;
	signal rs2_i: integer range 0 to (2**n_reg)-1;
	signal rd_i	: integer range 0 to (2**n_reg)-1;

begin

	-- input address as integer (to use as index)
	rs1_i <= (to_integer(unsigned(rs1)));
	rs2_i <= (to_integer(unsigned(rs2)));
	rd_i  <= (to_integer(unsigned(rd)));

	-- read address rs1, do forward (= rd) if necessary
	data_rs1 <= data_rd			when (rs1_i = rd_i AND RegFile_W = '1')		else
				(others => '0')	when (rst_data(rs1_i) = '0' OR rs1_i = 0)	else
				regs_file(rs1_i);

	-- read address rs2, do forward (= rd) if necessary
	data_rs2 <= data_rd			when (rs2_i = rd_i AND RegFile_W = '1')		else
				(others => '0') when (rst_data(rs2_i) = '0' OR rs2_i = 0)	else
				regs_file(rs2_i);

	-----------------------------------------------------------------
	-- Register File
	RegFile_Write : process (clk)
	begin
		if (rising_edge(clk)) then
			if (RegFile_W = '1') then
				regs_file(rd_i) <= data_rd;

			end if;
		end if;
	end process RegFile_Write;

	-- Reset Register
	regfile_rst : process (clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				rst_data <= (others => '0');

			elsif (RegFile_W = '1' AND rd_i/=0) then	-- index 0 is ignored, since the register x0 is
				rst_data(rd_i) <= '1';					-- a constant 0

			end if;
		end if;
	end process regfile_rst;

end architecture behavior;
