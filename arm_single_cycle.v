`timescale 1ns/1ps

//  ARM 状态单周期 CPU：一条指令在一个时钟上升沿完成状态更新。
module arm_single_cycle (
    input  wire        clk,
    input  wire        reset,
    output reg  [31:0] pc,
    output wire [31:0] instruction
);
    reg [31:0] imem [0:63];       // 64 个字的指令 ROM
    reg [31:0] dmem [0:63];       // 64 个字的数据 RAM，按字对齐访问
    reg [31:0] regs [0:15];       // ARM 通用寄存器组；R15 不作为普通寄存器写入
    reg        zero_flag;         // SUBS 更新的 Z 标志，供 EQ 条件使用

    // 组合逻辑产生的下一状态、ALU 结果和写回/访存控制。
    reg [31:0] next_pc;
    reg [31:0] writeback_value;
    reg [31:0] alu_result;
    reg [31:0] memory_address;
    reg        reg_write;
    reg        mem_write;
    reg        flag_write;
    reg [3:0]  destination;
    reg [31:0] immediate;
    reg [3:0]  opcode;
    reg [31:0] operand_a;
    integer i;

    // PC 是字节地址；忽略低两位后作为指令 ROM 的字索引。
    assign instruction = imem[pc[7:2]];

    // ARM 数据处理立即数：8 位常数右旋 (rotate_imm * 2) 位。
    function [31:0] ror32;
        input [31:0] value;
        input [4:0] amount;
        begin
            if (amount == 0)
                ror32 = value;
            else
                ror32 = (value >> amount) | (value << (32 - amount));
        end
    endfunction

    initial begin
        // 未写入指令的 ROM 位置填入 NOP，数据 RAM 和寄存器初值清零。
        for (i = 0; i < 64; i = i + 1) begin
            imem[i] = 32'hE1A00000; // ARM NOP: MOV r0, r0
            dmem[i] = 32'b0;
        end
        for (i = 0; i < 16; i = i + 1)
            regs[i] = 32'b0;
        // 仿真启动目录应为本目录；加载 program.hex 的 11 条测试指令。
        $readmemh("program.hex", imem, 0, 10);
    end

    // 组合数据通路：默认顺序执行，只有有效指令才覆盖默认控制值。
    always @* begin
        next_pc         = pc + 32'd4;
        writeback_value = 32'b0;
        alu_result      = 32'b0;
        memory_address  = 32'b0;
        reg_write       = 1'b0;
        mem_write       = 1'b0;
        flag_write      = 1'b0;
        destination     = instruction[15:12];
        immediate       = 32'b0;
        opcode          = instruction[24:21];
        operand_a       = regs[instruction[19:16]];

        // 条件字段只实现 AL（总是执行）和 EQ（Z 标志为 1 时执行）。
        if ((instruction[31:28] == 4'hE) ||
            ((instruction[31:28] == 4'h0) && zero_flag)) begin
            if (instruction[27:25] == 3'b101) begin
                // B：ARM 分支基准是当前 PC+8，偏移是符号扩展后左移两位。
                next_pc = pc + 32'd8 + {{6{instruction[23]}}, instruction[23:0], 2'b00};
            end else if ((instruction[27:26] == 2'b01) && instruction[24] &&
                         instruction[23] && !instruction[22] && !instruction[25]) begin
                // LDR/STR：仅支持字访问、立即数正偏移、pre-index 寻址。
                memory_address = regs[instruction[19:16]] + {20'b0, instruction[11:0]};
                if (instruction[20]) begin
                    // LDR：组合读取数据 RAM，写回目标寄存器。
                    writeback_value = dmem[memory_address[7:2]];
                    reg_write = 1'b1;
                end else begin
                    // STR：在时钟上升沿把目标寄存器内容写入 RAM。
                    mem_write = 1'b1;
                end
            end else if (instruction[27:26] == 2'b00 && instruction[25]) begin
                // 数据处理立即数指令：先按 ARM 编码还原 32 位立即数。
                immediate = ror32({24'b0, instruction[7:0]},
                                  {instruction[11:8], 1'b0});
                operand_a = regs[instruction[19:16]];
                case (opcode)
                    4'b1101: begin // MOV Rd, #imm
                        alu_result = immediate;
                        reg_write = 1'b1;
                    end
                    4'b0100: begin // ADD Rd, Rn, #imm
                        alu_result = operand_a + immediate;
                        reg_write = 1'b1;
                    end
                    4'b0010: begin // SUB/SUBS Rd, Rn, #imm
                        alu_result = operand_a - immediate;
                        reg_write = 1'b1;
                    end
                    default: begin
                        alu_result = 32'b0;
                    end
                endcase
                if (reg_write) begin
                    writeback_value = alu_result;
                    // S 位为 1 时更新 Z；本最小版本只维护 Z 标志。
                    flag_write = instruction[20];
                end
            end
        end
    end

    // 时序状态：复位清 PC/寄存器/Z；正常上升沿提交 PC、写回和内存写入。
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc        <= 32'b0;
            zero_flag <= 1'b0;
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 32'b0;
        end else begin
            pc <= next_pc;
            if (reg_write && destination != 4'd15)
                regs[destination] <= writeback_value;
            if (flag_write)
                zero_flag <= (alu_result == 32'b0);
            if (mem_write)
                dmem[memory_address[7:2]] <= regs[instruction[15:12]];
        end
    end
endmodule
