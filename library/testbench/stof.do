onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/stof_e/clk
add wave -noupdate /testbench/stof_e/bcd_frm
add wave -noupdate /testbench/stof_e/bcd_irdy
add wave -noupdate /testbench/stof_e/bcd_trdy
add wave -noupdate /testbench/stof_e/fix_irdy
add wave -noupdate /testbench/stof_e/fix_trdy
add wave -noupdate -radix decimal /testbench/stof_e/bcd_left
add wave -noupdate -radix decimal /testbench/stof_e/bcd_right
add wave -noupdate -radix hexadecimal -childformat {{/testbench/stof_e/fix_do(0) -radix hexadecimal} {/testbench/stof_e/fix_do(1) -radix hexadecimal} {/testbench/stof_e/fix_do(2) -radix hexadecimal} {/testbench/stof_e/fix_do(3) -radix hexadecimal} {/testbench/stof_e/fix_do(4) -radix hexadecimal} {/testbench/stof_e/fix_do(5) -radix hexadecimal} {/testbench/stof_e/fix_do(6) -radix hexadecimal} {/testbench/stof_e/fix_do(7) -radix hexadecimal} {/testbench/stof_e/fix_do(8) -radix hexadecimal} {/testbench/stof_e/fix_do(9) -radix hexadecimal} {/testbench/stof_e/fix_do(10) -radix hexadecimal} {/testbench/stof_e/fix_do(11) -radix hexadecimal} {/testbench/stof_e/fix_do(12) -radix hexadecimal} {/testbench/stof_e/fix_do(13) -radix hexadecimal} {/testbench/stof_e/fix_do(14) -radix hexadecimal} {/testbench/stof_e/fix_do(15) -radix hexadecimal} {/testbench/stof_e/fix_do(16) -radix hexadecimal} {/testbench/stof_e/fix_do(17) -radix hexadecimal} {/testbench/stof_e/fix_do(18) -radix hexadecimal} {/testbench/stof_e/fix_do(19) -radix hexadecimal} {/testbench/stof_e/fix_do(20) -radix hexadecimal} {/testbench/stof_e/fix_do(21) -radix hexadecimal} {/testbench/stof_e/fix_do(22) -radix hexadecimal} {/testbench/stof_e/fix_do(23) -radix hexadecimal}} -subitemconfig {/testbench/stof_e/fix_do(0) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(1) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(2) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(3) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(4) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(5) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(6) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(7) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(8) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(9) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(10) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(11) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(12) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(13) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(14) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(15) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(16) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(17) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(18) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(19) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(20) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(21) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(22) {-height 18 -radix hexadecimal} /testbench/stof_e/fix_do(23) {-height 18 -radix hexadecimal}} /testbench/stof_e/fix_do
add wave -noupdate -divider {New Divider}
add wave -noupdate -radix hexadecimal /testbench/stof_e/fixfmt_p/fmt
add wave -noupdate -radix hexadecimal /testbench/stof_e/fixfmt_p/codes
add wave -noupdate -radix hexadecimal /testbench/stof_e/fixidx_d
add wave -noupdate -radix hexadecimal /testbench/stof_e/fixidx_q
add wave -noupdate -radix hexadecimal /testbench/stof_e/bcdidx_q
add wave -noupdate -radix hexadecimal /testbench/stof_e/bcdidx_d
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {156 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {416 ns}
