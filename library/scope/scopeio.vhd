library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library hdl4fpga;
use hdl4fpga.std.all;
use hdl4fpga.cgafont.all;

entity scopeio is
	generic (
		inputs         : natural := 1;
		input_preamp   : real_vector;
		layout_id      : natural := 0;
		vt_div         : std_logic_vector := b"0_0010_0000";
		hz_div         : std_logic_vector := b"0_0010_0000";
		hz_scales      : scale_vector;
		vt_scales      : scale_vector;
		gauge_labels   : std_logic_vector;
		unit_symbols   : std_logic_vector;
		channels_fg    : std_logic_vector;
		channels_bg    : std_logic_vector;
		hzaxis_fg      : std_logic_vector;
		hzaxis_bg      : std_logic_vector;
		grid_fg        : std_logic_vector;
		grid_bg        : std_logic_vector);

	port (
		mii_rxc     : in  std_logic := '-';
		mii_rxdv    : in  std_logic := '0';
		mii_rxd     : in  std_logic_vector;
		tdiv        : out std_logic_vector(4-1 downto 0);
		cmd_rdy     : in  std_logic := '0';
		channel_ena : in  std_logic_vector(0 to inputs-1) := (others => '1');
		input_clk   : in  std_logic;
		input_ena   : in  std_logic := '1';
		input_data  : in  std_logic_vector;
		video_clk   : in  std_logic;
		video_rgb   : out std_logic_vector;
		video_hsync : out std_logic;
		video_vsync : out std_logic;
		video_blank : out std_logic;
		video_sync  : out std_logic);
end;

