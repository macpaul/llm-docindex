#!/usr/bin/env python3
"""
scripts/patch_docx_xml.py
Precision Incremental XML Node Patching Tool for Microsoft Word (.docx).
Allows AI Agents to perform surgical micro-edits on Word documents via XPath
or text targeting without rewriting entire files or corrupting enterprise styles.
Saves >95% LLM output tokens compared to full document regeneration.
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Optional, Dict, Any, List
from lxml import etree

# Standard OpenXML namespaces
NAMESPACES = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "m": "http://schemas.openxmlformats.org/officeDocument/2006/math",
    "v": "urn:schemas-microsoft-com:vml",
    "wp": "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing",
    "w10": "urn:schemas-microsoft-com:office:word",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "pic": "http://schemas.openxmlformats.org/drawingml/2006/picture",
}


def patch_docx(
    docx_path: str,
    xpath_query: Optional[str] = None,
    new_text: Optional[str] = None,
    find_text: Optional[str] = None,
    replace_text: Optional[str] = None,
    target_part: str = "word/document.xml",
    output_path: Optional[str] = None,
    dry_run: bool = False,
) -> Dict[str, Any]:
    docx_file = Path(docx_path).resolve()
    if not docx_file.exists():
        return {"status": "error", "message": f"File not found: {docx_path}"}

    temp_dir = tempfile.mkdtemp(prefix="docx_patch_")
    try:
        # Unpack the DOCX (OPC zip)
        with zipfile.ZipFile(docx_file, "r") as zip_in:
            zip_in.extractall(temp_dir)

        part_file = Path(temp_dir) / target_part
        if not part_file.exists():
            return {
                "status": "error",
                "message": f"Target XML part '{target_part}' not found in {docx_file.name}",
            }

        # Parse XML with lxml
        parser = etree.XMLParser(remove_blank_text=False)
        tree = etree.parse(str(part_file), parser)
        root = tree.getroot()

        modified_nodes = []

        if xpath_query:
            # Custom XPath evaluation
            nodes = root.xpath(xpath_query, namespaces=NAMESPACES)
            for node in nodes:
                if isinstance(node, etree._Element):
                    old_val = node.text or ""
                    node.text = new_text
                    modified_nodes.append(
                        {
                            "tag": node.tag,
                            "old_text": old_val,
                            "new_text": new_text,
                        }
                    )
        elif find_text is not None:
            # Search all text nodes <w:t>
            text_nodes = root.xpath("//w:t", namespaces=NAMESPACES)
            for node in text_nodes:
                if node.text and find_text in node.text:
                    old_val = node.text
                    updated_val = old_val.replace(find_text, replace_text or "")
                    node.text = updated_val
                    modified_nodes.append(
                        {
                            "tag": node.tag,
                            "old_text": old_val,
                            "new_text": updated_val,
                        }
                    )
        else:
            return {
                "status": "error",
                "message": "Either --xpath with --new-text or --find with --replace must be provided.",
            }

        if not modified_nodes:
            return {
                "status": "not_found",
                "message": "No matching XML nodes found for query.",
                "matched_count": 0,
            }

        if not dry_run:
            # Write updated XML back to part
            tree.write(
                str(part_file),
                xml_declaration=True,
                encoding="utf-8",
                standalone=True,
            )

            # Re-pack the DOCX archive
            dest = Path(output_path).resolve() if output_path else docx_file
            dest.parent.mkdir(parents=True, exist_ok=True)

            with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as zip_out:
                for folder_path, _, filenames in os.walk(temp_dir):
                    for filename in filenames:
                        file_path = os.path.join(folder_path, filename)
                        archive_name = os.path.relpath(file_path, temp_dir)
                        zip_out.write(file_path, archive_name)

        return {
            "status": "success",
            "dry_run": dry_run,
            "modified_count": len(modified_nodes),
            "target_part": target_part,
            "modifications": modified_nodes,
            "output_file": str(output_path or docx_path),
            "tokens_saved_estimate": max(500, len(modified_nodes) * 800),
        }

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(
        description="Surgically patch Microsoft Word (.docx) XML nodes via XPath or text replacement."
    )
    parser.add_argument("docx_file", help="Path to input .docx document")
    parser.add_argument("-o", "--output", help="Output path (default: overwrite in-place)")
    parser.add_argument(
        "--xpath",
        help="XPath query targeting XML elements (e.g., //w:t[contains(text(),'2025')])",
    )
    parser.add_argument("--new-text", help="New text to insert into nodes matched by --xpath")
    parser.add_argument("--find", help="Text substring to search for inside <w:t> elements")
    parser.add_argument("--replace", help="Replacement text for matches found by --find")
    parser.add_argument(
        "--part",
        default="word/document.xml",
        help="Target XML part inside DOCX (default: word/document.xml)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview matched nodes and changes without writing to file",
    )
    parser.add_argument("--json", action="store_true", help="Output result as JSON")

    args = parser.parse_args()

    result = patch_docx(
        docx_path=args.docx_file,
        xpath_query=args.xpath,
        new_text=args.new_text,
        find_text=args.find,
        replace_text=args.replace,
        target_part=args.part,
        output_path=args.output,
        dry_run=args.dry_run,
    )

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        if result["status"] == "success":
            dry_msg = " [DRY-RUN - NO CHANGES WRITTEN]" if result.get("dry_run") else ""
            print(f"Successfully patched {result['modified_count']} node(s){dry_msg}.")
            for mod in result.get("modifications", []):
                print(f"  - Changed: '{mod['old_text']}' -> '{mod['new_text']}'")
            print(f"Estimated token savings: ~{result['tokens_saved_estimate']:,} output tokens")
        elif result["status"] == "not_found":
            print(f"[NOT FOUND] {result['message']}", file=sys.stderr)
            sys.exit(2)
        else:
            print(f"[ERROR] {result['message']}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
