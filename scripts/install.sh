#!/usr/bin/env bash
#
# AI-DLC Workflow Installer
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/habitfactory/aidlc-workflows/main/scripts/install.sh)"
#
# Options:
#   --platform <name>   Platform to configure (claude-code, cursor, cline, q-developer, kiro, copilot)
#   --ref <ref>         Git ref to install from (default: main)
#   --repo <owner/repo> GitHub repository (default: habitfactory/aidlc-workflows)
#   --help              Show this help message
#
set -euo pipefail

# --- Configuration ---
REPO="${AIDLC_REPO:-habitfactory/aidlc-workflows}"
REF="${AIDLC_REF:-main}"
PLATFORM=""

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# --- Helper functions ---
info()  { printf "${BLUE}==>${NC} ${BOLD}%s${NC}\n" "$*"; }
ok()    { printf "${GREEN}==>${NC} ${BOLD}%s${NC}\n" "$*"; }
warn()  { printf "${YELLOW}Warning:${NC} %s\n" "$*"; }
error() { printf "${RED}Error:${NC} %s\n" "$*" >&2; }
die()   { error "$@"; exit 1; }

usage() {
  cat <<EOF
${BOLD}AI-DLC Workflow Installer${NC}

Sets up AI-DLC workflow rules for your coding agent.

${BOLD}Usage:${NC}
  install.sh [options]

${BOLD}Options:${NC}
  --platform <name>   Platform to configure:
                         claude-code  - Claude Code (CLAUDE.md)
                         cursor       - Cursor IDE (.cursor/rules/)
                         cline        - Cline (.clinerules/)
                         q-developer  - Amazon Q Developer (.amazonq/rules/)
                         kiro         - Kiro (.kiro/steering/)
                         copilot      - GitHub Copilot (.github/copilot-instructions.md)
  --ref <ref>         Git ref to install from (default: main)
  --repo <owner/repo> GitHub repository (default: habitfactory/aidlc-workflows)
  --help              Show this help message

${BOLD}Examples:${NC}
  # Interactive platform selection:
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/${REPO}/${REF}/scripts/install.sh)"

  # Direct platform specification:
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/${REPO}/${REF}/scripts/install.sh)" -- --platform claude-code

  # Environment variable overrides:
  AIDLC_REPO=myorg/aidlc-workflows AIDLC_REF=v1.0.0 bash install.sh --platform cursor
EOF
  exit 0
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --ref)      REF="$2"; shift 2 ;;
    --repo)     REPO="$2"; shift 2 ;;
    --help|-h)  usage ;;
    *)          die "Unknown option: $1. Use --help for usage." ;;
  esac
done

# --- Check prerequisites ---
command -v curl >/dev/null 2>&1 || die "curl is required but not installed."
command -v tar  >/dev/null 2>&1 || die "tar is required but not installed."

# --- Platform selection ---
select_platform() {
  echo ""
  printf "${BOLD}Select your coding platform:${NC}\n"
  echo ""
  echo "  1) Claude Code"
  echo "  2) Cursor IDE"
  echo "  3) Cline"
  echo "  4) Amazon Q Developer"
  echo "  5) Kiro"
  echo "  6) GitHub Copilot"
  echo ""
  printf "Enter choice [1-6]: "
  read -r choice
  case "$choice" in
    1) PLATFORM="claude-code" ;;
    2) PLATFORM="cursor" ;;
    3) PLATFORM="cline" ;;
    4) PLATFORM="q-developer" ;;
    5) PLATFORM="kiro" ;;
    6) PLATFORM="copilot" ;;
    *) die "Invalid choice: $choice" ;;
  esac
}

if [[ -z "$PLATFORM" ]]; then
  select_platform
fi

# Validate platform
case "$PLATFORM" in
  claude-code|cursor|cline|q-developer|kiro|copilot) ;;
  *) die "Unknown platform: $PLATFORM. Use --help for valid options." ;;
esac

info "Installing AI-DLC workflow for ${PLATFORM}..."

# --- Download and extract ---
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

TARBALL_URL="https://github.com/${REPO}/archive/${REF}.tar.gz"
info "Downloading from ${REPO}@${REF}..."

if ! curl -fsSL "$TARBALL_URL" | tar xz -C "$TMPDIR" 2>/dev/null; then
  die "Failed to download from ${TARBALL_URL}\nCheck that the repository and ref exist."
fi

# Find the extracted directory (GitHub names it <repo>-<ref>/)
EXTRACTED=$(find "$TMPDIR" -maxdepth 1 -type d -name "aidlc-workflows-*" | head -1)
if [[ -z "$EXTRACTED" ]]; then
  die "Unexpected archive structure. Could not find extracted directory."
fi

