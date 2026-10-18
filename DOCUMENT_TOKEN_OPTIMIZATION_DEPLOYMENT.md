# LLM Document Token Optimization & Retrieval Tools: System Deployment Guide & Package Inventory

## 1. Executive Summary & Architecture Overview

Modern Large Language Models (LLMs) feature expanded context windows reaching hundreds of thousands to millions of tokens. However, directly ingesting raw document formats (such as PDF, DOCX, PPTX, XLSX, HTML, XML, and raw repository source trees) incurs catastrophic token waste, elevated inference latency, and degraded retrieval accuracy.

Empirical evaluations show:
* **PDFs & Presentations**: Direct multi-modal rasterization of a 20-page visual PDF consumes 40,000 to 70,000 tokens. Flattening into high-density Markdown reduces this to 10,000–15,000 tokens (**>80% token savings**).
* **Web Pages & HTML**: Raw DOM trees contain excessive boilerplate (navigation, scripts, tracking pixels, ads). Stripping boilerplate down to semantic Markdown condenses 5,000–20,000 tokens to under 1,000 tokens (**>85% token savings**).
* **Office Document Edits**: Rewriting an entire DOCX/PPTX to change a few fields consumes thousands of output tokens and corrupts styles/layouts. Targeted **XML node patching via XPath** achieves micro-edits within **<50 output tokens** (**>95% token savings**).
* **Code Repositories**: Packing entire source trees floods context windows with implementation noise. Employing **Tree-sitter AST compression (`--compress`)**, **TokToken symbol-level retrieval**, and **SCIP semantic code graphs** reduces code token consumption by **70% to 99%**.

This deployment guide surveys every tool analyzed in `LLM-Document-Token-Optimization.md`, catalogs all required Ubuntu system packages and GitHub components, outlines deployment architectures for both root (multi-user system-wide) and non-root users, details verification procedures, and specifies their conversion into modular AI coding CLI skills.

```
+--------------------------------------------------------------------------------------------------+
|                                    AI Agent / Coding CLI Layer                                    |
|   (Google Antigravity CLI / IDE / Claude Code Skills / FastMCP Model Context Protocol Servers)   |
+--------------------------------------------------------------------------------------------------+
                                                 |
         +---------------------------------------+---------------------------------------+
         |                                       |                                       |
         v                                       v                                       v
+-----------------------+               +-----------------------+               +-----------------------+
|  Office & Docs Layer  |               |    Web & DOM Layer    |               |  Code & AST Semantics |
+-----------------------+               +-----------------------+               +-----------------------+
| - MarkItDown (MS)     |               | - Trafilatura (Python)|               | - Repomix (--compress)|
| - Docling (IBM)       |               | - Readdown (JS/Node)  |               | - TokToken (C/FTS5)   |
| - PyMuPDF4LLM         |               | - Readability+Turndown|               | - Aider (Repo Map)    |
| - python-docx + lxml  |               | - jsdom / linkedom    |               | - SCIP & scip-search  |
|   (Incremental XPath) |               |                       |               | - Serena MCP & Pyright|
+-----------------------+               +-----------------------+               +-----------------------+
         |                                       |                                       |
         +---------------------------------------+---------------------------------------+
                                                 |
                                                 v
+--------------------------------------------------------------------------------------------------+
|                                 Operating System & Runtime Host                                  |
|     Ubuntu 22.04 / 24.04 / 26.04 LTS (x86_64 & aarch64) | Managed Python 3.12 Runtime via UV     |
|           System Deploy: /usr/local/bin | /opt/doc-token-tools | /etc/profile.d/                  |
+--------------------------------------------------------------------------------------------------+
```

---

## 2. Complete Tool Survey & Functional Taxonomy

