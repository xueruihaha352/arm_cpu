# ARM 单周期 CPU 最小仿真

这是一个教学用 ARM 状态（32 位 ARM 指令编码）单周期 CPU，不是完整 ARM 兼容处理器。

## 支持范围

- 数据处理立即数：`MOV`、`ADD`、`SUB`，支持 ARM 8-bit rotated immediate 编码
- `SUBS` 可更新 Z 标志
- 条件字段仅支持 `AL` 和 `EQ`
- `B`，按 ARM 的 `PC + 8` 规则计算分支目标
- 字对齐 `LDR` / `STR`，仅支持立即数正偏移、pre-index 寻址
- 寄存器 R0-R14 可用于通用数据；R15 写入会被忽略，不实现作为操作数的 PC 行为

指令存储器和数据存储器都采用组合读，以便访存指令在一个周期内完成。指令 ROM 从当前运行目录的 `program.hex` 初始化。

## 运行

需要安装 Icarus Verilog。进入本目录后执行 Makefile：

```sh
make
```

测试平台会检查算术、`BEQ` 跳转、`STR` 和 `LDR`，成功时输出 `PASS`，并生成 `arm_cpu.vcd`。可用 GTKWave 打开波形：

```sh
gtkwave arm_cpu.vcd
```

也可以使用一键脚本编译、运行测试并在 Surfer 中打开波形：

```sh
./run_sim.sh
```

只运行仿真、不打开 Surfer：

```sh
./run_sim.sh --no-wave
```

## 文件

- `arm_single_cycle.v`：CPU RTL
- `program.hex`：ARM 指令机器码测试程序
- `tb_arm_single_cycle.v`：自动检查的 testbench


