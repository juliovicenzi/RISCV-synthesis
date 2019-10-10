library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.core_pkg.all;

entity csr_unit is
	port
	(
		rst			: in std_logic;
		clk			: in std_logic;
		-- cache signals
		wait_d		: in std_logic;	
		-- stall/flush flags
		flush		: in std_logic;
		flush_excp	: in std_logic;
		-- ctrl signals
		csr_en		: in std_logic;
		csr_op		: in std_logic_vector(2 downto 0);
		csr_sel		: in std_logic_vector(3 downto 0);
		-- type of excp
		iaddr_excp	: in std_logic;	-- bad instr. address (jal/jalr/branch)
		daddr_excp	: in std_logic;	-- bad data address (load/store)
		instr_excp	: in std_logic;	-- illegal instr. (instr[1:0] < "11")
		ext_intr	: in std_logic;
		-- input and output data for CSR registers
		m_epc_in	: in std_logic_vector(n-1 downto 2);	-- epc input
		m_tvec_base	: out std_logic_vector(n-1 downto 2);	-- tvec base address
		intr_en		: out std_logic;						-- interrupt enable
		excp_en		: out std_logic;						-- software exception enable
		csr_in		: in std_logic_vector(n-1 downto 0);
		csr_out		: out std_logic_vector(n-1 downto 0)
	);
end entity csr_unit;

architecture behavior of csr_unit is

	constant	zero	:	std_logic_vector(n-1 downto 5)	:= (others => '0');
	signal		M_out	:	std_logic_vector(n-1 downto 0);
	signal		en		:	std_logic;

	-----------------
	-- CSR set and clear bit instructions
	signal	csr_in_op	:	std_logic_vector(n-1 downto 0);
	signal	csr_set		:	std_logic_vector(n-1 downto 0);
	signal	csr_clear	:	std_logic_vector(n-1 downto 0);

	-----------------
	-- m_status register
	signal	m_status	:	std_logic_vector(1 downto 0)	:= "01";	-- the Machine level status reg only uses 2 bits, [4] and [0]
		-- alias	MPP			:	std_logic	is	m_status(2);	-- not used
	alias	MPIE		:	std_logic	is	m_status(1);
	alias	MIE			:	std_logic	is	m_status(0);

	signal	m_status_in	:	std_logic_vector(1 downto 0);
	signal	m_status_out:	std_logic_vector(n-1 downto 0);

	-----------------
	-- m_ie register
	signal	m_ie		:	std_logic_vector(1 downto 0) := (others => '0');
	alias	MEIE		:	std_logic	is	m_ie(1);
	alias	MSIE		:	std_logic	is	m_ie(0);

	signal	m_ie_in		:	std_logic_vector(1 downto 0);
	signal	m_ie_out	:	std_logic_vector(n-1 downto 0);

	-----------------
	-- m_tvec register
	signal	m_tvec		:	std_logic_vector(n-1 downto 0)	:= (others => '0');	-- trap handler base address
	alias	BASE		:	std_logic_vector(n-1 downto 2)	is	m_tvec(n-1 downto 2);
	alias	MODE		:	std_logic_vector(1 downto 0)	is	m_tvec(1 downto 0);

	signal		intr_base:	std_logic;
	constant	DIRECT	:	std_logic_vector(1 downto 0) := "00";
	constant	VECTOR	:	std_logic_vector(1 downto 0) := "10";

	-----------------
	-- m_epc register
	signal	m_epc		:	std_logic_vector(n-1 downto 2)	:= (others => '1');	-- excpetion program counter
	signal	m_epc_out	:	std_logic_vector(n-1 downto 0);

	-----------------
	-- m_cause register
	signal	m_cause		:	std_logic_vector(4 downto 0)	:= (others => '0');	-- exception/interrupt cause
	alias	CAUSE_INTR	:	std_logic						is	m_cause(4);
	alias	CAUSE		:	std_logic_vector(3 downto 0)	is	m_cause(3 downto 0);

	signal	m_cause_in	:	std_logic_vector(4 downto 0);
	signal	m_cause_out	:	std_logic_vector(n-1 downto 0);
	signal	CAUSE_excp_in:	std_logic_vector(3 downto 0);
	signal	CAUSE_intr_in:	std_logic_vector(3 downto 0);