### 2.1 Office Documents & Presentations Ingestion (Reading)
* **MarkItDown** (Microsoft):
  * **Role**: General-purpose, ultra-fast multi-format text extractor. Converts PDF, DOCX, PPTX, XLSX, HTML, images, and audio into LLM-ready GitHub Flavored Markdown (GFM).
  * **Ecosystem**: Python library and CLI (`markitdown`).
  * **Strengths**: Sub-second execution, zero heavy ML runtime overhead, flattens Excel sheets into readable GFM tables, supports Azure Document Intelligence / Vision plugins.
  * **Weaknesses**: Linear text stream extraction for PDFs (via `pdfminer.six`); struggles with multi-column reading order and complex table boundaries in scanned PDFs.
* **Docling** (IBM):
  * **Role**: Deep document understanding and layout analysis engine.
  * **Ecosystem**: Python library and CLI (`docling`, `docling-core`, PyTorch / ONNX models).
  * **Strengths**: Reconstructs reading order in multi-column research papers and financial statements; identifies complex table cells, formulas, and OCR text with high structural fidelity.
  * **Weaknesses**: Higher latency (seconds per page), requires initial model weight downloads (~500MB).
* **PyMuPDF4LLM** (Artifex):
  * **Role**: Millisecond-level local PDF-to-Markdown converter.
  * **Ecosystem**: Python library (`pymupdf4llm`).
  * **Strengths**: Blazing fast, pure digital PDF extraction, generates bounding box metadata without deep learning dependencies.
  * **Weaknesses**: Dedicated solely to digital PDFs (does not handle DOCX/PPTX or complex OCR without tesseract).

### 2.2 Office Documents Incremental Modification (Writing / Patching)
* **python-docx & lxml**:
  * **Role**: Non-destructive, incremental XML node patching for `.docx` files.
  * **Mechanism**: `.docx` files are ZIP packages containing `word/document.xml`. Rather than rewriting the document, an agent passes an XPath query and replacement text (e.g., `//w:t[contains(., '2025')]` -> `2026`).
  * **Strengths**: Slashes LLM output tokens from thousands to <50 tokens; strictly preserves corporate styles, headers, footers, and XML schemas.

### 2.3 Web Pages, DOM & Wiki Purifiers
* **Trafilatura**:
  * **Role**: State-of-the-art web scraping and boilerplate removal CLI/library.
  * **Ecosystem**: Python / lxml (`trafilatura`).
  * **Strengths**: Combines heuristic XPath rules with Readability fallback; outstanding multi-lingual support; F1 benchmark score of 0.859–0.91; strips banners, menus, footers, and trackers.
* **Mozilla Readability + Turndown**:
  * **Role**: DOM text-density scoring paired with HTML-to-GFM translation.
  * **Ecosystem**: Node.js (`@mozilla/readability`, `turndown`, `turndown-plugin-gfm`, `jsdom`, `linkedom`).
  * **Strengths**: High fidelity on single long-form articles; widely battle-tested in browser reader modes.
* **Readdown**:
  * **Role**: Zero-dependency, ultra-lightweight (5KB) HTML-to-Markdown cleaner designed specifically for AI contexts.
  * **Ecosystem**: Node.js / CLI (`readdown`).
  * **Strengths**: 40% faster than Readability+Turndown, perfectly preserves header hierarchies and unpacks nested tables without bloat.

### 2.4 Code & Structured Document Semantic / AST Compression
* **Repomix** (formerly Repopack):
  * **Role**: Codebase packaging tool with Tree-sitter AST compression (`repomix --compress`).
  * **Ecosystem**: Node.js / Rust CLI (`repomix`, `repomix-rs`).
  * **Strengths**: Prunes function/method bodies while retaining signatures, class outlines, and docstrings, reducing codebase tokens by >70%.
* **TokToken**:
  * **Role**: High-speed, single-binary C symbol indexer powered by `universal-ctags` and SQLite FTS5.
  * **Ecosystem**: C binary (`toktoken`).
  * **Strengths**: Enables targeted symbol retrieval (definitions, references) without ingesting full files, saving 88%–99% of tokens during repository navigation.
* **Aider Repo Map**:
  * **Role**: Topological code repository mapper using Tree-sitter and PageRank graph algorithms.
  * **Ecosystem**: Python (`aider-chat`).
  * **Strengths**: Computes symbol centrality and packs the top most relevant definitions into context.
