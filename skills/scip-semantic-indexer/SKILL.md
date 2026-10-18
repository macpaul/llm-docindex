---
name: scip-semantic-indexer
description: Cross-language SCIP (SCIP Code Intelligence Protocol) code graph indexer and search tool. Performs compiler-accurate symbol resolution, jump-to-definition, and reference lookups across TypeScript, Python, Go, and C/C++ projects.
---

# SCIP Semantic Indexer Skill

## When to Use This Skill
* Use when an agent needs exact, compiler-verified symbol definitions, cross-module references, or interface implementations.
* Essential for large polyglot codebases where regex or textual search generates severe false-positive noise.
* Use before conducting broad symbol renames or validating interface adherence.

## Quick Start CLI Commands
```bash
# 1. Generate SCIP index for TypeScript/JavaScript
scip-typescript index --yarn-workspaces

# 2. Generate SCIP index for Python
scip-python index .

# 3. Generate SCIP index for Go
scip-go

# 4. Generate SCIP index for C/C++
scip-clang --compile-commands=compile_commands.json

# 5. Inspect and validate index.scip protobuf
scip print index.scip

# 6. Query symbols and references using scip-search
scip-search -index index.scip -symbol "calculate_metrics"
```

## Protocol Architecture
* SCIP uses standard Protocol Buffers (`index.scip`) to represent code graphs with:
  - Precise symbol descriptor strings (`<package> <version> <namespace>/<symbol>#`).
  - Definition locations with exact line/column boundaries.
  - Cross-file reference sets.
  - Type relationships and interface implementations.
* Bypasses the need to run heavy, long-running language servers in memory when performing static symbol audits.
