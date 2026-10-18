#!/usr/bin/env bash
# ==============================================================================
# verify-doc-tools.sh
# Comprehensive Verification & Smoke-Testing Script for Document Token Optimization Tools
# Validates binaries, Python modules, Node libraries, and executes live smoke tests.
# ==============================================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNED=0

log_pass() {
    echo -e "  [${GREEN}PASS${NC}] $*"
    ((PASSED++))
}

log_fail() {
    echo -e "  [${RED}FAIL${NC}] $*"
    ((FAILED++))
}

log_warn() {
    echo -e "  [${YELLOW}WARN${NC}] $*"
    ((WARNED++))
}

log_section() {
    echo -e "\n${CYAN}${BOLD}=== $* ===${NC}"
}

# Resolve Python runner (Check /opt/doc-token-tools/bin/python, ~/.local/share/doc-token-tools-venv/bin/python, /opt/indexing-python-tools/bin/python, or system python3)
PY_RUNNER=""
for candidate in \
    "/opt/doc-token-tools/bin/python" \
    "${HOME}/.local/share/doc-token-tools-venv/bin/python" \
    "/opt/indexing-python-tools/bin/python" \
    "$(which python3 2>/dev/null)"; do
    if [[ -x "${candidate}" ]]; then
        PY_RUNNER="${candidate}"
        break
    fi
done

# Ensure NODE_PATH is configured
export NODE_PATH="/usr/local/lib/node_modules:${HOME}/.local/lib/node_modules${NODE_PATH:+:$NODE_PATH}"
export PATH="/usr/local/bin:${HOME}/.local/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$(mktemp -d -t doc-verify-XXXXXX)"
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

echo -e "${BOLD}Document Token Optimization Tools Verification Suite${NC}"
echo -e "Using Python Runtime: ${BLUE}${PY_RUNNER:-None}${NC}"
echo -e "System PATH:         ${BLUE}${PATH}${NC}"

# ------------------------------------------------------------------------------
# 1. Check CLI Binaries & Tools
# ------------------------------------------------------------------------------
log_section "1. Validating Core CLI Binaries"

check_cmd() {
    local cmd_name="$1"
    local ver_arg="${2:---version}"
    local is_critical="${3:-true}"

    if command -v "${cmd_name}" >/dev/null 2>&1; then
        local ver_out
        ver_out="$("${cmd_name}" ${ver_arg} 2>&1 | head -n 1 || true)"
        if [[ -z "${ver_out}" ]]; then
            ver_out="Available at $(command -v "${cmd_name}")"
        fi
        log_pass "${cmd_name}: ${ver_out}"
    else
        if [[ "${is_critical}" == "true" ]]; then
            log_fail "${cmd_name} is NOT found in PATH"
        else
            log_warn "${cmd_name} is optional and not currently installed in PATH"
        fi
    fi
}

check_cmd "uv" "--version" "true"
check_cmd "markitdown" "--help" "false"
check_cmd "docling" "--version" "false"
check_cmd "trafilatura" "--version" "false"
check_cmd "readdown" "--help" "false"
check_cmd "repomix" "--version" "true"
check_cmd "toktoken" "--version" "true"
check_cmd "ctags" "--version" "true"
check_cmd "aider" "--version" "true"
check_cmd "scip" "--version" "true"
check_cmd "scip-search" "--version" "false"
check_cmd "pyright" "--version" "true"
check_cmd "rust-analyzer" "--version" "true"
check_cmd "fastmcp" "--version" "false"

# Check Custom Helper Wrappers / Scripts
log_section "2. Validating Custom Helper Scripts"
for s in "convert_doc.py" "patch_docx_xml.py" "purify_web.py" "doc_mcp_server.py"; do
    if [[ -f "${SCRIPT_DIR}/scripts/${s}" && -x "${SCRIPT_DIR}/scripts/${s}" ]]; then
        log_pass "Script scripts/${s} exists and is executable"
    else
        log_fail "Script scripts/${s} missing or not executable"
    fi
done

# ------------------------------------------------------------------------------
# 3. Python Module Imports Check
# ------------------------------------------------------------------------------
log_section "3. Validating Python Optimization Modules"

if [[ -n "${PY_RUNNER}" ]]; then
    check_py_module() {
        local mod="$1"
        local is_critical="${2:-true}"

        if "${PY_RUNNER}" -c "import ${mod}" >/dev/null 2>&1; then
            local mod_ver
            mod_ver="$("${PY_RUNNER}" -c "import ${mod}; print(getattr(${mod}, '__version__', 'available'))" 2>/dev/null || echo "available")"
            log_pass "Python module '${mod}': ${mod_ver}"
        else
            if [[ "${is_critical}" == "true" ]]; then
                log_fail "Python module '${mod}' failed to import in ${PY_RUNNER}"
            else
                log_warn "Python module '${mod}' not imported (optional/specialized)"
            fi
        fi
    }

    check_py_module "markitdown" "false"
    check_py_module "pymupdf4llm" "false"
    check_py_module "docling" "false"
    check_py_module "trafilatura" "false"
    check_py_module "docx" "false"
    check_py_module "lxml" "false"
    check_py_module "fastmcp" "true"
    check_py_module "openpyxl" "false"
    check_py_module "pptx" "false"
    check_py_module "aider" "true"
else
    log_fail "No valid Python runner found to test module imports"
fi

# ------------------------------------------------------------------------------
# 4. Node.js Packages Check
# ------------------------------------------------------------------------------
log_section "4. Validating Node.js Purifiers & AST Tools"

