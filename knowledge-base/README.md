# Knowledge Base Skill for Claude Code

一个 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 自定义 Skill，用于管理个人知识库。

## 支持的内容类型

| 类型 | 目录 | 说明 |
|------|------|------|
| 日记 | `diary/` | 每日记录 |
| 周报 | `weekly/` | 每周工作总结 |
| 月报 | `monthly/` | 每月工作总结 |
| Bug 记录 | `bugs/` | 问题排查与解决方案 |
| 经验总结 | `experience/` | 踩坑经验与最佳实践 |
| 工具收集 | `tools/` | 好用工具的记录 |
| 项目记录 | `projects/` | 项目进展与架构决策 |
| 学习笔记 | `learning/` | 学习内容整理 |

## 安装方法

> **个人级 vs 项目级：** Claude Code 支持两种 skill 注册方式：
> - **个人级**（推荐）：安装到 `~/.claude/skills/`，在所有项目中都可使用
> - **项目级**：安装到项目的 `.claude/skills/`，仅在该项目中生效
>
> 以下方法默认安装为个人级 skill。如需项目级安装，将目标路径中的 `~/.claude/skills/` 替换为 `<你的项目>/.claude/skills/` 即可。

### 方法一：一键安装（推荐）

将以下提示词复制粘贴到 Claude Code 中执行：

```
请帮我安装 knowledge-base skill：
1. 运行 git clone https://github.com/CarolineCheng233/knowledge-base.git /tmp/knowledge-base-skill
2. 运行 mkdir -p ~/.claude/skills/knowledge-base/references
3. 将 /tmp/knowledge-base-skill/SKILL.md 复制到 ~/.claude/skills/knowledge-base/SKILL.md
4. 将 /tmp/knowledge-base-skill/references/templates.md 复制到 ~/.claude/skills/knowledge-base/references/templates.md
5. 读取 SKILL.md 确认安装成功
6. 清理临时文件 rm -rf /tmp/knowledge-base-skill
```

### 方法二：手动安装

1. 克隆仓库：

```bash
git clone https://github.com/CarolineCheng233/knowledge-base.git
```

2. 将 skill 文件复制到 Claude Code skills 目录：

```bash
mkdir -p ~/.claude/skills/knowledge-base/references
cp knowledge-base/SKILL.md ~/.claude/skills/knowledge-base/
cp knowledge-base/references/templates.md ~/.claude/skills/knowledge-base/references/
```

3. 重启 Claude Code 即可生效。

### 方法三：下载 .skill 文件安装

从 [GitHub Releases](https://github.com/CarolineCheng233/knowledge-base/releases) 下载 `knowledge-base.skill` 文件，然后解压到个人 skills 目录：

```bash
unzip knowledge-base.skill -d ~/.claude/skills/
```

解压后的目录结构：

```
~/.claude/skills/knowledge-base/
├── SKILL.md
└── references/
    └── templates.md
```

重启 Claude Code 即可生效。

## 使用示例

安装完成后，在 Claude Code 中使用以下语句即可触发：

```
帮我写一篇今天的日记
记录一个 bug：xxx 报错了
总结一下本周的工作，生成周报
搜索知识库中关于 Docker 的内容
记录一个工具：xxx
写一篇学习笔记：xxx
```

## 验证安装

安装完成后，重启 Claude Code，输入 `/knowledge-base` 即可调用。如果提示 "unknown skill"，请检查：

1. 文件是否位于 `~/.claude/skills/knowledge-base/SKILL.md`（个人级）或 `.claude/skills/knowledge-base/SKILL.md`（项目级）
2. 目录结构是否正确（`SKILL.md` 必须在 `knowledge-base/` 子目录下，不能直接放在 `skills/` 下）
3. 是否已重启 Claude Code 会话

## 目录结构

```
knowledge-base/
├── SKILL.md                    # Skill 主文件（定义工作流和目录结构）
├── references/
│   └── templates.md            # 8 种内容类型的 Markdown 模板
├── .gitignore
└── README.md
```

## 配置

安装后，你可能需要修改 `SKILL.md` 中的知识库路径，将其指向你自己的知识库目录：

```markdown
## 知识库路径

`/Users/你的用户名/Documents/knowledgeBase/`
```

## License

MIT
