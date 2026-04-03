#!/usr/bin/env bash
#
# AI-DLC Workflow Installer
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/habitfactory/aidlc-workflows/main/scripts/install.sh)"
#
# Options:
#   --platform <name>   Platform to configure (claude-code, cursor, cline, q-developer, kiro, copilot)
#   --no-codex          Skip Codex CLI installation (claude-code only)
#   --ref <ref>         Git ref to install from (default: main)
#   --repo <owner/repo> GitHub repository (default: habitfactory/aidlc-workflows)
#   --help              Show this help message
#
set -euo pipefail

# --- Configuration ---
REPO="${AIDLC_REPO:-habitfactory/aidlc-workflows}"
REF="${AIDLC_REF:-main}"
PLATFORM=""
NO_CODEX=false

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
warn()  { printf "${YELLOW}주의:${NC} %s\n" "$*"; }
error() { printf "${RED}오류:${NC} %s\n" "$*" >&2; }
die()   { error "$@"; exit 1; }

usage() {
  cat <<EOF
${BOLD}AI-DLC 워크플로우 설치 스크립트${NC}

코딩 에이전트에 AI-DLC 워크플로우 규칙을 설정합니다.

${BOLD}사용법:${NC}
  install.sh [옵션]

${BOLD}옵션:${NC}
  --platform <name>   설정할 플랫폼:
                         claude-code  - Claude Code (CLAUDE.md)
                         cursor       - Cursor IDE (.cursor/rules/)
                         cline        - Cline (.clinerules/)
                         q-developer  - Amazon Q Developer (.amazonq/rules/)
                         kiro         - Kiro (.kiro/steering/)
                         copilot      - GitHub Copilot (.github/copilot-instructions.md)
  --no-codex          Codex CLI 설치를 건너뜁니다 (claude-code 전용)
  --ref <ref>         설치할 Git ref (기본값: main)
  --repo <owner/repo> GitHub 저장소 (기본값: habitfactory/aidlc-workflows)
  --help              도움말 표시

${BOLD}사용 예시:${NC}
  # 대화형 플랫폼 선택:
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/${REPO}/${REF}/scripts/install.sh)"

  # 플랫폼 직접 지정:
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/${REPO}/${REF}/scripts/install.sh)" -- --platform claude-code

  # Codex 설치 없이 Claude Code만 설정:
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/${REPO}/${REF}/scripts/install.sh)" -- --platform claude-code --no-codex

  # 환경 변수로 저장소 지정:
  AIDLC_REPO=myorg/aidlc-workflows AIDLC_REF=v1.0.0 bash install.sh --platform cursor
EOF
  exit 0
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)  PLATFORM="$2"; shift 2 ;;
    --no-codex)  NO_CODEX=true; shift ;;
    --ref)       REF="$2"; shift 2 ;;
    --repo)      REPO="$2"; shift 2 ;;
    --help|-h)   usage ;;
    *)           die "알 수 없는 옵션: $1 (--help 로 사용법을 확인하세요)" ;;
  esac
done

# --- Check prerequisites ---
command -v curl >/dev/null 2>&1 || die "curl 이 설치되어 있지 않습니다."
command -v tar  >/dev/null 2>&1 || die "tar 가 설치되어 있지 않습니다."

# --- Platform selection ---
select_platform() {
  echo ""
  printf "${BOLD}코딩 플랫폼을 선택하세요:${NC}\n"
  echo ""
  echo "  1) Claude Code"
  echo "  2) Cursor IDE"
  echo "  3) Cline"
  echo "  4) Amazon Q Developer"
  echo "  5) Kiro"
  echo "  6) GitHub Copilot"
  echo ""
  printf "선택 [1-6]: "
  read -r choice
  case "$choice" in
    1) PLATFORM="claude-code" ;;
    2) PLATFORM="cursor" ;;
    3) PLATFORM="cline" ;;
    4) PLATFORM="q-developer" ;;
    5) PLATFORM="kiro" ;;
    6) PLATFORM="copilot" ;;
    *) die "잘못된 선택입니다: $choice" ;;
  esac
}

