#!/usr/bin/env bash
# ==============================================================================
# deploy-doc-tools.sh
# System-wide (root/sudo) deployment script for LLM Document Token Optimization & Retrieval Tools
# Target OS: Ubuntu 22.04 / 24.04 / 26.04 (Debian-based x86_64 & aarch64)
# Deploy Destination: /usr/local/bin (accessible to all system users)
# Python Environment: /opt/doc-token-tools (managed Python 3.12 via uv)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo -e "\n${CYAN}${BOLD}==>${NC} ${BOLD}$*${NC}"
}

# ------------------------------------------------------------------------------
# 0. Check Root / Sudo Privileges
# ------------------------------------------------------------------------------
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log_error "This script must be executed with root privileges for system-wide installation."
    echo -e "Please re-run with: ${BOLD}sudo $0${NC}"
    exit 1
fi

ARCH="$(uname -m)"
log_info "Detected Architecture: ${ARCH}"
case "${ARCH}" in
    x86_64)
        TOKTOKEN_ARCH="x86_64"
        SCIP_ARCH="amd64"
        UV_ARCH="x86_64-unknown-linux-gnu"
        RUST_ANALYZER_ARCH="x86_64-unknown-linux-gnu"
        ;;
    aarch64|arm64)
        TOKTOKEN_ARCH="aarch64"
        SCIP_ARCH="arm64"
        UV_ARCH="aarch64-unknown-linux-gnu"
        RUST_ANALYZER_ARCH="aarch64-unknown-linux-gnu"
        ;;
    *)
        log_warn "Architecture ${ARCH} might require manual builds for binary assets."
        TOKTOKEN_ARCH="x86_64"
        SCIP_ARCH="amd64"
        UV_ARCH="x86_64-unknown-linux-gnu"
        RUST_ANALYZER_ARCH="x86_64-unknown-linux-gnu"
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$(mktemp -d -t doc-token-deploy-XXXXXX)"
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# 1. Install Ubuntu Native Packages via APT
# ------------------------------------------------------------------------------
log_step "Step 1: Installing Ubuntu system packages via APT"
export DEBIAN_FRONTEND=noninteractive

apt-get update -y

APT_PACKAGES=(
    build-essential
    gfortran
    pkg-config
    libxml2-dev
    libxslt1-dev
    zlib1g-dev
    libsqlite3-dev
    sqlite3
    universal-ctags
    poppler-utils
    tesseract-ocr
    tesseract-ocr-eng
    pandoc
    libgl1
    libglib2.0-0
    curl
    wget
    git
    jq
    unzip
    tar
    gzip
    python3
    python3-pip
    python3-venv
    libopenblas-dev
    liblapack-dev
    cargo
    rustc
)

# Optional multi-language OCR packages if available
for ocr_pkg in tesseract-ocr-chi-tra tesseract-ocr-chi-sim; do
    if apt-cache show "${ocr_pkg}" >/dev/null 2>&1; then
        APT_PACKAGES+=("${ocr_pkg}")
    fi
done

# Check for nodejs and golang-go if not already present
if ! command -v node >/dev/null 2>&1; then
    APT_PACKAGES+=(nodejs npm)
fi
if ! command -v go >/dev/null 2>&1; then
    APT_PACKAGES+=(golang-go)
fi

apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"
log_success "APT packages successfully installed."

# ------------------------------------------------------------------------------
# 2. Install Astral UV (Fast, Isolated System-wide Python Runner)
# ------------------------------------------------------------------------------
log_step "Step 2: Installing Astral uv & uvx into /usr/local/bin"
if ! command -v uv >/dev/null 2>&1; then
    log_info "Downloading standalone uv archive..."
    UV_URL="https://github.com/astral-sh/uv/releases/latest/download/uv-${UV_ARCH}.tar.gz"
    curl -fsSL "${UV_URL}" -o "${TEMP_DIR}/uv.tar.gz"
    tar -xzf "${TEMP_DIR}/uv.tar.gz" -C "${TEMP_DIR}"
    install -m 755 "${TEMP_DIR}/uv-${UV_ARCH}/uv" /usr/local/bin/uv
    install -m 755 "${TEMP_DIR}/uv-${UV_ARCH}/uvx" /usr/local/bin/uvx
    log_success "Installed uv: $(/usr/local/bin/uv --version)"