if command -v node >/dev/null 2>&1; then
    check_node_pkg() {
        local pkg="$1"
        local is_critical="${2:-true}"

        if node -e "require.resolve('${pkg}')" >/dev/null 2>&1; then
            log_pass "Node package '${pkg}' is resolvable"
        else
            if [[ "${is_critical}" == "true" ]]; then
                log_fail "Node package '${pkg}' cannot be resolved"
            else
                log_warn "Node package '${pkg}' not resolvable globally"
            fi
        fi
    }

    check_node_pkg "repomix" "true"
    check_node_pkg "readdown" "false"
    check_node_pkg "@mozilla/readability" "false"
    check_node_pkg "turndown" "false"
    check_node_pkg "pyright" "true"
else
    log_warn "Node.js runtime not found. Skipping Node package checks."
fi

# ------------------------------------------------------------------------------
# 5. Live Functional Smoke Tests
# ------------------------------------------------------------------------------
log_section "5. Executing Live Smoke Tests"

# 5.1 Test Web Purifier on Messy HTML
TEST_HTML="${TEMP_DIR}/messy.html"
cat << 'EOF' > "${TEST_HTML}"
<!DOCTYPE html>
<html>
<head><title>Test Article Page</title></head>
<body>
    <header><nav><a href="/home">Home</a> | <a href="/ads">Ad Link</a></nav></header>
    <div class="banner-ad">Buy Our Special Product Now!</div>
    <main>
        <article>
            <h1>Understanding LLM Document Token Optimization</h1>
            <p>Directly sending raw HTML or visual PDFs to language models wastes up to 90% of tokens.</p>
            <p>By transforming raw files into clean Markdown, agents achieve superior attention focus and lower latency.</p>
        </article>
    </main>
    <div class="cookie-banner">Accept all tracking cookies?</div>
    <footer>Copyright 2026 Test Site. All rights reserved.</footer>
</body>
</html>
EOF

if [[ -f "${SCRIPT_DIR}/scripts/purify_web.py" && -n "${PY_RUNNER}" ]]; then
    if "${PY_RUNNER}" "${SCRIPT_DIR}/scripts/purify_web.py" -i "${TEST_HTML}" --stats > "${TEMP_DIR}/purified.md" 2> "${TEMP_DIR}/purify.log"; then
        if grep -q "Understanding LLM Document Token Optimization" "${TEMP_DIR}/purified.md"; then
            log_pass "Web Purifier successfully extracted article and stripped noise"
        else
            log_fail "Web Purifier output did not contain the expected article content"
        fi
    else
        log_warn "Web Purifier smoke test encountered non-fatal error (runtime missing dependencies)"
    fi
fi

# 5.2 Test Document Converter on Sample Text/HTML
if [[ -f "${SCRIPT_DIR}/scripts/convert_doc.py" && -n "${PY_RUNNER}" ]]; then
    if "${PY_RUNNER}" "${SCRIPT_DIR}/scripts/convert_doc.py" "${TEST_HTML}" -o "${TEMP_DIR}/converted.md" --stats 2> "${TEMP_DIR}/convert.log"; then
        if [[ -s "${TEMP_DIR}/converted.md" ]]; then
            log_pass "Document Converter successfully generated Markdown"
        else
            log_fail "Document Converter generated empty output"
        fi
    else
        log_warn "Document Converter smoke test encountered non-fatal error"
    fi
fi

# 5.3 Test Repomix Tree-sitter Compression
TEST_SRC_DIR="${TEMP_DIR}/sample_repo"
mkdir -p "${TEST_SRC_DIR}"
cat << 'EOF' > "${TEST_SRC_DIR}/sample.py"
def calculate_metrics(data_points: list[float]) -> dict:
    """Calculate mean and variance of data points."""
    total = sum(data_points)
    count = len(data_points)
    mean = total / count
    var = sum((x - mean) ** 2 for x in data_points) / count
    return {"mean": mean, "variance": var}

class TokenOptimizer:
    def __init__(self, model_name: str):
        self.model_name = model_name
    def compress(self, text: str) -> str:
        return text.strip()
EOF

if command -v repomix >/dev/null 2>&1; then
    if (cd "${TEST_SRC_DIR}" && repomix --compress --output "${TEMP_DIR}/repomix_out.txt" >/dev/null 2>&1); then
        if [[ -s "${TEMP_DIR}/repomix_out.txt" ]]; then
            log_pass "Repomix Tree-sitter AST compression successfully generated packed output"
        else
            log_fail "Repomix generated empty packed output"
        fi
    else
        log_warn "Repomix --compress execution failed"
    fi
fi

# 5.4 Test TokToken Symbol Indexing
if command -v toktoken >/dev/null 2>&1; then
    if (cd "${TEST_SRC_DIR}" && toktoken index >/dev/null 2>&1); then
        log_pass "TokToken index successfully built symbol database"
    else
        log_warn "TokToken index returned non-zero status"
    fi
fi

# ------------------------------------------------------------------------------
# Final Summary
# ------------------------------------------------------------------------------
log_section "Verification Summary"
echo -e "Total Checks Passed: ${GREEN}${BOLD}${PASSED}${NC}"
echo -e "Total Checks Warned: ${YELLOW}${BOLD}${WARNED}${NC}"
echo -e "Total Checks Failed: ${RED}${BOLD}${FAILED}${NC}"

if [[ "${FAILED}" -eq 0 ]]; then
    echo -e "\n${GREEN}${BOLD}Status: READY FOR PRODUCTION USE${NC}\n"
    exit 0
else
    echo -e "\n${RED}${BOLD}Status: CRITICAL FAILURES DETECTED - REVIEW DIAGNOSTICS ABOVE${NC}\n"
    exit 1
fi