if [[ -z "$PLATFORM" ]]; then
  select_platform
fi

# Validate platform
case "$PLATFORM" in
  claude-code|cursor|cline|q-developer|kiro|copilot) ;;
  *) die "알 수 없는 플랫폼: $PLATFORM (--help 로 사용법을 확인하세요)" ;;
esac

info "${PLATFORM} 용 AI-DLC 워크플로우를 설치합니다..."

# --- Download and extract ---
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

TARBALL_URL="https://github.com/${REPO}/archive/${REF}.tar.gz"
info "${REPO}@${REF} 에서 다운로드 중..."

if ! curl -fsSL "$TARBALL_URL" | tar xz -C "$TMPDIR" 2>/dev/null; then
  die "${TARBALL_URL} 에서 다운로드에 실패했습니다. 저장소와 ref 가 존재하는지 확인하세요."
fi

# Find the extracted directory (GitHub names it <repo>-<ref>/)
EXTRACTED=$(find "$TMPDIR" -maxdepth 1 -type d -name "aidlc-workflows-*" | head -1)
if [[ -z "$EXTRACTED" ]]; then
  die "예상치 못한 아카이브 구조입니다. 압축 해제된 디렉토리를 찾을 수 없습니다."
fi

SRC_RULES="${EXTRACTED}/aidlc-rules/aws-aidlc-rules"
SRC_DETAILS="${EXTRACTED}/aidlc-rules/aws-aidlc-rule-details"

[[ -d "$SRC_RULES" ]]   || die "아카이브에서 규칙 디렉토리를 찾을 수 없습니다."
[[ -d "$SRC_DETAILS" ]] || die "아카이브에서 규칙 상세 디렉토리를 찾을 수 없습니다."

# --- Check for existing files ---
check_existing() {
  local target="$1"
  if [[ -e "$target" ]]; then
    warn "'${target}' 이(가) 이미 존재합니다."
    printf "  덮어쓰시겠습니까? [y/N]: "
    read -r answer
    case "$answer" in
      [yY]|[yY][eE][sS]) return 0 ;;
      *) info "${target} 건너뜀"; return 1 ;;
    esac
  fi
  return 0
}

# --- Platform-specific setup ---
setup_rule_details() {
  if check_existing ".aidlc-rule-details"; then
    mkdir -p .aidlc-rule-details
    cp -R "${SRC_DETAILS}/"* .aidlc-rule-details/
    ok "규칙 상세 파일을 .aidlc-rule-details/ 에 복사했습니다"
  fi
}

setup_codex() {
  echo ""
  info "Codex 리뷰 확장을 설정합니다..."

  # Step 1: Check Node.js
  if ! command -v node >/dev/null 2>&1; then
    warn "Codex CLI 에 Node.js 가 필요하지만 설치되어 있지 않습니다. Codex CLI 설치를 건너뜁니다."
    warn "Node.js 18.18+ 설치 후 다음 명령을 실행하세요: npm install -g @openai/codex"
  else
    NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
    if [[ "$NODE_VER" -lt 18 ]]; then
      warn "Codex CLI 에 Node.js 18.18+ 가 필요합니다 (현재: $(node -v)). Codex CLI 설치를 건너뜁니다."
    else
      # Step 2: Install Codex CLI
      if command -v codex >/dev/null 2>&1; then
        ok "Codex CLI 가 이미 설치되어 있습니다 ($(codex --version 2>/dev/null || echo '버전 불명'))"
      else
        info "Codex CLI 를 설치합니다..."
        if npm install -g @openai/codex 2>/dev/null; then
          ok "Codex CLI 설치 완료"
        else
          warn "Codex CLI 전역 설치에 실패했습니다. 다음을 시도하세요: sudo npm install -g @openai/codex"
        fi
      fi
    fi
  fi

  # Step 3: Print Claude Code plugin setup instructions
  echo ""
  printf "${YELLOW}────────────────────────────────────────────────────${NC}\n"
  printf "${BOLD}  Codex 플러그인 설정 (Claude Code 안에서 실행)${NC}\n"
  printf "${YELLOW}────────────────────────────────────────────────────${NC}\n"
  echo ""
  echo "  Claude Code 를 열고 아래 명령을 순서대로 실행하세요:"
  echo ""
  echo "    1. /plugin marketplace add openai/codex-plugin-cc"
  echo "    2. /plugin install codex@openai-codex"
  echo "    3. /reload-plugins"
  echo "    4. /codex:setup"
  echo ""
  echo "  Codex 로그인이 필요한 경우:"
  echo "    !codex login"
  echo ""
  printf "${YELLOW}────────────────────────────────────────────────────${NC}\n"
}