else
    log_info "uv is already installed at $(command -v uv)"
fi

# ------------------------------------------------------------------------------
# 3. Install Global NPM Packages (Repomix, Readdown, Readability, Turndown, LSPs)
# ------------------------------------------------------------------------------
log_step "Step 3: Installing global NPM packages for DOM purifying, AST, and LSPs"
NPM_PACKAGES=(
    repomix
    repomix-rs
    readdown
    @mozilla/readability
    turndown
    turndown-plugin-gfm
    jsdom
    linkedom
    tree-sitter-cli
    pyright
    typescript
    typescript-language-server
    @vtsls/language-server
    @sourcegraph/scip-typescript
    @sourcegraph/scip-python
)

log_info "Installing: ${NPM_PACKAGES[*]}"
npm install -g "${NPM_PACKAGES[@]}"
log_success "Global NPM packages installed."

# ------------------------------------------------------------------------------
# 4. Install Standalone GitHub Binaries into /usr/local/bin
# ------------------------------------------------------------------------------
log_step "Step 4: Installing Standalone GitHub Binaries into /usr/local/bin"

# 4.1 TokToken (mauriziofonte/toktoken)
if ! command -v toktoken >/dev/null 2>&1; then
    log_info "Deploying TokToken (Single C binary, SQLite FTS5 + ctags)..."
    TOKTOKEN_URL="https://github.com/mauriziofonte/toktoken/releases/latest/download/toktoken-linux-${TOKTOKEN_ARCH}"
    if curl -fsSL -o "${TEMP_DIR}/toktoken" "${TOKTOKEN_URL}"; then
        install -m 755 "${TEMP_DIR}/toktoken" /usr/local/bin/toktoken
        log_success "Installed TokToken: /usr/local/bin/toktoken"
    else
        log_warn "Failed to download prebuilt TokToken."
    fi
else
    log_info "toktoken already installed at $(command -v toktoken)"
fi

# 4.2 rust-analyzer (Official Rust LSP)
if ! command -v rust-analyzer >/dev/null 2>&1; then
    log_info "Deploying rust-analyzer..."
    RUST_ANALYZER_URL="https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-${RUST_ANALYZER_ARCH}.gz"
    if curl -fsSL -o "${TEMP_DIR}/rust-analyzer.gz" "${RUST_ANALYZER_URL}"; then
        gzip -d -f "${TEMP_DIR}/rust-analyzer.gz"
        install -m 755 "${TEMP_DIR}/rust-analyzer" /usr/local/bin/rust-analyzer
        log_success "Installed rust-analyzer"
    fi
else
    log_info "rust-analyzer already installed at $(command -v rust-analyzer)"
fi

# 4.3 scip CLI (sourcegraph/scip)
if ! command -v scip >/dev/null 2>&1; then
    log_info "Deploying SCIP CLI..."
    SCIP_URL="https://github.com/scip-code/scip/releases/latest/download/scip-linux-${SCIP_ARCH}.tar.gz"
    if curl -fsSL -o "${TEMP_DIR}/scip.tar.gz" "${SCIP_URL}"; then
        tar -xzf "${TEMP_DIR}/scip.tar.gz" -C "${TEMP_DIR}"
        if [[ -f "${TEMP_DIR}/scip" ]]; then
            install -m 755 "${TEMP_DIR}/scip" /usr/local/bin/scip
        elif [[ -f "${TEMP_DIR}/scip-linux-${SCIP_ARCH}/scip" ]]; then
            install -m 755 "${TEMP_DIR}/scip-linux-${SCIP_ARCH}/scip" /usr/local/bin/scip
        fi
        log_success "Installed scip CLI: $(/usr/local/bin/scip --version || true)"
    fi
else
    log_info "scip already installed at $(command -v scip)"
fi

