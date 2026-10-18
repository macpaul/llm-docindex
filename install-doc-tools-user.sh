#!/usr/bin/env bash
# ==============================================================================
# install-doc-tools-user.sh
# User-level (non-root) installation script for LLM Document Token Tools
# Target OS: Ubuntu / Linux (x86_64 & aarch64)
# Deploy Destination: ~/.local/bin and ~/.local/share/doc-token-tools-venv
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

USER_BIN="${HOME}/.local/bin"
mkdir -p "${USER_BIN}"

# Ensure ~/.local/bin is in PATH for this script session
export PATH="${USER_BIN}:${PATH}"

ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64)
        UV_ARCH="x86_64-unknown-linux-gnu"
        TOKTOKEN_ARCH="x86_64"
        ;;
    aarch64|arm64)
        UV_ARCH="aarch64-unknown-linux-gnu"
        TOKTOKEN_ARCH="aarch64"
        ;;
    *)
        UV_ARCH="x86_64-unknown-linux-gnu"
        TOKTOKEN_ARCH="x86_64"
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$(mktemp -d -t doc-user-deploy-XXXXXX)"
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# 1. Ensure Astral UV is Installed
# ------------------------------------------------------------------------------
log_step "Step 1: Checking Astral uv..."
if ! command -v uv >/dev/null 2>&1; then
    log_info "Downloading standalone uv for user..."
    UV_URL="https://github.com/astral-sh/uv/releases/latest/download/uv-${UV_ARCH}.tar.gz"
    curl -fsSL "${UV_URL}" -o "${TEMP_DIR}/uv.tar.gz"
    tar -xzf "${TEMP_DIR}/uv.tar.gz" -C "${TEMP_DIR}"
    install -m 755 "${TEMP_DIR}/uv-${UV_ARCH}/uv" "${USER_BIN}/uv"
    install -m 755 "${TEMP_DIR}/uv-${UV_ARCH}/uvx" "${USER_BIN}/uvx"
    log_success "Installed uv to ${USER_BIN}/uv"
else
    log_info "uv already available at $(command -v uv)"
fi

# ------------------------------------------------------------------------------
# 2. Setup User Python Environment (~/.local/share/doc-token-tools-venv)
# ------------------------------------------------------------------------------
log_step "Step 2: Provisioning Python 3.12 Virtual Environment via uv"

USER_VENV="${HOME}/.local/share/doc-token-tools-venv"
TARGET_PYTHON="3.12"

log_info "Installing managed Python ${TARGET_PYTHON} runtime..."
uv python install "${TARGET_PYTHON}"

log_info "Creating virtual environment at ${USER_VENV}..."
uv venv "${USER_VENV}" --python "${TARGET_PYTHON}"

USER_PYTHON_PACKAGES=(
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

log_info "Installing Python document token tools into user environment..."
for pkg in "${USER_PYTHON_PACKAGES[@]}"; do
    log_info "Installing ${pkg}..."
    if uv pip install --python "${USER_VENV}/bin/python" "${pkg}"; then
        log_success "Successfully installed ${pkg}"
    else
        log_warn "Failed to install ${pkg}. Continuing..."
    fi
done

# Symlink CLI executables into ~/.local/bin
for bin_name in markitdown docling trafilatura fastmcp aider; do
    if [[ -f "${USER_VENV}/bin/${bin_name}" ]]; then
        ln -sf "${USER_VENV}/bin/${bin_name}" "${USER_BIN}/${bin_name}"
        log_success "Symlinked ${bin_name} -> ${USER_BIN}/${bin_name}"
    fi
done

# ------------------------------------------------------------------------------
# 3. User Node.js Packages (NPM prefix ~/.local)
# ------------------------------------------------------------------------------
log_step "Step 3: Installing Node.js packages to ~/.local"
if command -v npm >/dev/null 2>&1; then
    NPM_USER_PACKAGES=(
        repomix
        readdown
        @mozilla/readability
        turndown
        turndown-plugin-gfm
        jsdom
        linkedom
        pyright
        tree-sitter-cli
    )
    log_info "Installing NPM packages to user prefix: ${NPM_USER_PACKAGES[*]}"
    npm install -g --prefix "${HOME}/.local" "${NPM_USER_PACKAGES[@]}" || log_warn "NPM user install encountered warnings"
else
    log_warn "npm not found. Skipping user-level Node packages."
fi

# ------------------------------------------------------------------------------
# 4. User GitHub Standalone Binaries (toktoken)
# ------------------------------------------------------------------------------
log_step "Step 4: Installing Standalone Binaries"
if ! command -v toktoken >/dev/null 2>&1; then
    log_info "Downloading TokToken..."
    TOKTOKEN_URL="https://github.com/mauriziofonte/toktoken/releases/latest/download/toktoken-linux-${TOKTOKEN_ARCH}"
    if curl -fsSL -o "${TEMP_DIR}/toktoken" "${TOKTOKEN_URL}"; then
        install -m 755 "${TEMP_DIR}/toktoken" "${USER_BIN}/toktoken"
        log_success "Installed TokToken to ${USER_BIN}/toktoken"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Install Custom CLI Wrapper Scripts
# ------------------------------------------------------------------------------
log_step "Step 5: Deploying Custom Document CLI Helper Tools to ~/.local/bin"

install_user_wrapper() {
    local target_cmd="$1"
    local script_name="$2"
    local wrapper_path="${USER_BIN}/${target_cmd}"

    cat << EOF > "${wrapper_path}"
#!/usr/bin/env bash
exec "${USER_VENV}/bin/python" "${SCRIPT_DIR}/scripts/${script_name}" "\$@"
EOF
    chmod 755 "${wrapper_path}"
    log_success "Deployed CLI wrapper: ${wrapper_path} -> scripts/${script_name}"
}

install_user_wrapper "convert-doc" "convert_doc.py"
install_user_wrapper "patch-docx-xml" "patch_docx_xml.py"
install_user_wrapper "purify-web" "purify_web.py"
install_user_wrapper "doc-mcp-server" "doc_mcp_server.py"

# ------------------------------------------------------------------------------
# 6. Configure Shell Profile (~/.bashrc)
# ------------------------------------------------------------------------------
log_step "Step 6: Checking PATH configuration in ~/.bashrc"
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.bashrc" 2>/dev/null; then
    log_info "Adding ~/.local/bin and NODE_PATH to ~/.bashrc..."
    cat << 'EOF' >> "${HOME}/.bashrc"

# Document Token Optimization Tools
export PATH="$HOME/.local/bin:$PATH"
export NODE_PATH="$HOME/.local/lib/node_modules${NODE_PATH:+:$NODE_PATH}"
export TOKTOKEN_CACHE_DIR="$HOME/.cache/toktoken"
EOF
    log_success "Updated ~/.bashrc"
else
    log_info "PATH configuration already present in ~/.bashrc"
fi

echo -e "\n${GREEN}${BOLD}====================================================================${NC}"
echo -e "${GREEN}${BOLD} User Installation Complete!                                       ${NC}"
echo -e "${GREEN}${BOLD}====================================================================${NC}"
echo -e "Run ${BOLD}./verify-doc-tools.sh${NC} to verify your installation.\n"
