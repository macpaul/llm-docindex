#!/usr/bin/env bash
# ==============================================================================
# install-skills.sh
# Link AI Coding CLI Skills to Workspace and Global Antigravity / Claude Code Scopes
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/skills"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Target Directories
WORKSPACE_SKILLS_DIR="${SCRIPT_DIR}/.agents/skills"
GLOBAL_AGENTS_SKILLS="${HOME}/.agents/skills"
GLOBAL_GEMINI_SKILLS="${HOME}/.gemini/config/skills"

mkdir -p "${WORKSPACE_SKILLS_DIR}"
mkdir -p "${GLOBAL_AGENTS_SKILLS}"
mkdir -p "${GLOBAL_GEMINI_SKILLS}"

log_info "Discovering skills in ${SKILLS_DIR}..."

SKILL_COUNT=0
for skill_path in "${SKILLS_DIR}"/*; do
    if [[ -d "${skill_path}" && -f "${skill_path}/SKILL.md" ]]; then
        skill_name="$(basename "${skill_path}")"
        ((SKILL_COUNT++))

        # 1. Workspace scope (.agents/skills/<skill>) -> relative link
        ln -sf "../../skills/${skill_name}" "${WORKSPACE_SKILLS_DIR}/${skill_name}"
        log_success "Linked workspace skill: .agents/skills/${skill_name}"

        # 2. Global user scope (~/.agents/skills/<skill>)
        ln -sf "${skill_path}" "${GLOBAL_AGENTS_SKILLS}/${skill_name}"

        # 3. Antigravity Global scope (~/.gemini/config/skills/<skill>)
        ln -sf "${skill_path}" "${GLOBAL_GEMINI_SKILLS}/${skill_name}"
        log_success "Linked global skill: ~/.gemini/config/skills/${skill_name}"
    fi
done

echo -e "\n${GREEN}${BOLD}====================================================================${NC}"
echo -e "${GREEN}${BOLD} Successfully linked ${SKILL_COUNT} AI Coding Skills!               ${NC}"
echo -e "${GREEN}${BOLD}====================================================================${NC}"
echo -e "Skills are now available in:"
echo -e "  - Workspace Scope: ${BOLD}${WORKSPACE_SKILLS_DIR}${NC}"
echo -e "  - Global Scope:    ${BOLD}${GLOBAL_GEMINI_SKILLS}${NC}\n"
