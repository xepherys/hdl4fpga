library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library hdl4fpga;
use hdl4fpga.std.all;
use hdl4fpga.scopeiopkg.all;

entity scopeio_segment is
	generic(
		input_latency : natural;
		latency       : natural;
		layout        : display_layout;
		axis_unit     : std_logic_vector := std_logic_vector(to_unsigned(25,5));
		inputs        : natural);
	port (
		rgtr_clk      : in  std_logic;
		rgtr_dv       : in  std_logic;
		rgtr_id       : in  std_logic_vector(8-1 downto 0);
		rgtr_data     : in  std_logic_vector;

		btof_binfrm   : buffer std_logic;
		btof_binirdy  : out std_logic;
		btof_bintrdy  : in  std_logic;
		btof_bindi    : out std_logic_vector;
		btof_unit     : out std_logic_vector;
		btof_neg      : out std_logic;
		btof_sign     : out std_logic;
		btof_align    : out std_logic;
		btof_bcdfrm   : in  std_logic;
		btof_bcdirdy  : in  std_logic;
		btof_bcdtrdy  : buffer std_logic;
		btof_bcdend   : in  std_logic;
		btof_bcddo    : in  std_logic_vector;

		hz_dv         : in  std_logic;
		hz_scale      : in  std_logic_vector;
		hz_base       : in  std_logic_vector;
		hz_offset     : in  std_logic_vector;

		gain_dv       : in  std_logic;
		gain_ids      : in  std_logic_vector;

		trigger_level : in  std_logic_vector;

		video_clk     : in  std_logic;
		x             : in  std_logic_vector;
		y             : in  std_logic_vector;

		grid_on       : in  std_logic;
		hz_on         : in  std_logic;
		vt_on         : in  std_logic;

		sample_dv     : in  std_logic;
		sample_data   : in  std_logic_vector;

		hz_dot        : out std_logic;
		vt_dot        : out std_logic;
		grid_dot      : out std_logic;
		trigger_dot   : out std_logic;
		trace_dots    : out std_logic_vector);
end;

