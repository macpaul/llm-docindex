#!/usr/bin/env python3
"""
scripts/convert_doc.py
Multi-engine office document and presentation converter for LLM Token Optimization.
Supports MarkItDown, PyMuPDF4LLM, and Docling with automatic fallback.
Converts PDF, DOCX, PPTX, XLSX, and HTML into high-density Markdown.
"""

import argparse
import os
import sys
from pathlib import Path


def convert_with_markitdown(file_path: str) -> str:
    from markitdown import MarkItDown
    converter = MarkItDown()
    result = converter.convert(file_path)
    return result.text_content


def convert_with_pymupdf(file_path: str) -> str:
    import pymupdf4llm
    return pymupdf4llm.to_markdown(file_path)


def convert_with_docling(file_path: str) -> str:
    from docling.document_converter import DocumentConverter
    converter = DocumentConverter()
    result = converter.convert(file_path)
    return result.document.export_to_markdown()


def estimate_tokens(text: str) -> int:
    """Rough heuristic estimate of tokens (approx 4 chars per token)."""
    return max(1, len(text) // 4)


def main():
    parser = argparse.ArgumentParser(
        description="Convert PDF, DOCX, PPTX, XLSX, and HTML to Markdown to save LLM context tokens."
    )
    parser.add_argument("input_file", help="Path to input document (PDF, DOCX, PPTX, XLSX, HTML)")
    parser.add_argument("-o", "--output", help="Output file path (default: stdout)")
    parser.add_argument(
        "-e",
        "--engine",
        choices=["auto", "markitdown", "pymupdf", "docling"],
        default="auto",
        help="Conversion engine to use (default: auto)",
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Print token savings statistics to stderr",
    )

    args = parser.parse_args()
    input_path = Path(args.input_file).resolve()

    if not input_path.exists():
        sys.stderr.write(f"Error: File not found: {input_path}\n")
        sys.exit(1)

    suffix = input_path.suffix.lower()
    raw_size_bytes = input_path.stat().st_size
    markdown_content = ""
    used_engine = ""

    # Engine selection logic
    if args.engine == "pymupdf" or (args.engine == "auto" and suffix == ".pdf"):
        try:
            markdown_content = convert_with_pymupdf(str(input_path))
            used_engine = "pymupdf4llm"
        except Exception as e:
            if args.engine != "auto":
                raise
            sys.stderr.write(f"[WARN] PyMuPDF4LLM failed ({e}), falling back to MarkItDown...\n")

    if not markdown_content and (args.engine in ("auto", "markitdown")):
        try:
            markdown_content = convert_with_markitdown(str(input_path))
            used_engine = "markitdown"
        except Exception as e:
            if args.engine != "auto":
                raise
            sys.stderr.write(f"[WARN] MarkItDown failed ({e}), attempting Docling fallback...\n")

    if not markdown_content and (args.engine in ("auto", "docling")):
        try:
            markdown_content = convert_with_docling(str(input_path))
            used_engine = "docling"
        except Exception as e:
            sys.stderr.write(f"[ERROR] All conversion engines failed. Last error: {e}\n")
            sys.exit(1)

    if not markdown_content:
        sys.stderr.write("[ERROR] Conversion produced no content.\n")
        sys.exit(1)

    # Output handling
    if args.output:
        out_path = Path(args.output).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(markdown_content, encoding="utf-8")
        sys.stderr.write(f"Converted {input_path.name} -> {out_path} using {used_engine}\n")
    else:
        sys.stdout.write(markdown_content)

    if args.stats:
        output_tokens = estimate_tokens(markdown_content)
        # Raw estimate: binary PDF / Office XML tokens is roughly 1 token per 2 bytes or higher
        raw_token_estimate = max(1, raw_size_bytes // 2)
        reduction = max(0.0, (1.0 - (output_tokens / raw_token_estimate)) * 100.0)
        sys.stderr.write("\n--- Token Optimization Stats ---\n")
        sys.stderr.write(f"Engine:           {used_engine}\n")
        sys.stderr.write(f"Original size:    {raw_size_bytes:,} bytes (~{raw_token_estimate:,} tokens)\n")
        sys.stderr.write(f"Markdown size:    {len(markdown_content):,} chars (~{output_tokens:,} tokens)\n")
        sys.stderr.write(f"Estimated saving: {reduction:.1f}%\n")


if __name__ == "__main__":
    main()
