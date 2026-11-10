`timescale 1ns/1ps

// CPU 的仿真测试平台：产生时钟/复位、观察执行过程，并在末尾自动判定结果。
module tb_arm_single_cycle;
    reg clk = 1'b0;               // 初始时钟为低
    reg reset = 1'b1;             // 先保持复位
    wire [31:0] pc;
    wire [31:0] instruction;
    // 将 DUT 内部数组元素导出为普通信号，方便 VCD/Surfer 观察。
    wire [31:0] debug_r2;
    wire [31:0] debug_r3;
    wire [31:0] debug_r4;
    wire [31:0] debug_r6;
    wire [31:0] debug_mem_40;

    // 被测设计（Device Under Test）。
    arm_single_cycle dut (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .instruction(instruction)
    );

    assign debug_r2 = dut.regs[2];
    assign debug_r3 = dut.regs[3];
    assign debug_r4 = dut.regs[4];
    assign debug_r6 = dut.regs[6];
    assign debug_mem_40 = dut.dmem[16]; // 字地址 0x40 对应 dmem[16]

    always #5 clk = ~clk;         // 每 5ns 翻转，时钟周期为 10ns

    initial begin
        // 记录全部层级信号，生成 arm_cpu.vcd 供 GTKWave 查看。
        $dumpfile("arm_cpu.vcd");
        $dumpvars(0, tb_arm_single_cycle);
        $display(" cycle       pc   instruction");

        // 让 CPU 经历两个复位上升沿，然后在下降沿附近解除复位。
        repeat (2) @(posedge clk);
        #1 reset = 1'b0;

        // 程序共 11 条指令；每次上升沿后延迟 1ns，等非阻塞赋值更新完再打印。
        repeat (11) begin
            @(posedge clk);
            #1 $display(" %5d  %08x  %08x", $time / 10, pc, instruction);
        end

        // 直接检查 DUT 内部寄存器和数据 RAM，覆盖算术、分支及访存结果。
        // !== 也会把 X/Z 未知值判为失败。
        if (dut.regs[2] !== 32'd12) $fatal(1, "ADD failed: r2=%0d", dut.regs[2]);
        if (dut.regs[3] !== 32'd0)  $fatal(1, "SUBS failed: r3=%0d", dut.regs[3]);
        if (dut.regs[4] !== 32'd42) $fatal(1, "BEQ failed to skip MOV r4,#99: r4=%0d", dut.regs[4]);
        if (dut.regs[6] !== 32'd42) $fatal(1, "LDR failed: r6=%0d", dut.regs[6]);
        if (dut.dmem[16] !== 32'd42) $fatal(1, "STR failed: mem[0x40]=%0d", dut.dmem[16]);

        // 所有检查都通过才会执行到这里。
        $display("PASS: arithmetic, BEQ, STR and LDR checks passed.");
        $finish;
    end
endmodule
