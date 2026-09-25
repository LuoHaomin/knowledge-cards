#!/bin/bash
# 初始化一个卡片式知识库：建板块目录、总览画布骨架、第一版导航
# Agent 用法（从 skill 目录以绝对路径调用，不复制脚本进知识库）：
#   bash <skill目录>/scripts/init_kb.sh <目标目录> <板块1> <板块2> ...
#   板块名会自动加数字前缀（01-、02-…），如：
#   init_kb.sh ~/Work/学习/线性代数 基础概念 矩阵理论 谱理论

set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -lt 2 ]; then
    echo "用法: init_kb.sh <目标目录> <板块1> <板块2> ..." >&2
    exit 1
fi

TARGET="$1"; shift
mkdir -p "$TARGET"

i=1
for board in "$@"; do
    n=$(printf "%02d" $i)
    mkdir -p "$TARGET/${n}-${board}"
    i=$((i+1))
done

# 生成空的总览画布骨架
if [ ! -f "$TARGET/知识总览.canvas" ]; then
    printf '{\n\t"nodes":[],\n\t"edges":[]\n}\n' > "$TARGET/知识总览.canvas"
fi

# 生成第一版导航
bash "$SKILL_DIR/生成导航.sh" "$TARGET"

echo "知识库已初始化：$TARGET"