* **SCIP (SCIP Code Intelligence Protocol) & scip-search**:
  * **Role**: Compiler-accurate cross-language semantic code graph protocol.
  * **Ecosystem**: `scip` CLI, `scip-search`, `scip-typescript`, `scip-python`, `scip-go`, `scip-clang`.
  * **Strengths**: Precise jump-to-definition and cross-file references across multi-language projects.
* **Serena MCP & Language Servers (LSP)**:
  * **Role**: LSP bridge for AI coding agents (`pyright`, `rust-analyzer`, `vtsls`, `gopls`).
  * **Strengths**: Flow-sensitive type inference and semantic symbol renaming.

### 2.5 Model Context Protocol (MCP) & Skills Packaging
* **FastMCP**:
  * **Role**: FastAPI-inspired Python framework for building and deploying MCP servers.
  * **Strengths**: Decorator-based tool definitions (`@mcp.tool`), automatic JSON schema generation, stdio transport for local CLI tools, SSE transport for remote servers.
* **Claude Code & Google Antigravity Skills (SKILL.md)**:
  * **Role**: Standardized agent capability encapsulation with progressive disclosure.
  * **Scopes**: Workspace scope (`.agents/skills/`), Global scope (`~/.agents/skills/` and `~/.gemini/config/skills/`).

---

## 3. Comprehensive Package Inventory

### 3.1 Ubuntu System Packages (APT)

| Package Name | Purpose / Dependent Tools | Source |
| :--- | :--- | :--- |
| `build-essential` | GCC, G++, Make for native extensions | Ubuntu Archive |
| `pkg-config` | Library path configuration for C/C++ builds | Ubuntu Archive |
| `libxml2-dev`, `libxslt1-dev`, `zlib1g-dev` | C headers for `lxml` and `trafilatura` | Ubuntu Archive |
| `libsqlite3-dev`, `sqlite3` | SQLite FTS5 engine for `toktoken` | Ubuntu Archive |
| `universal-ctags` | Symbol parsing for `toktoken` and `aider` | Ubuntu Archive |
| `poppler-utils` | PDF utilities (`pdftotext`, `pdfinfo`) for MarkItDown | Ubuntu Archive |
| `tesseract-ocr` | Optical character recognition engine for scanned docs | Ubuntu Archive |
| `tesseract-ocr-eng`, `tesseract-ocr-chi-tra`, `tesseract-ocr-chi-sim` | Multi-language OCR data packs | Ubuntu Archive |
| `pandoc` | General markup format conversion fallback | Ubuntu Archive |
| `libgl1`, `libglib2.0-0` | OpenGL and GLib runtimes for OpenCV / Docling | Ubuntu Archive |
| `curl`, `wget`, `git`, `jq`, `unzip`, `tar`, `gzip` | Core download and archive extraction utilities | Ubuntu Archive |
| `nodejs`, `npm` | JavaScript runtime and package manager | Ubuntu Archive / NodeSource |
| `golang-go` | Go compiler for `scip-go` and `scip-search` | Ubuntu Archive |
| `cargo`, `rustc` | Rust toolchain for `rust-analyzer-mcp` | Ubuntu Archive |
| `gfortran`, `libopenblas-dev`, `liblapack-dev` | Fortran / BLAS headers for scientific Python builds | Ubuntu Archive |

### 3.2 Python Packages (PyPI via UV)

Managed in dedicated virtual environment `/opt/doc-token-tools` (Python 3.12):

