library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library hdl4fpga;
use hdl4fpga.std.all;
use hdl4fpga.cgafonts.all;

entity scopeio_axis is
	generic (
		latency     : natural);
	port (
		clk         : in  std_logic;

		frm         : in  std_logic;
		irdy        : in  std_logic;
		trdy        : out std_logic;
		unit        : in  std_logic_vector;

		wu_frm      : out std_logic;
		wu_irdy     : out std_logic;
		wu_trdy     : in  std_logic;
		wu_value    : out std_logic_vector;
		wu_format   : in  std_logic_vector;

		video_clk   : in  std_logic;
		video_hcntr : in  std_logic_vector;
		video_vcntr : in  std_logic_vector;

		hz_offset   : in  std_logic_vector;
		video_hzon  : in  std_logic;
		video_hzdot : out std_logic;

		vt_offset   : in  std_logic_vector;
		video_vton  : in  std_logic;
		video_vtdot : out std_logic);

end;

architecture def of scopeio_axis is

	signal vt_ena      : std_logic;
	signal vt_addr     : std_logic_vector(13-1 downto 6);
	signal vt_vaddr    : std_logic_vector(13-1 downto 0);
	signal vt_taddr    : std_logic_vector(13-1 downto 6);
	signal vt_tick     : std_logic_vector(wu_format'range);

	signal hz_ena      : std_logic;
	signal hz_addr     : std_logic_vector(13-1 downto 6);
	signal hz_vaddr    : std_logic_vector(13-1 downto 0);
	signal hz_taddr    : std_logic_vector(13-1 downto 6);
	signal hz_tick     : std_logic_vector(wu_format'range);

begin

	ticks_b : block
	begin

		process (clk)
			variable cntr : unsigned(max(hz_addr'length, vt_addr'length)-1 downto 0);
		begin
			if rising_edge(clk) then
				if frm='0' then
					cntr := (others => '0');
				elsif wu_trdy='1' then
					cntr := cntr + 1;
				end if;
				hz_addr <= std_logic_vector(cntr(hz_addr'range));
				vt_addr <= std_logic_vector(cntr(vt_addr'range));
			end if;
		end process;

		ticks_e : entity hdl4fpga.scopeio_ticks
		port map (
			clk      => clk,
			frm      => frm,
			irdy     => irdy,
			trdy     => trdy,
			base     => x"000e",
			step     => x"0010",
			wu_frm   => wu_frm,
			wu_irdy  => wu_irdy,
			wu_trdy  => wu_trdy,
			wu_value => wu_value);

	end block;

	hz_mem_e : entity hdl4fpga.dpram
	generic map (
		bitrom => (0 to 2**7*wu_format'length-1 => '1'))
	port map (
		wr_clk  => clk,
		wr_ena  => hz_ena,
		wr_addr => hz_addr,
		wr_data => wu_format,

		rd_addr => hz_taddr,
		rd_data => hz_tick);

	vt_mem_e : entity hdl4fpga.dpram
	generic map (
		bitrom => (0 to 2**4*wu_format'length-1 => '1'))
	port map (
		wr_clk  => clk,
		wr_ena  => vt_ena,
		wr_addr => vt_addr,
		wr_data => wu_format,

		rd_addr => vt_taddr,
		rd_data => vt_tick);

	video_b : block

		signal char_code : std_logic_vector(4-1 downto 0);
		signal char_row  : std_logic_vector(3-1 downto 0);
		signal char_col  : std_logic_vector(3-1 downto 0);
		signal char_dot  : std_logic;

		signal hz_x     : signed(hz_vaddr'range);
		signal hz_y     : std_logic_vector(video_vcntr'length-1 downto 0);
		signal hz_bcd   : std_logic_vector(char_code'range);
		signal hz_crow  : std_logic_vector(6-1 downto 0);
		signal hz_ccol  : std_logic_vector(6-1 downto 0);
		signal hz_don   : std_logic;
		signal hs_on    : std_logic;

		signal vt_x     : std_logic_vector(video_hcntr'length-1 downto 0);
		signal vt_y     : signed(hz_vaddr'range);
		signal vt_bcd   : std_logic_vector(char_code'range);
		signal vt_crow  : std_logic_vector(6-1 downto 0);
		signal vt_ccol  : std_logic_vector(6-1 downto 0);
		signal vt_don   : std_logic;
		signal vs_on    : std_logic;

	begin

		hz_x <= resize(signed(video_hcntr), hz_x'length) + signed(hz_offset);
		hz_y <= video_vcntr;
		process (video_clk)
		begin
			if rising_edge(video_clk) then
				hz_vaddr <= std_logic_vector(hz_x);
				hs_on    <= video_hzon;
				hz_ccol  <= std_logic_vector(hz_x(hz_ccol'range));
				hz_crow  <= hz_y(hz_crow'range);
			end if;
		end process;
		hz_taddr <= hz_vaddr(hz_taddr'range);
		hz_bcd   <= word2byte(hz_tick, hz_vaddr(6-1 downto 3), char_code'length);

		vt_x <= video_hcntr;
		vt_y <= resize(signed(video_vcntr), vt_y'length) + signed(vt_offset);
		process (video_clk)
		begin
			if rising_edge(video_clk) then
				vt_vaddr <= std_logic_vector(vt_y);
				vs_on    <= video_vton;
				vt_ccol  <= vt_x(vt_ccol'range);
				vt_crow  <= std_logic_vector(vt_y(vt_crow'range));
			end if;
		end process;
		vt_taddr <= vt_vaddr(vt_taddr'range);
		vt_bcd   <= word2byte(std_logic_vector(unsigned(vt_tick) rol 2*char_code'length), video_hcntr(6-1 downto 3), char_code'length);

		char_row  <= word2byte(hz_crow & vt_crow, vs_on); 
		char_col  <= word2byte(hz_ccol & vt_ccol, vs_on); 
		char_code <= word2byte(hz_bcd  & vt_bcd,  vs_on);
		rom_e : entity hdl4fpga.cga_rom
		generic map (
			font_bitrom => psf1digit8x8,
			font_height => 2**3,
			font_width  => 2**3)
		port map (
			clk       => video_clk,
			char_col  => char_col,
			char_row  => char_row,
			char_code => char_code,
			char_dot  => char_dot);

		romlat_b : block
			signal ons : std_logic_vector(0 to 2-1);
		begin

			ons(0) <= hs_on;
			ons(1) <= vs_on and vt_y(4) and vt_y(3);
			lat_e : entity hdl4fpga.align
			generic map (
				n => ons'length,
				d => (ons'range => 2))
			port map (
				clk   => video_clk,
				di    => ons,
				do(0) => hz_don,
				do(1) => vt_don);
		end block;

		lat_b : block
			signal dots : std_logic_vector(0 to 2-1);
		begin
			dots(0) <= char_dot and hz_don;
			dots(1) <= char_dot and vt_don;

			lat_e : entity hdl4fpga.align
			generic map (
				n => dots'length,
				d => (dots'range => latency-3))
			port map (
				clk   => video_clk,
				di    => dots,
				do(0) => video_hzdot,
				do(1) => video_vtdot);
		end block;
	end block;

end;
