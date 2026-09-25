#!/bin/bash
# 生成 导航.md：按板块列出全部卡片（双链、tags、一句话摘要）+ 断链报告
# 用法：在知识库目录下执行  ./生成导航.sh
cd "$(dirname "$0")"

python3 <<'EOF'
import os, re, glob

boards = sorted(d for d in os.listdir('.') if re.match(r'^\d+-', d) and os.path.isdir(d))

def parse_card(path):
    src = open(path).read()
    tags, aliases, abstract = [], [], ''
    m = re.search(r'^tags:\s*\[(.*?)\]', src, re.M)
    if m: tags = [t.strip() for t in m.group(1).split(',') if t.strip()]
    m = re.search(r'^aliases:\s*\[(.*?)\]', src, re.M)
    if m: aliases = [a.strip() for a in m.group(1).split(',') if a.strip()]
    m = re.search(r'> \[!abstract\] 一句话\n> (.+)', src)
    if m: abstract = m.group(1).strip()
    return tags, aliases, abstract

lines = ['# 知识库导航', '',
         '> 由 `./生成导航.sh` 自动生成——请勿手工编辑；新增卡片后重新运行即可。', '']

all_names = {os.path.splitext(os.path.basename(f))[0]
             for b in boards for f in glob.glob(f'{b}/*.md')}
total = 0
for b in boards:
    cards = sorted(glob.glob(f'{b}/*.md'))
    lines += [f'## {b}（{len(cards)}）', '']
    for f in cards:
        name = os.path.splitext(os.path.basename(f))[0]
        tags, aliases, abstract = parse_card(f)
        total += 1
        tag_str = ' '.join(f'#{t}' for t in tags)
        lines.append(f'- [[{name}]] {tag_str}')
        if abstract:
            lines.append(f'  - {abstract}')
        if aliases:
            lines.append(f'  - 别名：{"、".join(aliases)}')
    lines.append('')

# 断链报告
broken = {}
for f in [p for b in boards for p in glob.glob(f'{b}/*.md')]:
    for m in re.findall(r'\[\[([^\]|#\\]+)', open(f).read()):
        if m not in all_names:
            broken.setdefault(m, []).append(os.path.basename(f))
lines += ['---', '', '## 断链报告（指向尚不存在的卡片）', '']
if broken:
    for target in sorted(broken):
        lines.append(f'- [[{target}]]：被 {", ".join(sorted(set(broken[target])))} 引用')
else:
    lines.append('- 无断链 ✅')
lines.append('')
open('导航.md', 'w').write('\n'.join(lines))
print(f'导航.md 已生成：{total} 张卡片，{len(broken)} 个断链目标')
EOF
