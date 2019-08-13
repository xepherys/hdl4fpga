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

entity pll2ser is
    port (
		clk      : in  std_logic;
		frm      : in  std_logic := '1';
		pll_irdy : in  std_logic := '1';
		pll_trdy : out std_logic;
		pll_data : in  std_logic_vector;
		ser_trdy : in  std_logic := '1';
		ser_irdy : out std_logic;
		ser_end  : out std_logic;
		ser_data : out std_logic_vector);
end;

architecture def of pll2ser is
begin

	process (clk)
		variable sr   : unsigned(0 to pll_data'length/ser_data'length-1);
		variable data : unsigned(0 to pll_data'length-1);
		variable frm1 : std_logic;
	begin
		if rising_edge(clk) then
			if frm='1' then
				if frm1='0' then
					sr   := to_unsigned(1, sr'length);
					data := unsigned(pll_data);
				elsif pll_irdy='1' then
					if ser_trdy='1' then
						sr   := sr   rol 1;
						data := data rol ser_data'length;
					end if;
				end if;
			end if;
			pll_trdy <= sr(0) and ser_trdy;
			ser_end  <= sr(0);
			ser_data <= std_logic_vector(data(0 to ser_data'length-1));
			frm1     := frm;
		end if;
	end process;
	ser_irdy <= pll_irdy;

end;