SRC_RULES="${EXTRACTED}/aidlc-rules/aws-aidlc-rules"
SRC_DETAILS="${EXTRACTED}/aidlc-rules/aws-aidlc-rule-details"

[[ -d "$SRC_RULES" ]]   || die "Source rules directory not found in archive."
[[ -d "$SRC_DETAILS" ]] || die "Source rule-details directory not found in archive."

# --- Check for existing files ---
check_existing() {
  local target="$1"
  if [[ -e "$target" ]]; then
    warn "'${target}' already exists."
    printf "  Overwrite? [y/N]: "
    read -r answer
    case "$answer" in
      [yY]|[yY][eE][sS]) return 0 ;;
      *) info "Skipping ${target}"; return 1 ;;
    esac
  fi
  return 0
}

# --- Platform-specific setup ---
setup_rule_details() {
  if check_existing ".aidlc-rule-details"; then
    mkdir -p .aidlc-rule-details
    cp -R "${SRC_DETAILS}/"* .aidlc-rule-details/
    ok "Copied rule details to .aidlc-rule-details/"
  fi
}

setup_claude_code() {
  if check_existing "CLAUDE.md"; then
    cp "${SRC_RULES}/core-workflow.md" ./CLAUDE.md
    ok "Copied core workflow to CLAUDE.md"
  fi
  setup_rule_details
  echo ""
  ok "Claude Code setup complete!"
  echo ""
  echo "  Verify: run 'claude' and ask \"What instructions are currently active?\""
}

setup_cursor() {
  mkdir -p .cursor/rules
  local target=".cursor/rules/ai-dlc-workflow.mdc"
  if check_existing "$target"; then
    cat > "$target" <<'FRONTMATTER'
---
description: "AI-DLC (AI-Driven Development Life Cycle) adaptive workflow for software development"
alwaysApply: true
---

FRONTMATTER
    cat "${SRC_RULES}/core-workflow.md" >> "$target"
    ok "Created ${target}"
  fi
  setup_rule_details
  echo ""
  ok "Cursor IDE setup complete!"
  echo ""
  echo "  Verify: Cursor Settings > Rules — look for 'ai-dlc-workflow'"
}

setup_cline() {
  mkdir -p .clinerules
  local target=".clinerules/core-workflow.md"
  if check_existing "$target"; then
    cp "${SRC_RULES}/core-workflow.md" "$target"
    ok "Copied core workflow to ${target}"
  fi
  setup_rule_details
  echo ""
  ok "Cline setup complete!"
  echo ""
  echo "  Verify: check the Rules popover under the Cline chat input"
}

setup_q_developer() {
  mkdir -p .amazonq/rules
  if check_existing ".amazonq/rules/aws-aidlc-rules"; then
    cp -R "$SRC_RULES" .amazonq/rules/
    ok "Copied rules to .amazonq/rules/aws-aidlc-rules/"
  fi
  if check_existing ".amazonq/aws-aidlc-rule-details"; then
    cp -R "$SRC_DETAILS" .amazonq/
    ok "Copied rule details to .amazonq/aws-aidlc-rule-details/"
  fi
  echo ""
  ok "Amazon Q Developer setup complete!"
  echo ""
  echo "  Verify: click 'Rules' button in the Q Chat window"
}

setup_kiro() {
  mkdir -p .kiro/steering
  if check_existing ".kiro/steering/aws-aidlc-rules"; then
    cp -R "$SRC_RULES" .kiro/steering/
    ok "Copied rules to .kiro/steering/aws-aidlc-rules/"
  fi
  if check_existing ".kiro/aws-aidlc-rule-details"; then
    cp -R "$SRC_DETAILS" .kiro/
    ok "Copied rule details to .kiro/aws-aidlc-rule-details/"
  fi
  echo ""
  ok "Kiro setup complete!"
  echo ""
  echo "  Verify: run '/context show' in Kiro CLI"
}

setup_copilot() {
  mkdir -p .github
  local target=".github/copilot-instructions.md"
  if check_existing "$target"; then
    cp "${SRC_RULES}/core-workflow.md" "$target"
    ok "Copied core workflow to ${target}"
  fi
  setup_rule_details
  echo ""
  ok "GitHub Copilot setup complete!"
  echo ""
  echo "  Verify: Copilot Chat > Configure Chat > Chat Instructions"
}

# --- Execute ---
case "$PLATFORM" in
  claude-code)  setup_claude_code ;;
  cursor)       setup_cursor ;;
  cline)        setup_cline ;;
  q-developer)  setup_q_developer ;;
  kiro)         setup_kiro ;;
  copilot)      setup_copilot ;;
esac

echo ""
info "Start coding with: \"Using AI-DLC, ...\""
echo ""
