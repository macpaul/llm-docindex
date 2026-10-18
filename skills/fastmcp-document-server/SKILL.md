---
name: fastmcp-document-server
description: Model Context Protocol (MCP) server lifecycle and tool definitions for document token optimization. Exposes read_document_optimized, incremental_docx_update, and purify_web_content over stdio/SSE for Claude Desktop, Antigravity, and Cursor.
---

# FastMCP Document Server Skill

## When to Use This Skill
* Use when configuring an MCP client (such as Google Antigravity, Claude Desktop, Cursor, or Zed) to communicate directly with document token optimization tools.
* Use when wrapping new Python document processing logic into MCP tool functions using the `@mcp.tool` decorator.
* Use to launch or test the stdio transport server.

## Quick Start
```bash
# Launch server via stdio transport (standard for local agents)
python3 scripts/doc_mcp_server.py

# Or run using FastMCP CLI
fastmcp run scripts/doc_mcp_server.py

# Inspect MCP tools and generated JSON schemas
fastmcp inspect scripts/doc_mcp_server.py
```

## MCP Configuration Example (`mcp_config.json`)
```json
{
  "mcpServers": {
    "document-optimizer": {
      "command": "/opt/doc-token-tools/bin/python",
      "args": ["/home/macpaul/doc-codeindex/scripts/doc_mcp_server.py"],
      "env": {
        "NODE_PATH": "/usr/local/lib/node_modules"
      }
    }
  }
}
```

## Available MCP Tools
1. **`read_document_optimized`**:
   - Parameters: `file_path: str`, `engine: str = "auto"`
   - Returns: Flattened Markdown representation of PDF/DOCX/PPTX/XLSX.
2. **`incremental_docx_update`**:
   - Parameters: `file_path: str`, `find_text: str`, `replace_text: str`, `xpath_query: str`, `new_text: str`, `dry_run: bool`
   - Returns: JSON report of patched XML nodes and token economy metrics.
3. **`purify_web_content`**:
   - Parameters: `url_or_html: str`, `is_url: bool = True`
   - Returns: Boilerplate-stripped semantic Markdown.
