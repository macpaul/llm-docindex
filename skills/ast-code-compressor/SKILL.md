---
name: ast-code-compressor
description: Packages and compresses codebases using Repomix and Tree-sitter AST pruning (--compress). Strips function bodies and implementation details while preserving type definitions, class structures, signatures, and docstrings, reducing codebase tokens by >70%.
---

# AST Code Compressor Skill

## When to Use This Skill
* Use whenever an agent needs a high-level overview of a large repository, module architecture, or API interface without reading every line of implementation code.
* Use before conducting multi-file code reviews, refactoring plans, or system architecture audits.
* Ideal for squeezing a million-token repository into a standard LLM context window.

## Quick Start CLI Commands
```bash
# Compress entire current directory using Tree-sitter AST pruning
repomix --compress

# Compress specific target directory with Markdown output format
repomix src/ --compress --style markdown --output repomix-outline.md

# Include only specific languages and ignore tests/assets
repomix --include "src/**/*.ts,src/**/*.py" --ignore "**/*test*,**/node_modules/**" --compress

# Custom instruction injection
repomix --compress --instruction "Analyze this interface outline for architectural decoupling."
```

## How It Works
* Repomix integrates `tree-sitter` grammars to parse source files into Abstract Syntax Trees.
* The `--compress` flag prunes statement blocks inside functions and methods, leaving only:
  - Class definitions and inheritance hierarchies.
  - Function signatures with parameter and return type annotations.
  - Exported interfaces, structs, and enums.
  - Module-level docstrings and comments.
* Token count is reduced by 70% to 85% with zero loss of semantic API topology.
