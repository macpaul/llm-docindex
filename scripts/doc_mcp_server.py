#!/usr/bin/env python3
"""
scripts/doc_mcp_server.py
Model Context Protocol (MCP) Server for Document Token Optimization.
Built using FastMCP to expose document flattening, XML incremental patching,
and web content purification tools to AI Agents (Claude Desktop, Antigravity, Cursor, etc.).
"""

import os
import sys
from pathlib import Path
from fastmcp import FastMCP

# Initialize FastMCP Server
mcp = FastMCP(
    name="Document-Token-Optimizer",
    instructions="Tools to convert heavy multi-format documents (PDF, DOCX, PPTX, HTML) to Markdown and perform incremental XML node patching to minimize LLM token usage.",
)

# Reference sibling scripts
SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS_DIR))


@mcp.tool
def read_document_optimized(file_path: str, engine: str = "auto") -> str:
    """
    Read a PDF, DOCX, PPTX, XLSX, or HTML file and convert it into high-density Markdown.
    Cuts token usage by up to 80% compared to raw document parsing or multi-modal vision.

    Args:
        file_path: Absolute or relative path to the target document.
        engine: 'auto', 'markitdown', 'pymupdf', or 'docling'.
    """
    path = Path(file_path).resolve()
    if not path.exists():
        return f"Error: File does not exist at {file_path}"

    suffix = path.suffix.lower()

    # 1. Try PyMuPDF4LLM for digital PDFs
    if engine == "pymupdf" or (engine == "auto" and suffix == ".pdf"):
        try:
            import pymupdf4llm
            return pymupdf4llm.to_markdown(str(path))
        except Exception as e:
            if engine == "pymupdf":
                return f"PyMuPDF error: {e}"

    # 2. Try MarkItDown for general office docs
    if engine in ("auto", "markitdown"):
        try:
            from markitdown import MarkItDown
            converter = MarkItDown()
            return converter.convert(str(path)).text_content
        except Exception as e:
            if engine == "markitdown":
                return f"MarkItDown error: {e}"

    # 3. Try Docling for deep layout analysis
    if engine in ("auto", "docling"):
        try:
            from docling.document_converter import DocumentConverter
            converter = DocumentConverter()
            result = converter.convert(str(path))
            return result.document.export_to_markdown()
        except Exception as e:
            return f"Docling conversion failed: {e}"

    return "Error: No matching conversion engine found."


@mcp.tool
def incremental_docx_update(
    file_path: str,
    find_text: str = None,
    replace_text: str = None,
    xpath_query: str = None,
    new_text: str = None,
    dry_run: bool = False,
) -> dict:
    """
    Incrementally modify a Word (.docx) document via XML node patching.
    Avoids rewriting the whole document, saving >95% output tokens and preserving
    all corporate formatting, styles, headers, and footers.

    Args:
        file_path: Path to the target .docx file.
        find_text: Text substring to find and replace in text nodes (<w:t>).
        replace_text: Replacement text.
        xpath_query: Explicit XPath query (e.g., //w:t[contains(text(), '2025')]).
        new_text: Text to set on elements matched by xpath_query.
        dry_run: If True, previews changes without writing to file.
    """
    try:
        from patch_docx_xml import patch_docx
        return patch_docx(
            docx_path=file_path,
            xpath_query=xpath_query,
            new_text=new_text,
            find_text=find_text,
            replace_text=replace_text,
            dry_run=dry_run,
        )
    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool
def purify_web_content(url_or_html: str, is_url: bool = True) -> str:
    """
    Purify web pages by stripping ads, scripts, navigation bars, and footers,
    returning clean, high-density Markdown. Reduces web tokens by 85% to 95%.

    Args:
        url_or_html: A web URL (if is_url=True) or raw HTML string (if is_url=False).
        is_url: True if first parameter is a URL to fetch, False if raw HTML.
    """
    try:
        from purify_web import purify_with_trafilatura, purify_with_readdown, fetch_url_html

        if is_url:
            html = fetch_url_html(url_or_html)
            url = url_or_html
        else:
            html = url_or_html
            url = None

        result = purify_with_trafilatura(html, url=url)
        if not result:
            result = purify_with_readdown(html)

        return result or "Error: No article or clean content could be extracted."
    except Exception as e:
        return f"Purification error: {e}"


if __name__ == "__main__":
    # Run stdio transport for local AI CLI / Agent interaction
    mcp.run(transport="stdio")
