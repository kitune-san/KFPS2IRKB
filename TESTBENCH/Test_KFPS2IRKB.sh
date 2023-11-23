#!/bin/sh

iverilog -o tb.vvp KFPS2IRKB_tb.sv ../HDL/KFPS2IRKB.sv ../HDL/KFPS2KB.sv ../HDL/KFPS2KB_Shift_Register.sv -g2012 -DIVERILOG
vvp tb.vvp
gtkwave tb.vcd

