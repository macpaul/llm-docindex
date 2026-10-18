---
name: toktoken-symbol-search
description: Precision symbol-level code indexing and dependency search using TokToken and universal-ctags with SQLite FTS5. Retrieves only the exact target function or class definition, saving 88% to 99% of tokens during repository exploration.
---

# TokToken Symbol Search Skill

## When to Use This Skill
* Use when an agent needs to locate and inspect a specific function, method, struct, or class definition in a large project.
* **NEVER** use broad full-text searches (like `grep` or reading entire source files) when hunting for a single symbol definition. Reading full 1,000-line files to find a 20-line function consumes thousands of unnecessary context tokens.
* Use when tracing function call dependencies across modules.

## Quick Start CLI Commands
```bash
# 1. Index the workspace (creates SQLite FTS5 index)
toktoken index

# 2. Search for a specific symbol definition
toktoken search "calculate_metrics"

# 3. Retrieve symbol definition along with dependent definitions
toktoken search "TokenOptimizer" --context

# 4. Dump symbol table overview
toktoken dump --limit 50
```

## How It Works
* TokToken is a standalone C binary integrating `universal-ctags` for AST tag generation and SQLite FTS5 for full-text symbol ranking.
* Instead of loading hundreds of lines of file padding, TokToken extracts byte offsets to return exclusively the symbol body and its signature.
* Achieves **88% to 99% token reduction** per exploratory lookup compared to file-level context injection.
