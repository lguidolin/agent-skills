#!/usr/bin/env bash
# scripts/constitution-install.sh — deploy the engineering-constitution skills
#
# The 16 constitution skills live in skills-available/. This script deploys them
# for use, two ways:
#   --global         symlink ALL 16 into ~/.claude/skills/ (your personal, all-projects use)
#   --project DIR    copy the portable set into DIR/.claude/skills/ (committed, team-shared)
#
# By default --project copies the 15 stack-portable skills and EXCLUDES
# cloud-delivery-aks (a project with no Kubernetes deploy should not even carry
# the Azure guidance). Use --all to include it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
POOL="$AGENT_SKILLS_DIR/skills-available"

# The 16 constitution skills (the pool also contains unrelated skills; we deploy only these).
CONSTITUTION_SKILLS=(
  engineering-constitution
  designing-before-building
  recording-decisions
  conventional-commits-and-releases
  tests-as-a-control
  change-hygiene-and-code-craft
  interface-craft-and-accessibility
  verification-gate-and-automation
  observability-and-slos
  defense-in-depth-security
  performance-and-scale
  resilience-and-deploy-safety
  postgres-postgraphile-rls-and-sql
  graphql-contract-testing
  zero-downtime-migrations
  cloud-delivery-aks
)
# Skills excluded from --project unless --all (stack-specific to cloud deploys).
PROJECT_EXCLUDE=( cloud-delivery-aks )

MODE=""
PROJECT_DIR=""
INCLUDE_ALL=0

usage() {
  cat <<'EOF'
Usage:
  constitution-install.sh --global
      Symlink all 16 constitution skills into ~/.claude/skills/

  constitution-install.sh --project <DIR> [--all]
      Copy the portable constitution skills into <DIR>/.claude/skills/
      (excludes cloud-delivery-aks unless --all is given)

Examples:
  constitution-install.sh --global
  constitution-install.sh --project ~/dev/active/rdv
  constitution-install.sh --project . --all
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)  MODE="global" ;;
    --project) MODE="project"; PROJECT_DIR="${2:?--project needs a directory}"; shift ;;
    --all)     INCLUDE_ALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "constitution-install: unknown flag $1" >&2; usage; exit 1 ;;
  esac
  shift
done

[[ -n "$MODE" ]] || { echo "constitution-install: pick --global or --project <DIR>" >&2; usage; exit 1; }

# Verify the pool has the skills before doing anything.
missing=0
for skill in "${CONSTITUTION_SKILLS[@]}"; do
  if [[ ! -f "$POOL/$skill/SKILL.md" ]]; then
    echo "  MISSING from pool: $skill" >&2
    missing=1
  fi
done
[[ "$missing" -eq 0 ]] || { echo "constitution-install: pool is incomplete, aborting." >&2; exit 1; }

install_global() {
  local dest="$HOME/.claude/skills"
  mkdir -p "$dest"
  echo "[constitution] symlinking 16 skills into $dest"
  local n=0
  for skill in "${CONSTITUTION_SKILLS[@]}"; do
    ln -sfn "$POOL/$skill" "$dest/$skill"   # -n: don't dereference an existing dir-symlink
    n=$((n + 1))
  done
  echo "  linked $n skill(s). (Updates automatically on 'git pull' of the pool.)"
}

is_excluded() {
  local s="$1"
  for ex in "${PROJECT_EXCLUDE[@]}"; do [[ "$s" == "$ex" ]] && return 0; done
  return 1
}

install_project() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo "constitution-install: no such directory: $dir" >&2; exit 1; }
  local dest
  dest="$(cd "$dir" && pwd)/.claude/skills"
  mkdir -p "$dest"
  echo "[constitution] copying skills into $dest"
  local n=0 skipped=0
  for skill in "${CONSTITUTION_SKILLS[@]}"; do
    if [[ "$INCLUDE_ALL" -eq 0 ]] && is_excluded "$skill"; then
      echo "  skip $skill (excluded; use --all to include)"
      skipped=$((skipped + 1))
      continue
    fi
    rm -rf "$dest/$skill"
    cp -R "$POOL/$skill" "$dest/$skill"
    n=$((n + 1))
  done
  echo "  copied $n skill(s), skipped $skipped. Commit $dest to share with the team."
}

case "$MODE" in
  global)  install_global ;;
  project) install_project "$PROJECT_DIR" ;;
esac

echo "[constitution] done."
