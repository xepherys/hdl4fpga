library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity scopeio_pointer is
	generic (
		latency     : natural := 0);
	port (
		video_clk   : in  std_logic;
		pointer_x   : in  std_logic_vector;
		pointer_y   : in  std_logic_vector;
		video_on    : in  std_logic;
		video_hcntr : in  std_logic_vector;
		video_vcntr : in  std_logic_vector;
		video_dot   : out std_logic);
end;

architecture beh of scopeio_pointer is

	signal R_video_hcntr_aligned: signed(video_hcntr'range);

begin

	process(video_clk)
	begin
		if rising_edge(video_clk) then
			if video_on='0' then
				R_video_hcntr_aligned <= to_signed(0, video_hcntr'length);
			else
				R_video_hcntr_aligned <= R_video_hcntr_aligned+1;
			end if;
		end if;
	end process;

	video_dot <= '1' when R_video_hcntr_aligned = signed(pointer_x) or video_vcntr = pointer_y else '0';

end;
