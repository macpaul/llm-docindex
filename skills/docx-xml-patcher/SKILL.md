---
name: docx-xml-patcher
description: Incrementally modifies Microsoft Word (.docx) documents using surgical XPath or text replacement on internal OpenXML nodes. Saves >95% LLM output tokens and preserves corporate formatting, styles, headers, and footers without full file rewriting.
---

# DOCX XML Patcher Skill

## When to Use This Skill
* Use whenever an instruction requests modifying, updating, or fixing text in a `.docx` document (such as contracts, formal letters, reports, or invoices).
* **NEVER** ask the LLM to rewrite the entire document or convert the DOCX to Markdown, edit it, and regenerate a new DOCX with pandoc (which completely destroys document formatting, styles, headers, and pagination).
* Use when changing dates, names, amounts, or clauses in existing documents.

## Quick Start CLI Commands
```bash
# Preview changes with dry-run (safe mode)
patch-docx-xml contract.docx --find "2025" --replace "2026" --dry-run

# Execute in-place replacement
patch-docx-xml contract.docx --find "Party A Inc." --replace "Acme Corporation"

# Precise XPath query on <w:t> elements
patch-docx-xml report.docx --xpath "//w:p[1]//w:t" --new-text "Updated Title"

# Target custom XML part (e.g., custom metadata)
patch-docx-xml report.docx --part "docProps/custom.xml" --find "Draft" --replace "Final"

# Output result to a new file
patch-docx-xml template.docx -o customized.docx --find "{{CLIENT_NAME}}" --replace "Google LLC"
```

## Parameter Guidance
* `--find`: Substring match within Word `<w:t>` (text) nodes.
* `--replace`: String to substitute into matched nodes.
* `--xpath`: Precision XPath expression using standard OpenXML namespaces (`w:`, `r:`, `m:`).
* `--new-text`: Value to apply to elements selected by `--xpath`.
* `--dry-run`: Inspect matched nodes, old values, and replacements without writing to disk.
* `--json`: Emit structured output suitable for automated agent pipelines.

## Token Economy
* Standard LLM rewriting a 30-page DOCX: ~25,000 output tokens + loss of corporate styles.
* Incremental XML patching: ~30 output tokens (tool call invocation) + 100% preservation of styles.
