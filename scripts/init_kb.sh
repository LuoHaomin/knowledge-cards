#!/bin/bash
# 初始化一个卡片式知识库：建板块目录、安装维护脚本
# 用法：init_kb.sh <目标目录> <板块1> <板块2> ...
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

# 安装维护脚本（幂等）
cp "$SKILL_DIR/生成导航.sh" "$SKILL_DIR/布局画布.sh" "$TARGET/"
chmod +x "$TARGET/生成导航.sh" "$TARGET/布局画布.sh"

# 生成空的总览画布骨架
if [ ! -f "$TARGET/知识总览.canvas" ]; then
    printf '{\n\t"nodes":[],\n\t"edges":[]\n}\n' > "$TARGET/知识总览.canvas"
fi

# 生成第一版导航
cd "$TARGET" && ./生成导航.sh

echo "知识库已初始化：$TARGET"
echo "日常维护：新卡放入板块文件夹；任何时候运行 ./生成导航.sh 刷新索引"