architecture def of scopeio_segment is

	signal vt_dv           : std_logic;
	signal vt_offsets      : std_logic_vector(inputs*(5+8)-1 downto 0);
	signal vt_chanid       : std_logic_vector(chanid_maxsize-1 downto 0);

	constant division_size : natural := grid_divisionsize(layout);
	constant font_size     : natural := axis_fontsize(layout);
	constant vt_height     : natural := grid_height(layout);

	constant division_bits : natural := unsigned_num_bits(division_size-1);
	constant vttick_bits   : natural := unsigned_num_bits(8*font_size-1);
	constant vtstep_bits   : natural := setif(vtaxis_tickrotate(layout)=ccw0, division_bits, vttick_bits);
	constant vtheight_bits : natural := unsigned_num_bits((vt_height-1)-1);

	signal vt_scale     : std_logic_vector(gain_ids'length/inputs-1 downto 0);
	signal vt_offset : std_logic_vector(vt_offsets'length/inputs-1 downto 0);

	signal axis_dv      : std_logic := '0';
	signal axis_sel     : std_logic;
	signal axis_scale   : std_logic_vector(4-1 downto 0);
	signal axis_base    : std_logic_vector(max(hz_base'length, vtheight_bits-(vtstep_bits+axisy_backscale))-1 downto 0);


begin

	scopeio_rgtrvtaxis_e : entity hdl4fpga.scopeio_rgtrvtaxis
	generic map (
		inputs  => inputs)
	port map (
		rgtr_clk   => rgtr_clk,
		rgtr_dv    => rgtr_dv,
		rgtr_id    => rgtr_id,
		rgtr_data  => rgtr_data,

		vt_dv      => vt_dv,
		vt_chanid  => vt_chanid,
		vt_offsets => vt_offsets);

	vt_scale  <= word2byte(gain_ids,   vt_chanid, vt_scale'length);
	vt_offset <= word2byte(vt_offsets, vt_chanid, vt_offset'length);
	grid_b : block
		constant offset_latency : natural := 1;

		signal y_grid   : std_logic_vector(y'range);
		signal x_grid   : std_logic_vector(x'range);
		signal grid_ena : std_logic;
	begin

		offset_p : process (video_clk)
			constant bias : natural := (vt_height/2) mod division_size;
		begin
			if rising_edge(video_clk) then
				y_grid   <= std_logic_vector(unsigned(y) + bias);
				x_grid   <= std_logic_vector(unsigned(x) + unsigned(hz_offset(division_bits-1 downto 0)));
				grid_ena <= grid_on;
			end if;
		end process;

		grid_e : entity hdl4fpga.scopeio_grid
		generic map (
			latency => latency-offset_latency,
			division_size => division_size)
		port map (
			clk  => video_clk,
			ena  => grid_ena,
			x    => x_grid,
			y    => y_grid,
			dot  => grid_dot);
	end block;

	axis_b : block
		signal v_offset : std_logic_vector(vt_offset'range);
	begin
		process (rgtr_clk)
		begin
			if rising_edge(rgtr_clk) then
				if vt_dv='1' or gain_dv='1' then
					axis_sel <= '1';
					axis_dv  <= '1';
				elsif hz_dv='1' then
					axis_sel <= '0';
					axis_dv  <= '1';
				else
					axis_dv  <= '0';
				end if;
			end if;
		end process;
		axis_scale <= word2byte(hz_scale & std_logic_vector(resize(unsigned(vt_scale), axis_scale'length)), axis_sel);

		bias_p : process (rgtr_clk)
			constant bias : natural := (vt_height/2) mod 2**vtstep_bits;
		begin
			if rising_edge(rgtr_clk) then
				v_offset <= std_logic_vector(unsigned(vt_offset) - bias);
			end if;
		end process;

		process (axis_sel, hz_base, v_offset)
			variable vt_base : std_logic_vector(v_offset'range);
		begin
			vt_base   := std_logic_vector(shift_right(signed(v_offset), vtstep_bits+axisy_backscale));
			axis_base <= word2byte(hz_base & vt_base(axis_base'range), axis_sel);
		end process;

		axis_e : entity hdl4fpga.scopeio_axis
		generic map (
			latency     => latency,
			axis_unit   => axis_unit,
			layout      => layout)
		port map (
			clk         => rgtr_clk,

			axis_dv     => axis_dv,
			axis_sel    => axis_sel,
			axis_base   => axis_base,
			axis_scale  => axis_scale,

			btof_binfrm  => btof_binfrm,
			btof_binirdy => btof_binirdy,
			btof_bintrdy => btof_bintrdy,
			btof_bindi   => btof_bindi,
			btof_unit    => btof_unit,
			btof_neg     => btof_neg,
			btof_sign    => btof_sign,
			btof_align   => btof_align,
			btof_bcdfrm  => btof_bcdfrm,
			btof_bcdirdy => btof_bcdirdy,
			btof_bcdtrdy => btof_bcdtrdy,
			btof_bcdend  => btof_bcdend,
			btof_bcddo   => btof_bcddo,

			video_clk   => video_clk,
			video_hcntr => x,
			video_vcntr => y,

			hz_offset   => hz_offset,
			video_hzon  => hz_on,
			video_hzdot => hz_dot,

			vt_offset   => v_offset(vtstep_bits+axisy_backscale-1 downto 0),
			video_vton  => vt_on,
			video_vtdot => vt_dot);
	end block;

	trigger_b : block 
		signal offset : unsigned(vt_offsets'length/inputs-1 downto 0);
		signal row  : unsigned(trigger_level'range);
		signal ena  : std_logic;
		signal hdot : std_logic;
	begin
		process (rgtr_clk)
		begin
			if rising_edge(rgtr_clk) then
				offset <= vt_height/2-unsigned(word2byte(vt_offsets, vt_chanid, offset'length));
			end if;
		end process;

		row <= resize(unsigned(trigger_level)+offset, row'length);
		ena <= grid_on when resize(unsigned(y), row'length)=row else '0';

		hline_e : entity hdl4fpga.draw_line
		port map (
			ena   => ena,
			mask  => b"1",
			x     => x,
			dot   => hdot);

		align_e :entity hdl4fpga.align
		generic map (
			n => 1,
			d => (0 => latency))
		port map (
			clk   => video_clk,
			di(0) => hdot,
			do(0) => trigger_dot);

	end block;

	trace_b : block
		constant drawvline_latency : natural := 1;
		constant traceena_latency  : natural := 2;

		signal dots : std_logic_vector(0 to trace_dots'length-1);
		signal vline : std_logic_vector(y'range);
	begin

		delay_y_e :entity hdl4fpga.align
		generic map (
			n => y'length,
			d => (0 to y'length-1 => input_latency))
		port map (
			clk => video_clk,
			di  => y,
			do  => vline);

		tracer_e : entity hdl4fpga.scopeio_tracer
		generic map (
			vt_height => vt_height)
		port map (
			clk      => video_clk,
			ena      => sample_dv,
			vline    => vline,
			offsets  => vt_offsets,
			ys       => sample_data,
			dots     => dots);

		align_e :entity hdl4fpga.align
		generic map (
			n => trace_dots'length,
			d => (0 to trace_dots'length-1 => latency-(input_latency+drawvline_latency)))
		port map (
			clk => video_clk,
			di  => dots,
			do  => trace_dots);

	end block;

end;
