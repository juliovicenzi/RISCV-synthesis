library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;
use ieee.numeric_std.all;

entity Predict_unit is
	port
	(
		rst			: in std_logic;
		clk			: in std_logic;
		stall		: in std_logic;
		-- branch ctrl signals from MEM stage
		Branch		: in std_logic;
		PC_Src		: in std_logic;
		-- predict unit ctrl output
		taken		: out std_logic;	-- taken flag
		miss_taken	: out std_logic;	-- miss check, it says if the 'miss_predict' was with taken = '1' OR  '0'
		miss_predict: out std_logic;	-- miss predict flag, must result in a flush
		bht_ready	: out std_logic;
		-- predict unit address input/output
		state_read	: out std_logic_vector(2 downto 0);
		state_write	: in std_logic_vector(2 downto 0);
		pc_read		: in std_logic_vector(n_pc-1 downto 0);	-- PC value to search through the BHT for a branch hit
		pc_write	: in std_logic_vector(n_pc-1 downto 0);	-- PC value to update/write a branch in the BHT if needed
		target_in	: in std_logic_vector(n_pc-1 downto 0);	-- new target to be stored
		target_out	: out std_logic_vector(n_pc-1 downto 0)	-- target taken
	);
end entity Predict_unit;

architecture behavior of Predict_unit is

    constant n_bht		:	integer := 9;			-- BHT size => 2^(n_bht) lines
	constant n_tag		:	integer := n_pc-n_bht;	-- tag size
	constant n_info		:	integer := n_tag+3;		-- tag + 2 bit state + 1 valid bit
	constant n_target	:	integer := n_pc;		-- target address size, the 2lsb are ignored (since PC must be 4bytes align)

	-----------------------------
	-- BHT line access
	-- read
	signal index_read	: std_logic_vector(n_bht-1 downto 0);
	signal tag_read 	: std_logic_vector(n_tag-1 downto 0);
	signal miss_bht_read: std_logic;	-- '1' means there is no branch at the selected line

	-- write
	signal branch_taken	: std_logic;	-- '1' means a branch instr. result is taken
	signal index_write	: std_logic_vector(n_bht-1 downto 0);
	signal we_info		: std_logic;
	signal we_target	: std_logic;

	-----------------------------
	-- BHT Info
	-- output
	signal valid_out	: std_logic;
	signal state_out	: std_logic_vector(1 downto 0);
	signal tag_out		: std_logic_vector(n_tag-1 downto 0);
	signal bht_info_out	: std_logic_vector(n_info-1 downto 0);

	-- input

	signal valid_in		: std_logic;
	signal state_in		: std_logic_vector(1 downto 0);
	signal tag_in		: std_logic_vector(n_tag-1 downto 0);
	signal bht_info_in	: std_logic_vector(n_info-1 downto 0);

	-- alias for the write state
	alias	miss_bht_check	:	std_logic is state_write(2);
	alias	state_check		:	std_logic is state_write(1);
	alias	fsm				:	std_logic_vector is state_write(1 downto 0);

	-- 'S' and 'W' = 'Strong' and 'Weak';   'NT' and 'T' = 'Not Taken' and 'Taken'
	constant	S_NT	:	std_logic_vector(1 downto 0) := "00";
	constant	W_NT	:	std_logic_vector(1 downto 0) := "01";
	constant	W_T		:	std_logic_vector(1 downto 0) := "10";
	constant	S_T		:	std_logic_vector(1 downto 0) := "11";

begin

	-----------------
	-- Miss verify
	-----------------
	-- Jumps are predicted as not-taken and will always trigger a miss_predict = 1 and miss_taken = 0

	branch_taken<= PC_Src;

	miss_taken	<=	'1'	when (state_check = '1' AND branch_taken = '0') else
					'0';

	miss_predict <= '1' when (branch_taken /= state_check) else
					'0';

	-------------------------------------------------------
	-- BRAM output: state & valid & tag
	-------------------------------------------------------
	--- inputs
	bht_info_in(n_tag+2)  		 		<= valid_in;
	bht_info_in(n_tag+1 downto n_tag)	<= state_in;
	bht_info_in(n_tag-1 downto 0) 		<= tag_in;

	valid_in <= '1';

	--- outputs
	valid_out 	<= bht_info_out(n_tag+2);
	state_out	<= bht_info_out(n_tag+1 downto n_tag);
	tag_out		<= bht_info_out(n_tag-1 downto 0);

	-------------------------------------------------------
	-- PC Read: search for a match in the BHT
	-------------------------------------------------------
	-- since the BHT have a 1 cycle latency to output data, we store the tag_read in
	-- a temporary register, so we can compare it against the tag output from the BHT
	-- and se if is a hit (in the BHT)
	index_read  <= pc_read(n_bht-1 downto 0);

	process (clk)
	begin
		if (rising_edge(clk)) then
			tag_read <= pc_read(n_pc-1 downto n_bht);
		end if;
	end process;

	-- see if the line given by 'index_read' has a branch stored
	miss_bht_read	<=	'0' when ( ( tag_out = tag_read ) AND valid_out = '1' ) else
						'1';
	state_read(2)	<=	miss_bht_read;

	-- if miss_bht_read = '0', we verify the 'taken' guess with the MSB of the state read from the 'bht_info',
	-- in case of a BHT miss (branch not found), the state is put to "00", as the initial guess (Strongly not taken)
	taken	<=	state_out(1) AND (NOT(miss_bht_read));

	state_read(1 downto 0)	<=	"00"	when	(miss_bht_read = '1') else
								state_out;

	-------------------------------------------------------
	-- PC Write: write/update a branch in the BHT if found with 'pc_read', and needed
	-------------------------------------------------------
	index_write	<= pc_write(n_bht-1 downto 0);
	tag_in		<= pc_write(n_pc-1 downto n_bht);

	-- write enable
	we_info		<= Branch;
	we_target	<= Branch AND miss_bht_check;

	-----------------
	-- 2 bit Logic:
	-- Taken State		=> S_T (strongly taken) = "11", W_T (weakly taken) = "10";
	-- Not Taken State	=> S_NT (strongly not taken) = "00", W_NT (weakly not taken) = "01";
	state_in <= "00" when (((fsm = S_NT) OR (fsm = W_NT) OR (fsm = W_T)) AND branch_taken = '0')	else
				"01" when (fsm = S_NT AND branch_taken = '1') 										else
				"10" when (fsm = S_T  AND branch_taken = '0') 										else
				"11" when (((fsm = W_NT) OR (fsm = W_T) OR (fsm = S_T)) AND branch_taken = '1')		else
				"--";

-----------------------------------------------------------
-- Branch History Table Instance
-----------------------------------------------------------
	-- branch history table "info (valid bit & 2bit state & tag)"" instance
	bht_info_i: bht_info
	generic map
	(
		n_addr	=> n_bht ,
		n_data	=> n_info
	)
	port map
	(
		rst		=> rst,
		clk 	=> clk ,
		stall	=> stall ,
		we 		=> we_info ,
		ready	=> bht_ready,
		-----------------------
		w_addr 	=> index_write ,
		r_addr  => index_read ,
		d_in    => bht_info_in ,
		d_out   => bht_info_out
	);

	-- branch history table "target" instance
	bht_target_i : bht_target
	generic map
	(
		n_addr	=> n_bht ,
		n_data	=> n-2
	)
	port map
	(
		clk		=> clk ,
		we		=> we_target ,
		stall	=> stall ,
		-----------------------
		w_addr	=> index_write ,
		r_addr	=> index_read ,
		d_in	=> target_in ,
		d_out	=> target_out
	);

end architecture behavior;
