---
name: repo-map-navigator
description: Generates topological codebase maps and navigates repository symbol structures using Aider Repo Map with Tree-sitter and PageRank graph centrality. Injects only the most critical file outlines and symbols into LLM context.
---

# Repo Map Navigator Skill

## When to Use This Skill
* Use when an agent enters a new or unfamiliar repository and needs to orient itself quickly.
* Use to understand which files define core data models, interfaces, and entry points without scanning every directory manually.
* Use when preparing context for multi-file architectural refactoring.

## Quick Start CLI Commands
```bash
# Print high-density repository map directly to terminal
aider --show-repo-map

# Generate repo map with specific token budget
aider --show-repo-map --map-tokens 1024 > repo_map_1k.txt

# Inspect repository map focused on specific files
aider --show-repo-map file1.py file2.py
```

## How It Works
1. **Symbol Extraction**: Aider uses Tree-sitter and ctags to extract class, function, and variable identifiers across all files.
2. **Graph Construction**: Constructs an adjacency matrix linking callers to callees and files to symbols.
3. **PageRank Centrality**: Ranks every symbol using PageRank to identify the most heavily referenced, foundational architectural entities.
4. **Context Injection**: Packs the highest-ranking signatures into a dense, compact ASCII map tailored to the agent's token budget.