| Python Package | Version Target | Primary CLI / Module | Functional Role |
| :--- | :--- | :--- | :--- |
| `markitdown` | `>=0.1.8` | `markitdown` | Universal office document to Markdown |
| `docling` | `>=2.140.0` | `docling` | Deep layout analysis & table reconstruction |
| `docling-core` | `>=2.102.0` | `docling.datamodel` | Data models and format serializers |
| `pymupdf4llm` | `>=1.28.2` | `pymupdf4llm` | Millisecond-level local PDF Markdown extractor |
| `trafilatura` | `>=2.3.1` | `trafilatura` | Web page boilerplate and noise stripping |
| `python-docx` | `>=1.2.0` | `docx` | Word document structure parsing |
| `lxml` | `>=6.1.3` | `lxml.etree` | High-speed XPath node querying and patching |
| `openpyxl` | `>=3.1.5` | `openpyxl` | Excel spreadsheet parsing for MarkItDown |
| `python-pptx` | `>=1.0.2` | `pptx` | PowerPoint presentation parsing |
| `fastmcp` | `>=4.1.1` | `fastmcp` | Fast MCP tool server builder |
| `mcp` | `>=2.3.0` | `mcp` | Model Context Protocol official SDK |
| `aider-chat` | `>=0.86.0` | `aider` | PageRank-based repository map builder |
| `beautifulsoup4` | `>=4.14.0` | `bs4` | HTML parsing and preprocessing |
| `pydantic` | `>=2.12.0` | `pydantic` | Schema validation for tool calls |

### 3.3 Node.js Packages (Global NPM)

| NPM Package | Version Target | Executable / Link | Functional Role |
| :--- | :--- | :--- | :--- |
| `repomix` | `>=1.18.0` | `repomix` | Codebase packer with Tree-sitter AST pruning |
| `repomix-rs` | `>=2.0.0` | `repomix-rs` | High-performance Rust backend for Repomix |
| `readdown` | `>=0.2.5` | `readdown` | Lightweight 5KB DOM-to-Markdown purifier |
| `@mozilla/readability` | `>=0.6.0` | Node library | DOM text density scoring algorithm |
| `turndown` | `>=7.2.4` | Node library | HTML-to-GFM converter |
| `turndown-plugin-gfm` | `>=1.0.2` | Node library | GitHub Flavored Markdown extensions (tables, tasks) |
| `jsdom` | `>=30.1.0` | Node library | Full W3C DOM implementation for Node.js |
| `linkedom` | `>=0.18.0` | Node library | High-speed, lightweight DOM alternative |
| `tree-sitter-cli` | `>=0.27.0` | `tree-sitter` | Tree-sitter grammar parser and CLI |
| `pyright` | `>=1.1.414` | `pyright`, `pyright-langserver` | Microsoft Python type checker and LSP |
| `typescript` | `>=7.0.0` | `tsc` | TypeScript compiler |
| `typescript-language-server`| `>=6.0.0` | `typescript-language-server` | TypeScript & JavaScript LSP |
| `@vtsls/language-server` | `>=0.3.0` | `vtsls` | Fast TypeScript LSP wrapper |
| `@sourcegraph/scip-typescript` | `>=0.4.0` | `scip-typescript` | SCIP TypeScript / JavaScript indexer |
| `@sourcegraph/scip-python` | `>=0.6.0` | `scip-python` | SCIP Python indexer |

### 3.4 Standalone Binaries (GitHub Releases & Source Builds)

| Binary Name | Source Repository | Build / Install Method | Installed Destination |
| :--- | :--- | :--- | :--- |
| `uv`, `uvx` | `astral-sh/uv` | Official release tarball | `/usr/local/bin/uv` |
| `toktoken` | `mauriziofonte/toktoken` | Official release binary | `/usr/local/bin/toktoken` |
| `rust-analyzer` | `rust-lang/rust-analyzer` | Official release binary | `/usr/local/bin/rust-analyzer` |
| `scip` | `scip-code/scip` | Official release tarball | `/usr/local/bin/scip` |
| `scip-clang` | `sourcegraph/scip-clang` | Official release binary | `/usr/local/bin/scip-clang` |
| `scip-search` | `liza-mas/scip-search` | Git clone + `go build` | `/usr/local/bin/scip-search` |
| `scip-go` | `scip-code/scip-go` | `go install` | `/usr/local/bin/scip-go` |
| `gopls` | `golang.org/x/tools/gopls`| `go install` | `/usr/local/bin/gopls` |
| `rust-analyzer-mcp` | crates.io / cargo | `cargo install --root /usr/local` | `/usr/local/bin/rust-analyzer-mcp` |

