# 知识库内容模板

以下是所有内容类型的 Markdown 模板。创建新条目时，读取对应模板并填充内容。

文件命名规则：`YYYY-MM-DD-中文标题.md`

---

## 日记 (diary/)

```markdown
---
type: diary
date: {{YYYY-MM-DD}}
tags: [日记]
---

# {{YYYY-MM-DD}} 日记

## 今日亮点
-

## 遇到的问题
-

## 感悟
<!-- 可选，有想法时记录 -->

```

---

## 周报 (weekly/)

```markdown
---
type: weekly
week: {{YYYY}}-W{{周号}}
date_range: {{周一日期}} ~ {{周日日期}}
tags: [周报]
---

# {{YYYY}} 第{{周号}}周 周报

## 本周完成
-

## 遇到的挑战
-

## 下周计划
-

```

---

## 月报 (monthly/)

```markdown
---
type: monthly
month: {{YYYY-MM}}
tags: [月报]
---

# {{YYYY年MM月}} 月报

## 月份总结


## 关键成果
-

## 经验教训
-

## 下月目标
-

```

---

## Bug记录 (bugs/)

```markdown
---
type: bug
date: {{YYYY-MM-DD}}
status: resolved
tags: [bug]
---

# {{Bug标题}}

## 环境
- 系统：
- 工具/版本：

## 复现步骤
1.

## 错误信息
```
粘贴错误日志
```

## 根因分析


## 解决方案


## 预防措施
-

```

---

## 经验总结 (experience/)

```markdown
---
type: experience
date: {{YYYY-MM-DD}}
tags: [经验]
---

# {{主题}}

## 背景


## 具体经验


## 关键收获
-

```

---

## 工具收集 (tools/)

```markdown
---
type: tool
date: {{YYYY-MM-DD}}
category: {{分类}}
tags: [工具]
---

# {{工具名}}

## 用途


## 优点
-

## 缺点
-

## 链接
- 官网：
- 文档：

```

---

## 项目想法 (projects/ideas/)

文件名：想法的简短描述，如 `AI写作助手.md`

```markdown
---
type: idea
date: {{YYYY-MM-DD}}
importance: {{1-10}}
status: 未启动
---

# {{想法标题}}

## 想法内容


## 方案调研

暂无
```

---

## 项目记录 (projects/doing/ 和 projects/done/)

```markdown
---
type: project
date: {{YYYY-MM-DD}}
status: doing
idea: ideas/{{对应想法文件名}}.md
tags: [项目]
---

# {{项目名}}

## 概述


## 架构决策
-

## 进展日志

### {{YYYY-MM-DD}}
-

```

---

## 学习笔记 (learning/)

```markdown
---
type: learning
date: {{YYYY-MM-DD}}
source: {{来源}}
tags: [学习]
---

# {{主题}}

## 核心概念
-

## 笔记


## 实践
-

```
