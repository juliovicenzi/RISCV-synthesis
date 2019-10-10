library ieee;
use ieee.std_logic_1164.all;

package cache_pkg is

----------------------------------------------------------------
--------- CACHE INIT INFO
	-- note: all ihex files must be inside the ise project folder

	constant	path	:	string := "text_file/ihex/";

	-- ihex files path
	constant	bootloader	:	string	:=	path&"bootloader.hex";
	constant	main		:	string	:=	path&"main.hex";
	constant	dhrystone	:	string	:=	path&"dhrystone.hex";
	constant	test		:	string	:=	path&"test/hex/";

-- 	constant   test_file   :   string  := "instr_basic.hex";
-- 	constant   test_file   :   string  := "instr_branch.hex";
-- 	constant   test_file   :   string  := "instr_r2imm.hex";
-- 	constant   test_file   :   string  := "instr_reg2reg.hex";
-- 	constant   test_file   :   string  := "instr_jump.hex";
-- 	constant   test_file   :   string  := "instr_load.hex";
-- 	constant   test_file   :   string  := "instr_store.hex";
-- 	constant   test_file   :   string  := "instr_csr.hex";
-- 	constant   test_file   :   string  := "instr_csri.hex";
-- 	constant   test_file   :   string  := "core_datapath.hex";
-- 	constant   test_file   :   string  := "io.hex";
-- 	constant   test_file   :   string  := "dcache.hex";
	
	constant	filepath	:	string	:=  bootloader;
	-- constant	filepath	:	string	:=	main;
	-- constant	filepath	:	string	:=	dhrystone;
	-- constant	filepath	:	string  :=  test&test_file;

----------------------------------------------------------------
--------- OTHERS
	constant n	:	integer := 32;
	constant n2	:	integer := n-2;

----------------------------------------------------------------
--------- INSTRUCTION CACHE
	component icache_ctrl is
		port(
			rst_cache	: in std_logic;
			rst_index	: in std_logic_vector(11 downto 0);
			clk			: in std_logic;
			valid_addr	: in std_logic;
			en			: in std_logic;
			wait_i		: out std_logic;
			dout		: out std_logic_vector(n-1 downto 0);
			addr		: in std_logic_vector(n2-1 downto 0);
			addr_reg_out: out std_logic_vector(n2-1 downto 0);
			miss		: out std_logic;
			ready_ir	: in std_logic;
			din			: in std_logic_vector(n-1 downto 0));
	end component icache_ctrl;

	component icache is
		generic(n_data	: integer;
				n_addr	: integer);
		port(
			clk			: in std_logic;
			en			: in std_logic;
			we			: in std_logic;
			addr		: in std_logic_vector(n_addr-1 downto 0);
			din			: in std_logic_vector(n_data-1 downto 0);
			dout		: out std_logic_vector(n_data-1 downto 0));
	end component icache;

	component icache_info is
		generic(n_data	: integer;
				n_addr	: integer);
		port(
			clk			: in std_logic;
			en			: in std_logic;
			we			: in std_logic;
			addr		: in std_logic_vector(n_addr-1 downto 0);
			din			: in std_logic_vector(n_data-1 downto 0);
			dout		: out std_logic_vector(n_data-1 downto 0));
	end component icache_info;
	
----------------------------------------------------------------
--------- DATA CACHE
	component dcache_ctrl is
		port(
			rst_cache	: in std_logic;
			rst_index	: in std_logic_vector(11 downto 0);
			clk			: in std_logic;
			valid_addr	: in std_logic;
			wait_d		: out std_logic;
			we			: in std_logic;
			sh_en		: in std_logic;
			sb_en		: in std_logic;
			addr		: in std_logic_vector(n-1 downto 0);
			addr_reg	: in std_logic_vector(n-1 downto 0);
			data		: inout std_logic_vector(n-1 downto 0);
			--------------------------------------
			miss_dcache	: out std_logic;
			wb_en		: out std_logic;
			addr_wb		: out std_logic_vector(n-1 downto 0);
			din			: in std_logic_vector(n-1 downto 0);
			dout		: out std_logic_vector(n-1 downto 0);
			ready_dr	: in std_logic
			);
	end component dcache_ctrl;

	component dcache is
		generic(
			n_data : integer;
			n_addr : integer
			);
		port(
			en_r	: in std_logic;
			clk		: in std_logic;
			col		: in std_logic;
			web		: in std_logic_vector(3 downto 0);
			addra	: in std_logic_vector(n_addr-1 downto 0);
			douta	: out std_logic_vector(n_data-1 downto 0);
			addrb	: in std_logic_vector(n_addr-1 downto 0);
			dinb	: in std_logic_vector(n_data-1 downto 0)
			);
	end component dcache;

	component dcache_info is
		generic(
			n_data : integer;
			n_addr : integer
			);
		port(
			en_r	: in std_logic;
			clk		: in std_logic;
			col		: in std_logic;
			web		: in std_logic;
			addra	: in std_logic_vector(n_addr-1 downto 0);
			douta	: out std_logic_vector(n_data-1 downto 0);
			addrb	: in std_logic_vector(n_addr-1 downto 0);
			dinb	: in std_logic_vector(n_data-1 downto 0)
			);
	end component dcache_info;

----------------------------------------------------------------
--------- READ/WRITE BUFFER
	COMPONENT cache_wbuffer is
		port
		(
			clk		: in std_logic;
			rst		: in std_logic;
			--------------------------------
			full	: out std_logic;
			empty	: out std_logic;
			en		: in std_logic;
			we		: in std_logic;
			addr_in	: in std_logic_vector(n-1 downto 0);
			addr_out: out std_logic_vector(n-1 downto 0);
			din		: in std_logic_vector(n-1 downto 0);
			dout	: out std_logic_vector(n-1 downto 0)
			--------------------------------
		);
	end COMPONENT cache_wbuffer;

end package cache_pkg;