begin

	intr_en	<=	MEIE AND MIE;
	excp_en	<=	MSIE AND MIE;

	en	<=	'1' when (wait_d = '0' AND flush = '0' AND csr_en = '1') else
			'0';

	-------------------------------------------------------
	------- Set and Clear operation
	csr_set		<=	M_out OR csr_in;
	csr_clear	<=	M_out AND (NOT(csr_in));

	with csr_op(1 downto 0) select
		csr_in_op	<=	csr_in			when	"01",
						csr_set			when	"10",
						csr_clear		when	"11",
						(others => '-')	when	others;

	-------------------------------------------------------
	------- Output
	with csr_sel select
		M_out	<=	m_status_out	when	mstatus_op,
					m_tvec			when	mtvec_op,
					m_epc_out		when	mepc_op,
					m_cause_out		when	mcause_op,
					m_ie_out		when	mie_op,
					(others => '-')	when	others;

	csr_out <= M_out;

	-------------------------------------------------------
	------- Machine Status
	m_status_in <=	csr_in_op(7) & csr_in_op(3);
	m_status_out<=	(7 => MPIE, 3 => MIE, others => '0');

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				m_status <= (others => '0');

			elsif (flush_excp = '1') then		-- disable global traps
				MPIE<= MIE;
				MIE <= '0';

			elsif (en = '1' AND csr_op = "000") then	-- enable global traps again
				MPIE<= '0';
				MIE	<= MPIE;

			elsif (en = '1' AND csr_sel = mstatus_op) then
				m_status <= m_status_in;


			end if;
		end if;
	end process;

	-------------------------------------------------------
	------- Machine Interrupt Enable
	m_ie_in		<=	csr_in_op(11) & csr_in_op(3);
	m_ie_out	<=	(11 => MEIE, 3 => MSIE, others => '0');

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				m_ie <= (others => '0');

			elsif (en = '1' AND csr_sel = mie_op) then
				m_ie <= m_ie_in;

			end if;
		end if;
	end process;

	-------------------------------------------------------
	------- Machine Trap Handler Base Address
	intr_base	<=	'1'	when	(MODE = VECTOR AND flush_excp = '1' AND ext_intr = '1') else
					'0';

	m_tvec_base	<=	std_logic_vector(unsigned(BASE) + unsigned(CAUSE))	when (intr_base = '1') else
					BASE;

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				m_tvec <= (others => '0');

			elsif (en = '1' AND csr_sel = mtvec_op) then
				m_tvec	<= csr_in_op(n-1 downto 0);

			end if;
		end if;
	end process;

	-------------------------------------------------------
	------- Machine Exception Program Counter
	m_epc_out <= m_epc & "00";

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				m_epc <= (others => '0');

			elsif (flush_excp = '1') then
				m_epc <= m_epc_in;

			elsif (en = '1' AND csr_sel = mepc_op) then
				m_epc <= csr_in_op(n-1 downto 2);

			end if;
		end if;
	end process;

	-------------------------------------------------------
	------- Machine Cause
	m_cause_in	<=	csr_in_op(n-1) & csr_in_op(3 downto 0);
	m_cause_out	<=	m_cause(4) & zero & m_cause(3 downto 0);

	-- cause of the exception => 0 = illegal instr; 2 = bad instr. address; 4 = bad data address
	CAUSE_excp_in	<=	'0' & daddr_excp & iaddr_excp & instr_excp;

	-- cause of interrupt (machine mode only) => 3 = software; 7 = timer; 11 = external
	-- priority level: from software (most) => external (less)
	CAUSE_intr_in(3 downto 0) <=	"1011";	-- "1011" is the code for Machine external interrupt

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				m_cause <= (others => '0');

			elsif (flush_excp = '1') then
				if (ext_intr = '1') then	-- interrupt has priority
					m_cause <= '1' & CAUSE_intr_in;
				else
					m_cause <= '0' & CAUSE_excp_in;
				end if;

			elsif (en = '1' AND csr_sel = mcause_op) then
				m_cause <= m_cause_in;

			end if;
		end if;
	end process;

end architecture behavior;
