--                                                                            --
-- Author(s):                                                                 --
--   Miguel Angel Sagreras                                                    --
--                                                                            --
-- Copyright (C) 2015                                                         --
--    Miguel Angel Sagreras                                                   --
--                                                                            --
-- This source file may be used and distributed without restriction provided  --
-- that this copyright statement is not removed from the file and that any    --
-- derivative work contains  the original copyright notice and the associated --
-- disclaimer.                                                                --
--                                                                            --
-- This source file is free software; you can redistribute it and/or modify   --
-- it under the terms of the GNU General Public License as published by the   --
-- Free Software Foundation, either version 3 of the License, or (at your     --
-- option) any later version.                                                 --
--                                                                            --
-- This source is distributed in the hope that it will be useful, but WITHOUT --
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or      --
-- FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for   --
-- more details at http://www.gnu.org/licenses/.                              --
--                                                                            --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library hdl4fpga;
use hdl4fpga.std.all;

entity scopeio_format is
	port (
		clk        : in  std_logic;
		binary     : in  std_logic_vector;
		binary_ena : in std_logic;
		point      : in  std_logic_vector;
		bcd_left   : in std_logic;
		bcd_dv     : out std_logic;
		bcd_dat    : out std_logic_vector);
end;

architecture def of scopeio_format is

	signal bin_ena : std_logic;
    signal bin_dv  : std_logic;
    signal bin_di  : std_logic_vector(0 to 4-1);

    signal bcd_rdy : std_logic;
    signal bin_fix : std_logic;
    signal bcd_do  : std_logic_vector(0 to 4-1);

begin

	xxx_b : block
		constant num_of_steps : natural := binary'length/bin_di'length;
		signal sel : std_logic_vector(0 to unsigned_num_bits(num_of_steps-1)-1);
	begin

		process (clk, binary_ena)
			variable cntr : unsigned(0 to sel'length);
			variable ena  : std_logic;
			variable dv  : std_logic;
		begin
			if rising_edge(clk) then
				bcd_dv <= dv;
				if binary_ena='0' then
					ena    := '0';
					dv := '0';
					cntr   := to_unsigned(num_of_steps-2, cntr'length);
				elsif bcd_rdy='1' then
					if cntr(0)='1' then
						ena    := '0';
						dv := '1';
						cntr   := to_unsigned(num_of_steps-2, cntr'length);
					elsif cntr(0)='0' then
						ena    := '1';
						dv := '0';
						cntr   := cntr - 1;
					end if;
				else
					ena    := '1';
					dv := '0';
				end if;
				sel  <= std_logic_vector(cntr(1 to cntr'right));
			end if;
			bin_ena <= ena and binary_ena;
		end process;

		process (binary, sel)
			variable value : std_logic_vector(bin_di'length*2**sel'length-1 downto 0);
		begin
			value  := (others => '-');
			value(binary'length-1 downto 0) := binary;
			value  := std_logic_vector(unsigned(value) ror bin_di'length);
			bin_di <= word2byte(std_logic_vector(value), not std_logic_vector(sel));
		end process;

	end block;

	scopeio_ftod_e : entity hdl4fpga.scopeio_ftod
	port map (
		clk     => clk,
		bin_ena => bin_ena,
		bin_dv  => bin_dv,
		bin_di  => bin_di,
                           
		bcd_rdy => bcd_rdy,
		bcd_do  => bcd_do);

	format_b : block
		signal value : std_logic_vector(0 to bcd_dat'length-1);
		signal right : std_logic_vector(0 to bcd_dat'length-1);
		signal float : std_logic_vector(0 to bcd_dat'length-1);
		signal sign  : std_logic_vector(0 to bcd_dat'length-1);
		signal f : std_logic_vector(0 to bcd_dat'length-1);

	begin

		process (clk)
			variable ena : std_logic;
		begin
			if rising_edge(clk) then
				if ena='1' then
					value <= push_left((value'range => '1'), bcd_do);
				else
					value <= push_left(value, bcd_do);
				end if;
				ena := bcd_rdy;
				float <= f;
			end if;
		end process;

		alignright_e  : entity hdl4fpga.align_bcd
		port map (
			value  => value,
			align  => right);
		
		sign_e : entity hdl4fpga.sign_bcd
		port map (
			value    => right,
			negative => '1',
			sign     => '1',
			format   => sign);
		
		formatbcd_e : entity hdl4fpga.format_bcd
		port map (
			value  => sign,
			point  => point,
			format => f);

		alignbcd_e  : entity hdl4fpga.align_bcd
		port map (
			left  => bcd_left,
			value => float,
			align => bcd_dat);
		
	end block;

end;