architecture beh of scopeio is


	type layout is record 
		mode        : natural;
		scr_width   : natural;
		num_of_seg  : natural;
		chan_x      : natural;
		chan_y      : natural;
		chan_width  : natural;
		chan_height : natural;
	end record;

	type layout_vector is array (natural range <>) of layout;
	constant ly_dptr : layout_vector(0 to 1) := (
--		0 => (mode, scr_width | num_of_seg | chan_x | chan_y | chan_width | chan_height
		0 => (   7,      1920,           4,     320,     270,       50*32,          256),
		1 => (   1,       800,           2,     320,     300,       15*32,          256));

	function to_naturalvector (
		constant arg  : layout)
		return natural_vector is
		variable rval : natural_vector(0 to 4*arg.num_of_seg-1);
	begin
		for i in 0 to arg.num_of_seg-1 loop
			rval(i*4+0) := 0;
			rval(i*4+1) := i*arg.chan_y;
			rval(i*4+2) := arg.scr_width;
			rval(i*4+3) := arg.chan_y-1;
		end loop;
		return rval;
	end;

	constant vt_size : natural := unsigned_num_bits(ly_dptr(layout_id).chan_height-1)+1;

	signal hdr_data         : std_logic_vector(288-1 downto 0);
	signal pld_data         : std_logic_vector(3*8-1 downto 0);
	signal pll_data         : std_logic_vector(0 to hdr_data'length+pld_data'length-1);
	signal ser_data         : std_logic_vector(32-1 downto 0);

	constant cga_zoom       : natural := 0;
	signal cga_we           : std_logic;
	signal scope_cmd        : std_logic_vector(8-1 downto 0);
	signal scope_data       : std_logic_vector(8-1 downto 0);
	signal scope_channel    : std_logic_vector(8-1 downto 0);
	signal char_dot         : std_logic;

	signal video_hs         : std_logic;
	signal video_vs         : std_logic;
	signal video_frm        : std_logic;
	signal video_hon        : std_logic;
	signal video_hzl        : std_logic;
	signal video_vld        : std_logic;
	signal video_vcntr      : std_logic_vector(11-1 downto 0);
	signal video_hcntr      : std_logic_vector(11-1 downto 0);

	signal tracers_on       : std_logic_vector(0 to inputs-1);
	signal objects_bg       : std_logic_vector(0 to 4-1);
	signal objects_fg       : std_logic_vector(0 to 3-1);

	signal video_io         : std_logic_vector(0 to 3-1);
	signal abscisa          : std_logic_vector(0 to unsigned_num_bits(ly_dptr(layout_id).chan_width-1)-1);
	
	signal win_don          : std_logic_vector(0 to 18-1);
	signal win_frm          : std_logic_vector(0 to 18-1);
	signal pll_rdy          : std_logic;

	signal input_addr       : std_logic_vector(0 to unsigned_num_bits(ly_dptr(layout_id).num_of_seg*ly_dptr(layout_id).chan_width-1));
	signal input_we         : std_logic;
	signal input_inc        : std_logic;

	signal vt_scale         : std_logic_vector(4-1 downto 0);
	signal channel_scale    : std_logic_vector(0 to vt_scale'length*inputs-1):= (others => '0');
	signal channel_decas    : std_logic_vector(0 to ascii'length*inputs-1);
	signal gp_vtscale       : std_logic_vector(0 to vt_scale'length*inputs-1);

	signal channel_select   : std_logic_vector(unsigned_num_bits(inputs-1)-1 downto 0);
	signal time_deca        : std_logic_vector(ascii'range);

	signal  vm_inputs       : std_logic_vector(0 to inputs*vt_size-1);
	signal  trigger_level   : std_logic_vector(0 to vt_size-1);
	signal  vm_addr         : std_logic_vector(1 to input_addr'right);
	signal  trigger_offset  : std_logic_vector(0 to vt_size-1);
	signal  trigger_edge    : std_logic;
	signal  trigger_select  : std_logic_vector(channel_select'range);
	signal  trigger_channel : std_logic_vector(trigger_select'range);
	signal  trigger_scale   : std_logic_vector(vt_scale'range);
	signal  trigger_deca    : std_logic_vector(ascii'range);
	signal  full_addr       : std_logic_vector(vm_addr'range);
	signal  channel_offset  : std_logic_vector(0 to inputs*vt_size-1) := (others => '0');
	signal  vt_pos    : std_logic_vector(0 to inputs*vt_size-1);
	signal  ordinates       : std_logic_vector(vm_inputs'range);
	signal  hz_scale        : std_logic_vector(4-1 downto 0);
	signal  text_data       : std_logic_vector(8-1 downto 0);
	signal  text_addr       : std_logic_vector(10-1 downto 0) := (others => '0');

	subtype mword         is signed(0 to 18-1);
	subtype mdword        is signed(0 to 2*mword'length-1);
	type    mword_vector  is array (natural range <>) of mword;
	type    mdword_vector is array (natural range <>) of mdword;

	signal scales           : std_logic_vector(0 to inputs*mword'length-1);
	signal video_pixel       : std_logic_vector(video_rgb'range);

	signal gpannel_on  : std_logic_vector(0 to ly_dptr(layout_id).num_of_seg-1);
	signal gpannel_x   : std_logic_vector(unsigned_num_bits(ly_dptr(layout_id).scr_width-1)-1 downto 0);
	signal gpannel_y   : std_logic_vector(unsigned_num_bits(ly_dptr(layout_id).chan_y-1)-1 downto 0);

	constant font_width  : natural := 8;
	constant font_height : natural := 16;
	signal   cga_code    : std_logic_vector(ascii'range);
	signal   cga_dot     : std_logic;
	signal   gpannel_row : std_logic_vector(unsigned_num_bits(ly_dptr(layout_id).chan_y)-2 downto unsigned_num_bits(font_height-1));
	signal   gpannel_col : std_logic_vector(unsigned_num_bits(ly_dptr(layout_id).chan_x-1)-1 downto unsigned_num_bits(font_width-1));
	signal   gauge_on    : std_logic_vector(0 to 2+inputs-1);
	signal capture_ena : std_logic;
	constant lat       : natural := 4;
	signal g_hzscale : std_logic_vector(hz_scale'range);
begin

	miirx_e : entity hdl4fpga.scopeio_ip
	port map (
		mii_rxc  => mii_rxc,
		mii_rxdv => mii_rxdv,
		mii_rxd  => mii_rxd,
		pll_data => pll_data,
		pll_rdy  => pll_rdy,
		ser_data => ser_data);

	downsampler_e : entity hdl4fpga.scopeio_downsampler
	port map (
		input_clk   => input_clk,
		input_ena   => input_ena,
		input_data  =>
		factor_data =>
		output_ena  =>
		output_data => );

	equalizer_g : for in 0 to inputs-1 generate
		subtype sample_range is natural i*input_size to (i+1)*input_size-1;
	begin
		equalizer_e : entity hdl4fpga.equalizer
		port map (
			input_clk      => input_clk,
			input_ena      => input_ena,
			input_sample   => input_data(sample_range),
			equalizer_addr => equalizer_addr,
			equalizer_data => equalizer_data,
			output_ena     => output_ena,
			output_sample  => output_data(sample_range));
	end generate;

	scope_trigger_e : entity hdl4fpga.trigger
	port map (
		input_clk       => input_clk,
		input_ena       => input_ena,
		input_data      => input_data,
		trigger_req     => trigger_req,
		trigger_edge    => trigger_edge,
		trigger_channel => trigger_channel,
		trigger_level   => trigger_level,
		capture_rdy     => ,
		capture_req     => ,
		output_data     => );

	graphics_b : block
	begin
		video_e : entity hdl4fpga.video_vga
		generic map (
			mode => ly_dptr(layout_id).mode,
			n    => 11)
		port map (
			clk   => video_clk,
			hsync => video_hs,
			vsync => video_vs,
			hcntr => video_hcntr,
			vcntr => video_vcntr,
			don   => video_hon,
			frm   => video_frm,
			nhl   => video_hzl);

		video_vld <= video_hon and video_frm;

		vgaio_e : entity hdl4fpga.align
		generic map (
			n => video_io'length,
			d => (video_io'range => unsigned_num_bits(ly_dptr(layout_id).chan_height-1)+2+delay))
		port map (
			clk   => video_clk,
			di(0) => video_hs,
			di(1) => video_vs,
			di(2) => video_vld,
			do    => video_io);

		win_mngr_e : entity hdl4fpga.win_mngr
		generic map (
			tab => to_naturalvector(ly_dptr(layout_id)))
		port map (
			video_clk  => video_clk,
			video_x    => video_hcntr,
			video_y    => video_vcntr,
			video_don  => video_hon,
			video_frm  => video_frm,
			win_don    => win_don,
			win_frm    => win_frm);

		scope_cga_e : entity hdl4fpga.scopeio_cga
		generic map (
			font_bitrom => psf1cp850x8x16,
			font_height => 16,
			font_width  => 8)
		port map (
			clk => video_clk,
			x   =>
			y   =>
			dot => cga_dot);

		scopeio_channel_e : entity hdl4fpga.scopeio_channel
		generic map (
			lat         => lat,
			inputs      => inputs,
			num_of_seg  => ly_dptr(layout_id).num_of_seg,
			chan_x      => ly_dptr(layout_id).chan_x,
			chan_width  => ly_dptr(layout_id).chan_width,
			chan_height => ly_dptr(layout_id).chan_height,
			scr_width   => ly_dptr(layout_id).scr_width,
			height      => ly_dptr(layout_id).chan_y,
		port map (
			video_clk   => video_clk,
			video_hzl   => video_hzl,
			win_frm     => win_frm,
			win_on      => win_don,
			samples     => samples,
			vt_pos      => vt_pos,
			trg_lvl     => trg_lvl,
			grid_pxl    => grid_pxl,
			trigger_pxl => trigger_pxl,
			traces_pxls => trace_pxls);

		scopeio_palette_e : entity hdl4fpga.palette
		port map (
			channels_fg  =>,  
			channels_bg  =>, 
			hzaxis_fg    =>, 
			hzaxis_bg    =>, 
			grid_fg      =>, 
			grid_bg      =>, 
			
			tracers_on   =>, 
			objectsfg_on => objects_, 
			objectsbg_on =>, 
			gauges_on    =>, 

			trigger_on   =>, 

			video_clk    => video_clk, 
			video_pixel  => video_pixel);
	end block;

	video_rgb   <= (video_rgb'range => video_io(2)) and video_pixel;
	video_blank <= video_io(2);
	video_hsync <= video_io(0);
	video_vsync <= video_io(1);
	video_sync  <= not video_io(1) and not video_io(0);

end;
