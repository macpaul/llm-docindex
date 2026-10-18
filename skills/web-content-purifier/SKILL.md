---
name: web-content-purifier
description: Strips web page boilerplate, navigation menus, advertisements, cookie banners, tracking codes, and scripts from URLs or HTML files using Trafilatura and Readdown. Extracts clean semantic Markdown, reducing input tokens by 85% to 95%.
---

# Web Content Purifier Skill

## When to Use This Skill
* Use whenever you need to fetch, ingest, or analyze web articles, documentation pages, blogs, or Wikipedia entries.
* **NEVER** pipe raw HTML or unfiltered `curl` responses directly into the LLM context. Raw DOM trees contain up to 90% non-content boilerplate that degrades LLM attention mechanisms and triggers hallucinations.
* Use when building web research summaries or RAG pipelines.

## Quick Start CLI Commands
```bash
# Purify live web URL directly to clean Markdown
purify-web -u "https://en.wikipedia.org/wiki/Large_language_model" -o llm_wiki.md --stats

# Purify a local scraped HTML file
purify-web -i raw_page.html -o clean_article.md

# Purify HTML passed via stdin
curl -s "https://example.com/blog/article" | purify-web -i -

# Use Trafilatura CLI directly
trafilatura -u "https://news.ycombinator.com" --output-format markdown

# Use Readdown CLI directly
readdown raw_dashboard.html > clean_dashboard.md
```

## Engine Heuristics
* **`trafilatura`**: Industry-standard Python extractor with deep XPath heuristics and fallback algorithms. Highest precision on multi-lingual content, news feeds, and blogs (F1 score > 0.91).
* **`readdown`**: Ultra-lightweight (5KB) Node.js package tailored for AI applications. Excellent for retaining complex header hierarchy and tables on structured sites.

## Token Optimization Impact
* Raw HTML page: ~15,000 to ~40,000 tokens (tags, inline CSS/JS, SVG icons, tracking metadata).
* Purified Markdown: ~800 to ~2,500 tokens.
* Attention Gain: Eliminates distracting sidebar tokens, focusing model context entirely on substantive text.