---

## 4. Comparative Evaluation Matrices

### 4.1 Office Document Ingestion: MarkItDown vs Docling vs PyMuPDF4LLM

| Dimension | MarkItDown | Docling | PyMuPDF4LLM |
| :--- | :--- | :--- | :--- |
| **Primary Architecture** | Lightweight multi-format parser | Deep ML layout understanding | Local fitz PDF text block extractor |
| **Token Reduction** | Superior (Flattens all to text) | High (Preserves coordinates/meta) | Superior (Removes all visual noise) |
| **Processing Speed** | Extremely Fast (10ms - 200ms) | Slow (1s - 5s per page) | Blazing Fast (1ms - 20ms per page) |
| **Multi-column PDF** | Weak (Sequential text stream) | Excellent (Reorders blocks) | Moderate (Block-based heuristics) |
| **Complex Table Support**| Moderate (Basic cell split) | Outstanding (Cell spans/AST) | Moderate (GFM table heuristics) |
| **DOCX/PPTX/XLSX** | Native & Complete Support | Good (DOCX & PPTX) | None (PDF only) |
| **Resource Footprint** | Low (<50MB RAM) | High (Requires GPU / Torch) | Ultra-low (<30MB RAM) |
| **Best Used For** | Daily office files, bulk preview | Financial reports, research papers| High-throughput digital PDF corpora |

### 4.2 Web & DOM Strippers: Trafilatura vs Readability+Turndown vs Readdown

| Dimension | Trafilatura | Readability + Turndown | Readdown |
| :--- | :--- | :--- | :--- |
| **Implementation** | Python (`lxml`) | JavaScript (Node.js/JSDOM) | JavaScript (Zero dependencies) |
| **Average F1 Accuracy** | ~0.910 (Robust across web) | ~0.940 (Long-form articles) | Optimized for AI parsing |
| **Memory / Bundle Size** | Moderate (~20MB Python) | Heavy (JSDOM ~65KB bundle) | Minimal (~5KB bundle) |
| **Execution Latency** | Fast (50ms - 300ms) | Moderate (JSDOM initialization)| Ultra-fast (~40% faster) |
| **Multi-lingual Support**| Native multi-language rules | Moderate (English-centric) | Preserves semantic headers & tables |
| **Best Used For** | Web crawlers, news, blogs | Reader modes, article archives | Real-time CLI & Agent workflows |

---

## 5. Deployment Architectures

### 5.1 System-Wide (Root / Sudo) Deployment Architecture

For multi-user Linux workstations and server environments, the system deployment is executed using `deploy-doc-tools.sh`.

```
/usr/local/bin/
├── markitdown                  -> /opt/doc-token-tools/bin/markitdown
├── docling                     -> /opt/doc-token-tools/bin/docling
├── trafilatura                 -> /opt/doc-token-tools/bin/trafilatura
├── fastmcp                     -> /opt/doc-token-tools/bin/fastmcp
├── aider                       -> /opt/indexing-python-tools/bin/aider (or doc-token-tools)
├── convert-doc                 -> (Unified CLI Converter)
├── patch-docx-xml              -> (XPath DOCX Patcher)
├── purify-web                  -> (Web Content Purifier)
├── repomix                     -> /usr/local/lib/node_modules/repomix/...
├── readdown                    -> /usr/local/lib/node_modules/readdown/...
├── pyright                     -> /usr/local/lib/node_modules/pyright/...
├── toktoken                    (C binary)
├── scip                        (Official CLI)
├── scip-search                 (Go binary)
└── rust-analyzer               (Rust binary)

/opt/uv-python/
└── cpython-3.12-linux-x86_64-gnu/ (World-readable Python 3.12 runtime)

/opt/doc-token-tools/
├── bin/python (3.12)
├── lib/python3.12/site-packages/
└── permissions: 755 (chmod -R a+rX)

/etc/profile.d/doc-token-tools.sh
└── Export PATH=/usr/local/bin:$PATH and NODE_PATH=/usr/local/lib/node_modules
```

