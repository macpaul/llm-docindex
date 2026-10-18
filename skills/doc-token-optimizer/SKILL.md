---
name: doc-token-optimizer
description: Converts PDF, DOCX, PPTX, and XLSX files into high-density Markdown using MarkItDown, PyMuPDF4LLM, or Docling. Prevents LLM context window overflow and saves 80%+ tokens compared to raw binary or multi-modal vision ingestion.
---

# Document Token Optimizer Skill

## When to Use This Skill
* Use whenever you need to read, analyze, or summarize `.pdf`, `.docx`, `.pptx`, `.xlsx`, or `.html` files.
* **NEVER** attempt to read binary documents or PDF files directly with file viewing tools or rasterize them as raw images into vision models without prior token evaluation.
* Use when preparing multi-document context for RAG or complex report synthesis.

## Quick Start CLI Commands
```bash
# Unified converter (automatically selects optimal engine)
convert-doc input.pdf -o output.md --stats

# Or direct Python script
python3 scripts/convert_doc.py document.docx -o document.md --stats

# MarkItDown directly
markitdown financial_report.xlsx -o report.md

# PyMuPDF4LLM for blazing-fast digital PDF
python3 -c "import pymupdf4llm; print(pymupdf4llm.to_markdown('paper.pdf'))" > paper.md

# Docling for complex academic papers or multi-column financial statements
docling complex_report.pdf --to md -o ./output/
```

## Engine Selection Matrix
* **`markitdown`**: Best default for office files (`.docx`, `.pptx`, `.xlsx`). Automatically flattens spreadsheets into clean Markdown tables.
* **`pymupdf` (`pymupdf4llm`)**: Best for digital PDFs when execution speed is critical (milliseconds per page).
* **`docling`**: Best for research papers, multi-column articles, and complex nested tables requiring deep OCR and reading-order reconstruction.

## Best Practices
1. Always inspect the generated Markdown rather than the original binary file.
2. For large spreadsheets (`.xlsx`), MarkItDown converts each worksheet into a standalone GFM table, stripping hidden formatting styles and cell coordinates.
3. If processing a scanned PDF with no text layer, specify `--engine docling` to engage the OCR pipeline.
