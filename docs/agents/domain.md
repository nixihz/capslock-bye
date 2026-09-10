# Domain Docs

本仓库采用 **single-context** 布局。`CapsCore` 与 `CapsBye` 属于同一个应用，使用共享领域词汇和架构决策记录。

## 探索代码前

- 阅读根目录 `CONTEXT.md`。
- 阅读 `docs/adr/` 中与当前工作相关的架构决策记录。
- 如果未来存在根目录 `CONTEXT-MAP.md`，先按其中的指引读取相关上下文的 `CONTEXT.md` 与 ADR。

这些文件不存在时，静默继续；不要把缺失视为错误，也不要主动建议补建。由 `domain-modeling` 在术语或决策实际明确后按需创建。

## 文件布局

```text
/
├── CONTEXT.md          # 按需创建的领域词汇与上下文
├── docs/
│   └── adr/            # 按需创建的架构决策记录
└── Sources/
    ├── CapsCore/
    └── CapsBye/
```

## 使用统一词汇

Issue 标题、重构建议、假设与测试名称涉及领域概念时，使用 `CONTEXT.md` 定义的术语，避免采用词汇表明确排除的同义词。

需要的概念尚未收录时，先检查是否引入了项目不用的说法；如果确有缺口，留给 `domain-modeling` 处理。

## 明示 ADR 冲突

输出与已有 ADR 冲突时，明确指出具体 ADR、冲突点以及重新讨论的原因，不要静默覆盖既有决策。
