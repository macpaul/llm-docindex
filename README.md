# LLM Document Token Optimization & Retrieval Suite

Comprehensive toolchain, deployment scripts, helper utilities, and AI coding CLI skills for minimizing LLM context window token waste across multi-format documents (PDF, DOCX, PPTX, XLSX, HTML), web pages, and codebases.

Based on the architectural study and engineering practices detailed in [LLM-Document-Token-Optimization.md](file:///home/macpaul/doc-codeindex/LLM-Document-Token-Optimization.md) and [DOCUMENT_TOKEN_OPTIMIZATION_DEPLOYMENT.md](file:///home/macpaul/doc-codeindex/DOCUMENT_TOKEN_OPTIMIZATION_DEPLOYMENT.md).

---

## 1. Key Capabilities & Token Economies

| Domain | Raw Approach | Optimized Approach | Toolchain | Token Savings |
| :--- | :--- | :--- | :--- | :--- |
| **PDF & Presentations** | Multi-modal rasterization (40k–70k tokens) | Markdown flattening (10k–15k tokens) | MarkItDown, PyMuPDF4LLM, Docling | **>80%** |
| **Office Editing** | Rewriting entire DOCX (thousands of tokens) | Incremental XPath XML patching (<50 tokens) | python-docx, lxml (`patch-docx-xml`) | **>95%** |
| **Web & DOM** | Raw HTML / DOM (5k–20k tokens) | Boilerplate-stripped Markdown (<1k tokens) | Trafilatura, Readdown (`purify-web`) | **>85%** |
| **Codebases** | Reading full source trees (hundreds of k tokens)| Tree-sitter AST pruning & Symbol indexing | Repomix (`--compress`), TokToken | **70%–99%** |

---

## 2. Repository Layout

```
.
├── LLM-Document-Token-Optimization.md     # Initial architectural research document
├── DOCUMENT_TOKEN_OPTIMIZATION_DEPLOYMENT.md # Complete deployment guide & package inventory
├── README.md                              # Repository overview and quick start guide
├── LICENSE                                # GNU Affero General Public License v3.0 (AGPL-3.0)
├── mcp_config.json                        # FastMCP server registration configuration
│
├── deploy-doc-tools.sh                    # System-wide (root/sudo) multi-user deployment script
├── install-doc-tools-user.sh              # User-level (non-root) deployment script
├── verify-doc-tools.sh                    # Verification and smoke-testing test suite
├── install-skills.sh                      # Symlinks skills to workspace and global scopes
│
├── scripts/                               # Helper CLI scripts & MCP Server
│   ├── convert_doc.py                     # Multi-engine document converter (MarkItDown/PyMuPDF/Docling)
│   ├── patch_docx_xml.py                  # XPath incremental XML patcher for .docx files
│   ├── purify_web.py                      # Universal web content & DOM boilerplate stripper
│   └── doc_mcp_server.py                  # FastMCP server for Claude Desktop & Antigravity
│
├── skills/                                # Modular AI Coding CLI Skills (SKILL.md)
│   ├── doc-token-optimizer/               # Office document to Markdown converter
│   ├── docx-xml-patcher/                  # Incremental XML patcher for Word documents
│   ├── web-content-purifier/              # Web & HTML boilerplate stripper
│   ├── ast-code-compressor/               # Repomix Tree-sitter AST code compressor
│   ├── toktoken-symbol-search/            # TokToken SQLite FTS5 symbol lookup
│   ├── repo-map-navigator/                # Aider PageRank repository topology mapper
│   ├── scip-semantic-indexer/             # SCIP cross-language code intelligence indexer
│   └── fastmcp-document-server/           # Model Context Protocol server integration
│
└── .agents/skills/                        # Workspace-scoped symlinks for AI agents
```

---

## 3. Quick Start & Deployment

### 3.1 System-Wide Installation (Root / Sudo)
Installs tools globally into `/usr/local/bin`, sets up a managed Python 3.12 environment in `/opt/doc-token-tools`, installs global NPM packages, compiles Go/Rust indexers, and configures `/etc/profile.d`:

```bash
sudo ./deploy-doc-tools.sh
```

### 3.2 Non-Root User Installation
For developers without sudo privileges, installs tools into `~/.local/bin` and provisions a local virtualenv in `~/.local/share/doc-token-tools-venv`:

```bash
./install-doc-tools-user.sh
```

### 3.3 Verification
Run the automated test suite to validate binaries, Python modules, Node packages, and live conversion smoke tests:

```bash
./verify-doc-tools.sh
```

### 3.4 Skill Registration
Link all 8 AI coding skills into your current workspace (`.agents/skills/`) and global user configuration (`~/.agents/skills/` and `~/.gemini/config/skills/`):

```bash
./install-skills.sh
```

---

## 4. Helper CLI Utilities

Once deployed, the following command-line tools are available directly in your PATH:

### `convert-doc`
Unified multi-format office document converter:
```bash
convert-doc report.pdf -o report.md --stats
convert-doc presentation.pptx -o slides.md
convert-doc sheet.xlsx -o table.md --engine markitdown
```

### `patch-docx-xml`
Surgical OpenXML node patcher for Word documents:
```bash
patch-docx-xml contract.docx --find "2025" --replace "2026" --dry-run
patch-docx-xml agreement.docx --xpath "//w:t[contains(text(), 'Company Inc.')]" --new-text "Enterprise Corp"
```

### `purify-web`
Boilerplate stripper extracting semantic Markdown from web pages:
```bash
purify-web -u "https://news.ycombinator.com" --stats
purify-web -i messy_scraped_page.html -o clean_article.md
```

### `doc-mcp-server`
Launches the FastMCP server for AI agents:
```bash
python3 scripts/doc_mcp_server.py
```

---

## 5. AI Coding Skills Catalog

1. **[`doc-token-optimizer`](file:///home/macpaul/doc-codeindex/skills/doc-token-optimizer/SKILL.md)**: Converts PDF, DOCX, PPTX, and XLSX files to Markdown using MarkItDown, PyMuPDF4LLM, or Docling.
2. **[`docx-xml-patcher`](file:///home/macpaul/doc-codeindex/skills/docx-xml-patcher/SKILL.md)**: Micro-patches DOCX XML nodes using XPath without full document regeneration.
3. **[`web-content-purifier`](file:///home/macpaul/doc-codeindex/skills/web-content-purifier/SKILL.md)**: Strips navigation, ads, and scripts from web pages using Trafilatura and Readdown.
4. **[`ast-code-compressor`](file:///home/macpaul/doc-codeindex/skills/ast-code-compressor/SKILL.md)**: Prunes function bodies while preserving signatures using Repomix `--compress`.
5. **[`toktoken-symbol-search`](file:///home/macpaul/doc-codeindex/skills/toktoken-symbol-search/SKILL.md)**: Locates surgical function/class definitions via TokToken SQLite FTS5.
6. **[`repo-map-navigator`](file:///home/macpaul/doc-codeindex/skills/repo-map-navigator/SKILL.md)**: Maps codebase architecture using Aider PageRank graph centrality.
7. **[`scip-semantic-indexer`](file:///home/macpaul/doc-codeindex/skills/scip-semantic-indexer/SKILL.md)**: Performs compiler-accurate symbol resolution with SCIP and scip-search.
8. **[`fastmcp-document-server`](file:///home/macpaul/doc-codeindex/skills/fastmcp-document-server/SKILL.md)**: Provides stdio MCP tools for agentic coding environments.

---

## 6. License

This repository is distributed under the terms of the **GNU Affero General Public License v3.0 (AGPL-3.0)**. See [LICENSE](file:///home/macpaul/doc-codeindex/LICENSE) for complete details.