**Key Isolation Features**:
1. **PEP 668 & Python 3.14 Compatibility**: Ubuntu 26.04 ships with Python 3.14. Native packages like PyTorch, OpenCV, and SciPy lack binary wheels on PyPI for 3.14. The deploy script uses Astral `uv` to provision a world-readable Python 3.12 runtime in `/opt/uv-python`.
2. **No Root Privilege Leaks**: By setting `UV_PYTHON_INSTALL_DIR=/opt/uv-python` and enforcing `chmod -R a+rX`, regular users can execute binaries without running into `bad interpreter: Permission denied` caused by root-restricted paths (`/root/.local/share/uv`).
3. **Global Node Resolution**: Configures `NODE_PATH=/usr/local/lib/node_modules` in `/etc/profile.d/` so scripts can import `@mozilla/readability` and `turndown` seamlessly.

### 5.2 User-Level (Non-Root) Deployment Architecture

For users without sudo privileges:
* Script: `install-doc-token-tools-user.sh`
* Executables: Installed to `~/.local/bin`
* Python Environment: `~/.local/share/doc-token-tools-venv` via `uv`
* Node Packages: Configured via `npm config set prefix ~/.local`
* PATH Setup: Configured in `~/.bashrc`

---

## 6. Verification & Validation Protocol

The verification script `verify-doc-tools.sh` performs automated smoke tests across all deployed components:

1. **Binary & Version Checks**:
   * Runs `--version` or `--help` across `markitdown`, `docling`, `trafilatura`, `readdown`, `repomix`, `toktoken`, `scip`, `scip-search`, `pyright`, `aider`, `rust-analyzer`.
2. **Functional Smoke Tests**:
   * **MarkItDown**: Converts a test markdown/office text stream.
   * **PyMuPDF4LLM & python-docx + lxml**: Validates XML document tree parsing and XPath querying.
   * **Trafilatura & Readdown**: Ingests sample messy HTML with scripts and navigation bars, verifying that headers, articles, and tables are preserved while boilerplate is stripped.
   * **Repomix**: Runs AST compression dry-run (`--compress`).
   * **TokToken & SCIP**: Confirms symbol indexing indexes and protobuf parser compatibility.
3. **Exit Code & Status Summary**:
   * Reports total Passed, Failed, and Warned checks with clear actionable diagnostics.

---

## 7. AI Coding CLI Skills Specification

To enable autonomous agent discovery, capabilities are packaged following the `SKILL.md` specification:

| Skill Directory | Target CLI Commands | Primary Agent Capabilities |
| :--- | :--- | :--- |
| `skills/doc-token-optimizer` | `/convert-doc`, MarkItDown, PyMuPDF4LLM, Docling | Ingest PDF, DOCX, PPTX, XLSX to Markdown |
| `skills/docx-xml-patcher` | `/patch-docx-xml`, `scripts/patch_docx_xml.py` | XPath incremental XML micro-patching |
| `skills/web-content-purifier` | `/purify-web`, Trafilatura, Readdown | Strip web DOM boilerplate to clean Markdown |
| `skills/ast-code-compressor` | `/ast-compress`, Repomix (`--compress`) | AST-level code stripping of function bodies |
| `skills/toktoken-symbol-search`| `/toktoken-search`, TokToken | Precision symbol retrieval (88-99% savings) |
| `skills/repo-map-navigator` | `/repo-map`, Aider | Topological PageRank codebase navigation |
| `skills/scip-semantic-indexer` | `/scip-index`, SCIP, scip-search | Cross-language compiler semantic code graphs |
| `skills/fastmcp-document-server`| FastMCP stdio server | Model Context Protocol tools provider |

The included `install-skills.sh` script installs and symlinks skills for both workspace discovery (`.agents/skills/`) and global agent discovery (`~/.agents/skills/` and `~/.gemini/config/skills/`).

---

## 8. License

This deployment suite and associated tooling are distributed under the terms of the **GNU Affero General Public License v3.0 (AGPL-3.0)**. See [LICENSE](file:///home/macpaul/doc-codeindex/LICENSE) for the complete legal text.
