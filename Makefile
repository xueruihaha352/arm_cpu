IVERILOG ?= iverilog
VVP ?= vvp

.PHONY: all compile run clean

all: run

compile:
	$(IVERILOG) -g2012 -Wall -o arm_cpu.vvp arm_single_cycle.v tb_arm_single_cycle.v

run: compile
	$(VVP) arm_cpu.vvp

clean:
	rm -f arm_cpu.vvp arm_cpu.vcd