# 4.4 scip-clang (C/C++ SCIP Indexer)
if [[ "${ARCH}" == "x86_64" ]] && ! command -v scip-clang >/dev/null 2>&1; then
    log_info "Deploying scip-clang for C/C++..."
    SCIP_CLANG_URL="https://github.com/sourcegraph/scip-clang/releases/download/v0.4.0/scip-clang-x86_64-linux"
    if curl -fsSL -o "${TEMP_DIR}/scip-clang" "${SCIP_CLANG_URL}"; then
        install -m 755 "${TEMP_DIR}/scip-clang" /usr/local/bin/scip-clang
        log_success "Installed scip-clang: /usr/local/bin/scip-clang"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Install Python Document Optimization & Retrieval Tools System-wide
# ------------------------------------------------------------------------------
log_step "Step 5: Installing Python Document Optimization Tools System-wide via uv"

export UV_PYTHON_INSTALL_DIR="/opt/uv-python"
mkdir -p "${UV_PYTHON_INSTALL_DIR}"
chmod 755 "${UV_PYTHON_INSTALL_DIR}"

SYSTEM_VENV="/opt/doc-token-tools"

# Recreate venv if pointing to restricted root path
if [[ -L "${SYSTEM_VENV}/bin/python" ]]; then
    current_target="$(readlink -f "${SYSTEM_VENV}/bin/python" 2>/dev/null || true)"
    if [[ "${current_target}" == /root/* ]]; then
        log_info "Detected existing venv pointing to restricted /root directory. Recreating..."
        rm -rf "${SYSTEM_VENV}"
    fi
fi
mkdir -p "${SYSTEM_VENV}"

# Manage Python 3.12 runtime to guarantee binary wheel availability
TARGET_PYTHON="3.12"
log_info "Ensuring managed Python ${TARGET_PYTHON} runtime in ${UV_PYTHON_INSTALL_DIR}..."
uv python install "${TARGET_PYTHON}"

log_info "Creating virtual environment at ${SYSTEM_VENV}..."
uv venv "${SYSTEM_VENV}" --python "${TARGET_PYTHON}"

PYTHON_TOOLS=(
    "markitdown"
    "pymupdf4llm"
    "docling"
    "trafilatura"
    "python-docx"
    "lxml"
    "openpyxl"
    "python-pptx"
    "fastmcp"
    "mcp"
    "aider-chat"
    "beautifulsoup4"
    "pydantic"
)

log_info "Installing Python document token tools into ${SYSTEM_VENV}..."
for pkg in "${PYTHON_TOOLS[@]}"; do
    log_info "Installing ${pkg}..."
    if uv pip install --python "${SYSTEM_VENV}/bin/python" "${pkg}"; then
        log_success "Successfully installed ${pkg}"
    else
        log_warn "Failed to install ${pkg}. Continuing..."
    fi
done

# Ensure world-read and world-execute permissions
chmod -R a+rX "${SYSTEM_VENV}" "${UV_PYTHON_INSTALL_DIR}" 2>/dev/null || true

# Symlink CLI executables into /usr/local/bin
log_info "Creating symlinks in /usr/local/bin for all users..."
for bin_name in markitdown docling trafilatura fastmcp aider; do
    if [[ -f "${SYSTEM_VENV}/bin/${bin_name}" ]]; then
        ln -sf "${SYSTEM_VENV}/bin/${bin_name}" "/usr/local/bin/${bin_name}"
        log_success "Symlinked ${bin_name} -> /usr/local/bin/${bin_name}"
    fi
done

# ------------------------------------------------------------------------------
# 6. Compile & Install Go Tools (gopls, scip-go, scip-search)
# ------------------------------------------------------------------------------
log_step "Step 6: Building and Installing Go Tools (gopls, scip-go, scip-search)"

export GOPATH="${TEMP_DIR}/go"
export GOCACHE="${TEMP_DIR}/go-cache"
mkdir -p "${GOPATH}" "${GOCACHE}"

if ! command -v gopls >/dev/null 2>&1; then
    log_info "Compiling gopls..."
    go install golang.org/x/tools/gopls@latest || log_warn "gopls install failed"
fi

if ! command -v scip-go >/dev/null 2>&1; then
    log_info "Compiling scip-go..."
    go install github.com/scip-code/scip-go/cmd/scip-go@latest || log_warn "scip-go install failed"
fi

if ! command -v scip-search >/dev/null 2>&1; then
    log_info "Building scip-search from source..."
    if git clone --depth 1 https://github.com/liza-mas/scip-search.git "${TEMP_DIR}/scip-search-src" 2>/dev/null; then
        (cd "${TEMP_DIR}/scip-search-src" && go build -o "${TEMP_DIR}/scip-search" ./cmd/scip-search)
        install -m 755 "${TEMP_DIR}/scip-search" /usr/local/bin/scip-search
        log_success "Installed scip-search: /usr/local/bin/scip-search"
    fi
fi

if [[ -d "${GOPATH}/bin" ]]; then
    for gobin in "${GOPATH}/bin"/*; do
        if [[ -f "${gobin}" ]]; then
            bname="$(basename "${gobin}")"
            install -m 755 "${gobin}" "/usr/local/bin/${bname}"
            log_success "Installed Go tool /usr/local/bin/${bname}"
        fi
    done
fi

# ------------------------------------------------------------------------------
# 7. Rust MCP Tools (rust-analyzer-mcp)
# ------------------------------------------------------------------------------
log_step "Step 7: Installing Rust Indexing Tools"
if ! command -v rust-analyzer-mcp >/dev/null 2>&1; then
    log_info "Compiling rust-analyzer-mcp..."
    cargo install --root /usr/local rust-analyzer-mcp || log_warn "rust-analyzer-mcp build skipped"
fi

# ------------------------------------------------------------------------------
# 8. Install Custom CLI Wrapper Scripts
# ------------------------------------------------------------------------------
log_step "Step 8: Deploying Custom Document CLI Helper Tools to /usr/local/bin"

install_wrapper() {
    local target_cmd="$1"
    local script_name="$2"
    local wrapper_path="/usr/local/bin/${target_cmd}"

    cat << EOF > "${wrapper_path}"
#!/usr/bin/env bash
# Wrapper for ${script_name} using isolated Python runtime
exec /opt/doc-token-tools/bin/python "${SCRIPT_DIR}/scripts/${script_name}" "\$@"
EOF
    chmod 755 "${wrapper_path}"
    log_success "Deployed CLI wrapper: ${wrapper_path} -> scripts/${script_name}"
}

install_wrapper "convert-doc" "convert_doc.py"
install_wrapper "patch-docx-xml" "patch_docx_xml.py"
install_wrapper "purify-web" "purify_web.py"
install_wrapper "doc-mcp-server" "doc_mcp_server.py"

# ------------------------------------------------------------------------------
# 9. Configure Global Environment Profile (/etc/profile.d)
# ------------------------------------------------------------------------------
log_step "Step 9: Configuring /etc/profile.d/doc-token-tools.sh"
cat << 'EOF' > /etc/profile.d/doc-token-tools.sh
# System-wide environment configuration for Document Token Optimization Tools
if [ -d "/usr/local/bin" ]; then
    case ":$PATH:" in
        *:/usr/local/bin:*) ;;
        *) export PATH="/usr/local/bin:$PATH" ;;
    esac
fi

# Ensure global Node modules resolution for Readability & Turndown
export NODE_PATH="/usr/local/lib/node_modules${NODE_PATH:+:$NODE_PATH}"

# Ensure user cache for TokToken
export TOKTOKEN_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/toktoken"
EOF
chmod 644 /etc/profile.d/doc-token-tools.sh
log_success "Configured /etc/profile.d/doc-token-tools.sh"

# Ensure standard permissions on /usr/local/bin tools
chmod 755 /usr/local/bin/* 2>/dev/null || true

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}${BOLD}====================================================================${NC}"
echo -e "${GREEN}${BOLD} All Document Token Optimization Tools Deployed System-Wide!       ${NC}"
echo -e "${GREEN}${BOLD}====================================================================${NC}"
echo -e "You can now run ${BOLD}./verify-doc-tools.sh${NC} to validate all installations.\n"
