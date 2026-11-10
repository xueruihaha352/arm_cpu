#!/bin/sh
set -eu

# 无论从哪里执行脚本，都切换到脚本所在目录，确保 program.hex 可被找到。
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}
SURFER=${SURFER:-surfer}
OPEN_WAVE=1

if [ "${1:-}" = "--no-wave" ]; then
    OPEN_WAVE=0
    shift
fi

if [ "$#" -ne 0 ]; then
    printf '用法: %s [--no-wave]\n' "$0" >&2
    exit 2
fi

for tool in "$IVERILOG" "$VVP"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf '错误：找不到 %s，请确认已安装或设置对应环境变量。\n' "$tool" >&2
        exit 127
    fi
done

printf '[1/3] 使用 Icarus Verilog 编译...\n'
"$IVERILOG" -g2012 -Wall -o arm_cpu.vvp arm_single_cycle.v tb_arm_single_cycle.v

printf '[2/3] 运行 testbench...\n'
"$VVP" arm_cpu.vvp

if [ "$OPEN_WAVE" -eq 1 ]; then
    if ! command -v "$SURFER" >/dev/null 2>&1; then
        printf '仿真已完成，但找不到 Surfer。波形已保存为 %s/arm_cpu.vcd\n' "$SCRIPT_DIR" >&2
        exit 127
    fi
    printf '[3/3] 在 Surfer 中打开波形...\n'
    "$SURFER" arm_cpu.vcd
else
    printf '[3/3] 已跳过 Surfer；波形文件为 %s/arm_cpu.vcd\n' "$SCRIPT_DIR"
fi
