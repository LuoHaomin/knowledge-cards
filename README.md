# knowledge-cards — 卡片式知识库

用「原子卡片 + 双链 + Obsidian canvas」管理学习型知识库的完整方法论。典型场景：数学、物理等理论课程，或读论文时遇到新概念——学习并记录成卡片，下次遗忘时快速查阅，避免对同一个概念反复学习。

## 安装

通过 [`npx skills`](https://skills.sh) 一键安装（registry 就是 GitHub 本身）：

```bash
# 装到当前项目（.claude/skills/）
npx skills add LuoHaomin/knowledge-cards

# 装到全局，并指定 Claude Code
npx skills add LuoHaomin/knowledge-cards -g -a claude-code
```

兼容 Claude Code / Cursor / Codex / Copilot 等 70+ agent。

## 这是什么

- **原子卡**：一张卡一个概念/定理。概念卡的灵魂是**定义拆解 + 反例**（每个定义条件各挡住什么病态）；定理卡的灵魂是**证明骨架 + 客户名单**（领域内谁依赖它）。
- **双链是承重墙**：wiki 链接零维护成本、自索引；文件夹（知识板块）只做轻量分区；canvas 做空间导航。
- **索引不手写**：`生成导航.sh` 自动产出分板块卡片清单 + 断链报告（断链 = 待办）；`布局画布.sh` 对 canvas 做力导向/分层自动布局。
- **知识卡只装知识**：库的定位是「读懂论文/教材所需知识点的查考库」，"我的研究用它做什么"不进卡。
- **写作规则成文**：复合内容拆分判据（会单独问 → 独立成卡；概念成立依据 → 寄生；技术引理 → 占坑）、来源规则（公认知识不标来源，论文特有内容标出处）。

触发词：建知识库 / 知识卡片 / 卡片笔记 / 整理知识点 / 把论文整理成卡片 / 读懂这篇论文需要哪些知识点……

## 仓库结构

```
knowledge-cards/
├── SKILL.md                  # 核心理念、结构约定、四个工作流
├── references/
│   ├── card-templates.md     # 概念卡/定理卡模板、写作细则、拆分判据
│   └── canvas-conventions.md # canvas JSON 格式、颜色约定、布局脚本参数
├── scripts/
│   ├── init_kb.sh            # 初始化新库结构
│   ├── 生成导航.sh            # 卡片清单 + 断链报告
│   └── 布局画布.sh            # canvas 自动布局（力导向 / --分层）
├── README.md
└── LICENSE
```

## 快速上手

对 Agent 说"在 `<目录>` 建一个知识库，板块为……"，或直接"把这篇论文的知识点整理进 `<库>`"。
