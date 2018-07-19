library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library hdl4fpga;
use hdl4fpga.std.all;
use hdl4fpga.cgafont.all;

entity scopeio is
	generic (
		inputs      : natural := 1;
		vlayout_id  : natural := 0;

		vt_from     : real_vector;
		vt_step     : real_vector;
		vt_scale    : std_logic_vector;
		vt_gain     : natural_vector;
		vt_factsyms : std_logic_vector;
		vt_untsyms  : std_logic_vector;

		hz_from     : real_vector;
		hz_step     : real_vector;
		hz_scale    : std_logic_vector;
		hz_gain     : natural_vector;
		hz_factsyms : std_logic_vector;
		hz_untsyms  : std_logic_vector);
	port (
		si_clk      : in  std_logic := '-';
		si_dv       : in  std_logic := '0';
		si_data     : in  std_logic_vector;
		so_clk      : in  std_logic := '-';
		so_dv       : out  std_logic := '0';
		so_data     : out  std_logic_vector;
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

	type video_layout is record 
		mode        : natural;
		scr_width   : natural;
		num_of_seg  : natural;
		chan_x      : natural;
		chan_y      : natural;
		chan_width  : natural;
		chan_height : natural;
	end record;

	type vlayout_vector is array (natural range <>) of video_layout;

--		      mode, scr_width | num_of_seg | chan_x | chan_y | chan_width | chan_height
	constant vlayout_tab : vlayout_vector(0 to 1) := (
		0 => (   7,      1920,           4,     320,     270,       50*32,          256),
		1 => (   1,       800,           2,     320,     300,       15*32,          256));

	function to_naturalvector (
		constant arg  : video_layout)
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

	signal video_hs         : std_logic;
	signal video_vs         : std_logic;
	signal video_frm        : std_logic;
	signal video_hon        : std_logic;
	signal video_hzl        : std_logic;
	signal video_vld        : std_logic;
	signal video_vcntr      : std_logic_vector(11-1 downto 0);
	signal video_hcntr      : std_logic_vector(11-1 downto 0);

	signal video_io         : std_logic_vector(0 to 3-1);
	
	signal win_don          : std_logic_vector(0 to 18-1);
	signal win_frm          : std_logic_vector(0 to 18-1);


	signal udpso_clk  : std_logic;
	signal udpso_dv   : std_logic;
	signal udpso_data : std_logic_vector(si_data'range);

	constant amp_rid     : natural := 1;
	constant trigger_rid : natural := 2;
	constant hzscale_rid : natural := 3;

	subtype amp_rgtr     is natural range 18-1 downto  1;
	subtype trigger_rgtr is natural range 32-1 downto 18;
	subtype hzscale_rgtr is natural range 40-1 downto 32;

	constant rgtr_map : natural_vector := (
		amp_rid     => 18,
		trigger_rid => 14,
		hzscale_rid => 8);

	signal rgtr_file          : std_logic_vector(hzscale_rgtr'high downto 0);
	signal rgtr_wttn          : std_logic;
	signal rgtr_id            : std_logic_vector(8-1 downto 0);
	signal downsample_ena     : std_logic;
	signal downsample_data    : std_logic_vector(input_data'range);
	signal ampsample_ena      : std_logic;
	signal ampsample_data     : std_logic_vector(input_data'range);
	signal triggersample_ena  : std_logic;
	signal triggersample_data : std_logic_vector(input_data'range);
	signal trigger_req        : std_logic;
	signal capture_rdy        : std_logic;
	signal capture_req        : std_logic;

	constant storage_size : natural := unsigned_num_bits(
		vlayout_tab(vlayout_id).num_of_seg*vlayout_tab(vlayout_id).chan_width-1);
	signal storage_addr : std_logic_vector(0 to storage_size-1);
	signal storage_data : std_logic_vector(input_data'range);

	signal video_pixel : std_logic_vector(video_rgb'range);
begin

	miiip_e : entity hdl4fpga.scopeio_miiudp
	port map (
		mii_rxc  => si_clk,
		mii_rxdv => si_dv,
		mii_rxd  => si_data,

		mii_req  => '-',
		mii_txc  => so_clk,
		mii_txdv => so_dv,
		mii_txd  => so_data,

		so_clk   => udpso_clk,
		so_dv    => udpso_dv,
		so_data  => udpso_data);

	scopeio_sin_e : entity hdl4fpga.scopeio_sin
	generic map (
		rgtr_map => rgtr_map)
	port map (
		sin_clk   => udpso_clk,
		sin_dv    => udpso_dv,
		sin_data  => udpso_data,
		rgtr_wttn => rgtr_wttn,
		rgtr_id   => rgtr_id,
		rgtr_file => rgtr_file);

	downsampler_e : entity hdl4fpga.scopeio_downsampler
	port map (
		input_clk   => input_clk,
		input_ena   => input_ena,
		input_data  => input_data,
		factor_data => rgtr_file(hzscale_rgtr),
		output_ena  => downsample_ena,
		output_data => downsample_data);

	amp_b : block
		subtype amp_chnl is natural range 10-1 downto  0;
		subtype amp_sel  is natural range 18-1 downto 10;

		constant sample_length : natural := input_data'length/inputs;
	begin
		amp_g : for i in 0 to inputs-1 generate
			subtype sample_range is natural range i*sample_length to (i+1)*sample_length-1;

			signal gain_value : std_logic_vector(0 to 18-1);
		begin

			process (so_clk)
			begin
				if rising_edge(so_clk) then
					if to_integer(unsigned(rgtr_file(amp_chnl)))=i then
--						gain_value <= mmm(to_integer(unsigned(rgtr_file(amp_sel))));
					end if;
				end if;
			end process;

			amp_e : entity hdl4fpga.scopeio_amp
			port map (
				input_clk     => input_clk,
				input_ena     => downsample_ena,
				input_sample  => downsample_data(sample_range),
				gain_value    => gain_value,
				output_ena    => ampsample_ena,
				output_sample => ampsample_data(sample_range));

		end generate;
	end block;

	scopeio_trigger_e : entity hdl4fpga.scopeio_trigger
	generic map (
		inputs => inputs)
	port map (
		input_clk    => input_clk,
		input_ena    => ampsample_ena,
		input_data   => ampsample_data,
		trigger_req  => trigger_req,
		trigger_rgtr => rgtr_file(trigger_rgtr),
		capture_rdy  => capture_rdy,
		capture_req  => capture_req,
		output_data  => triggersample_data);

	storage_b : block

		signal mem_full : std_logic;
		signal mem_clk  : std_logic;

		signal wr_clk   : std_logic;
		signal wr_ena   : std_logic;
		signal wr_addr  : std_logic_vector(storage_addr'range);
		signal wr_data  : std_logic_vector(triggersample_data'range);
		signal rd_clk   : std_logic;
		signal rd_addr  : std_logic_vector(wr_addr'range);
		signal rd_data  : std_logic_vector(wr_data'range);

	begin

		capture_rdy <= mem_full;
		wr_clk      <= input_clk;
		wr_ena      <= capture_req;
		wr_data     <= triggersample_data;

		process (wr_clk)
			variable aux : unsigned(0 to wr_addr'length);
		begin
			if rising_edge(wr_clk) then
				if wr_ena='0' then
					aux := (others => '0');
				else
					aux := aux + 1;
				end if;
				wr_addr  <= std_logic_vector(aux(1 to wr_addr'length));
				mem_full <= aux(0);
			end if;
		end process;

		rd_addr_e : entity hdl4fpga.align
		generic map (
			n => rd_addr'length,
			d => (rd_addr'range => 1))
		port map (
			clk => rd_clk,
			di  => storage_addr,
			do  => rd_addr);

		mem_e : entity hdl4fpga.dpram 
		port map (
			wr_clk  => wr_clk,
			wr_ena  => wr_ena,
			wr_addr => wr_addr,
			wr_data => wr_data,
			rd_addr => rd_addr,
			rd_data => rd_data);

		rd_data_e : entity hdl4fpga.align
		generic map (
			n => rd_data'length,
			d => (rd_data'range => 1))
		port map (
			clk => rd_clk,
			di  => rd_data,
			do  => storage_data);

	end block;

	graphics_b : block
		constant lat       : natural := 4;
		constant vgaio_lat : natural := unsigned_num_bits(vlayout_tab(vlayout_id).chan_height-1)+2+lat;
	begin
		video_e : entity hdl4fpga.video_vga
		generic map (
			mode => vlayout_tab(vlayout_id).mode,
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
			d => (video_io'range => vgaio_lat))
		port map (
			clk   => video_clk,
			di(0) => video_hs,
			di(1) => video_vs,
			di(2) => video_vld,
			do    => video_io);

		win_mngr_e : entity hdl4fpga.win_mngr
		generic map (
			tab => to_naturalvector(vlayout_tab(vlayout_id)))
		port map (
			video_clk  => video_clk,
			video_x    => video_hcntr,
			video_y    => video_vcntr,
			video_don  => video_hon,
			video_frm  => video_frm,
			win_don    => win_don,
			win_frm    => win_frm);

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
			samples     => storage_data,
			vt_pos      => vt_pos,
			trg_lvl     => trg_lvl,
			grid_pxl    => grid_pxl,
			trigger_pxl => trigger_pxl,
			traces_pxls => trace_pxls);
--
--		scopeio_palette_e : entity hdl4fpga.palette
--		port map (
--			channels_fg  =>,  
--			channels_bg  =>, 
--			hzaxis_fg    =>, 
--			hzaxis_bg    =>, 
--			grid_fg      =>, 
--			grid_bg      =>, 
--			
--			tracers_on   =>, 
--			objectsfg_on => objects_, 
--			objectsbg_on =>, 
--			gauges_on    =>, 
--
--			trigger_on   =>, 
--
--			video_clk    => video_clk, 
--			video_pixel  => video_pixel);
	end block;

	video_rgb   <= (video_rgb'range => video_io(2)) and video_pixel;
	video_blank <= video_io(2);
	video_hsync <= video_io(0);
	video_vsync <= video_io(1);
	video_sync  <= not video_io(1) and not video_io(0);

end;
