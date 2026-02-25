---
name: knowledge-base
description: "管理个人知识库：创建日记、周报、月报、Bug记录、经验总结、工具收集、项目想法与记录、学习笔记。支持按关键词检索知识库内容，汇总生成周报/月报，管理项目想法（ideas）生命周期。当用户提到写日记、记录bug、记笔记、搜索知识库、总结本周/本月、记录想法/idea等场景时触发。"
---

# 个人知识库管理

## 知识库路径

`/Users/chy/Documents/knowledgeBase/`

## 目录结构

| 目录 | 用途 |
|------|------|
| `diary/` | 日记 |
| `weekly/` | 周报 |
| `monthly/` | 月报 |
| `bugs/` | Bug记录 |
| `experience/` | 经验总结 |
| `tools/` | 工具收集 |
| `projects/` | 项目管理（含子目录） |
| `projects/ideas/` | 未启动的项目想法 |
| `projects/doing/` | 进行中的项目 |
| `projects/done/` | 已完成的项目 |
| `projects/TODO.md` | 未启动 ideas 的汇总表 |
| `learning/` | 学习笔记 |

## 命名规则

- 一般文件：`YYYY-MM-DD-中文标题.md`，如 `2025-01-15-代理连接问题.md`
- Ideas 文件：直接用想法的简短描述命名，如 `AI写作助手.md`、`语音输入结构化整理工具.md`

## 核心工作流

### 创建条目

1. 根据用户意图识别内容类型
2. 读取 `references/templates.md` 中对应模板
3. 用实际内容填充模板（保留 YAML frontmatter）
4. 写入到对应目录，文件名遵循命名规则

### 管理项目想法 (ideas)

1. 新想法 → 在 `projects/ideas/` 下创建文件，使用想法简短描述命名
2. 决定启动 → 移到 `projects/doing/`（或在 doing 下新建，保留 ideas 中原始记录）
3. 项目完成 → 移到 `projects/done/`
4. 创建或修改 idea 后，同步更新 `projects/TODO.md` 中的汇总表

Ideas 文件要点：
- `importance` 字段：1-10 分制，表示想法的重要度
- `status` 字段：未启动 / 进行中 / 已完成
- 文件名用想法的简短中文描述，如 `语音输入结构化整理工具.md`

### 检索内容

1. 用 Grep 在 `/Users/chy/Documents/knowledgeBase/` 下搜索关键词
2. 用 Read 读取匹配的文件
3. 向用户总结呈现相关内容

### 生成报告

1. 确定时间范围（本周/本月）
2. 用 Glob 找到时间范围内的条目（按文件名日期前缀匹配）
3. 读取并汇总这些条目
4. 按周报/月报模板生成报告文件

## 模板参考

所有内容类型的模板定义在 `references/templates.md` 中。创建条目前务必先读取对应模板。