setup_claude_code() {
  if check_existing "CLAUDE.md"; then
    cp "${SRC_RULES}/core-workflow.md" ./CLAUDE.md
    ok "코어 워크플로우를 CLAUDE.md 에 복사했습니다"
  fi
  setup_rule_details

  if [[ "$NO_CODEX" != true ]]; then
    setup_codex
  fi

  echo ""
  ok "Claude Code 설정 완료!"
  echo ""
  echo "  확인: 'claude' 를 실행하고 \"현재 활성화된 지침이 무엇인가요?\" 라고 물어보세요"
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
    ok "${target} 생성 완료"
  fi
  setup_rule_details
  echo ""
  ok "Cursor IDE 설정 완료!"
  echo ""
  echo "  확인: Cursor 설정 > Rules 에서 'ai-dlc-workflow' 를 확인하세요"
}

setup_cline() {
  mkdir -p .clinerules
  local target=".clinerules/core-workflow.md"
  if check_existing "$target"; then
    cp "${SRC_RULES}/core-workflow.md" "$target"
    ok "코어 워크플로우를 ${target} 에 복사했습니다"
  fi
  setup_rule_details
  echo ""
  ok "Cline 설정 완료!"
  echo ""
  echo "  확인: Cline 채팅 입력란 아래의 Rules 팝오버를 확인하세요"
}

setup_q_developer() {
  mkdir -p .amazonq/rules
  if check_existing ".amazonq/rules/aws-aidlc-rules"; then
    cp -R "$SRC_RULES" .amazonq/rules/
    ok "규칙을 .amazonq/rules/aws-aidlc-rules/ 에 복사했습니다"
  fi
  if check_existing ".amazonq/aws-aidlc-rule-details"; then
    cp -R "$SRC_DETAILS" .amazonq/
    ok "규칙 상세를 .amazonq/aws-aidlc-rule-details/ 에 복사했습니다"
  fi
  echo ""
  ok "Amazon Q Developer 설정 완료!"
  echo ""
  echo "  확인: Q Chat 창에서 'Rules' 버튼을 클릭하세요"
}

setup_kiro() {
  mkdir -p .kiro/steering
  if check_existing ".kiro/steering/aws-aidlc-rules"; then
    cp -R "$SRC_RULES" .kiro/steering/
    ok "규칙을 .kiro/steering/aws-aidlc-rules/ 에 복사했습니다"
  fi
  if check_existing ".kiro/aws-aidlc-rule-details"; then
    cp -R "$SRC_DETAILS" .kiro/
    ok "규칙 상세를 .kiro/aws-aidlc-rule-details/ 에 복사했습니다"
  fi
  echo ""
  ok "Kiro 설정 완료!"
  echo ""
  echo "  확인: Kiro CLI 에서 '/context show' 를 실행하세요"
}

setup_copilot() {
  mkdir -p .github
  local target=".github/copilot-instructions.md"
  if check_existing "$target"; then
    cp "${SRC_RULES}/core-workflow.md" "$target"
    ok "코어 워크플로우를 ${target} 에 복사했습니다"
  fi
  setup_rule_details
  echo ""
  ok "GitHub Copilot 설정 완료!"
  echo ""
  echo "  확인: Copilot Chat > Configure Chat > Chat Instructions 에서 확인하세요"
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
info "\"Using AI-DLC, ...\" 로 시작하여 코딩을 시작하세요!"
echo ""
