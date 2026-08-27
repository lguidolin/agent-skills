#!/usr/bin/env bash
# scripts/install.sh — deploy the skills in skills/ for use by Claude Code.
#
#   --global          symlink every skill into ~/.claude/skills/
#                     (personal, all projects; tracks the repo on git pull)
#   --project <DIR>   copy skills into <DIR>/.claude/skills/
#                     (committed, shared with the team)
#
# Claude Code discovers skills in ~/.claude/skills/ and <project>/.claude/skills/.
# Only the frontmatter (name + description) of each SKILL.md is loaded up front;
# the body is read when the skill is actually invoked. Installing the whole set
# globally therefore costs very little context, which is why there is no
# per-project skill gating here.
#
# STACK_SPECIFIC skills are excluded from --project unless --all is given: a
# repo with no Kubernetes deploy should not carry the Azure guidance.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="${AGENT_SKILLS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
POOL="$AGENT_SKILLS_DIR/skills"

STACK_SPECIFIC=( cloud-delivery-aks postgres-postgraphile-rls-and-sql graphql-contract-testing )

MODE=""
PROJECT_DIR=""
INCLUDE_ALL=0

usage() {
  cat <<'USAGE'
Usage:
  install.sh --global
      Symlink every skill in skills/ into ~/.claude/skills/

  install.sh --project <DIR> [--all]
      Copy skills into <DIR>/.claude/skills/
      (excludes stack-specific skills unless --all is given)

Examples:
  install.sh --global
  install.sh --project ~/dev/active/rdv
  install.sh --project . --all
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)  MODE="global" ;;
    --project) MODE="project"; PROJECT_DIR="${2:?--project needs a directory}"; shift ;;
    --all)     INCLUDE_ALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown flag $1" >&2; usage; exit 1 ;;
  esac
  shift
done

[[ -n "$MODE" ]] || { echo "install.sh: pick --global or --project <DIR>" >&2; usage; exit 1; }
[[ -d "$POOL" ]] || { echo "install.sh: no skills/ directory at $POOL" >&2; exit 1; }

# Collect skills from the pool.
skills=()
for dir in "$POOL"/*/; do
  [[ -f "$dir/SKILL.md" ]] || continue
  skills+=("$(basename "$dir")")
done
[[ "${#skills[@]}" -gt 0 ]] || { echo "install.sh: pool is empty" >&2; exit 1; }

# An installed plugin owns the skills it ships. Installing a same-named skill
# would shadow one copy with the other, so refuse rather than pick a winner.
#
# This repo is itself installable as a plugin (.claude-plugin/), and its root
# skills/ directory is the conventional plugin skills path — so a user who
# installed it from the marketplace would see every skill reported as
# plugin-owned and be unable to run this script at all. Collisions coming from
# our own plugin are therefore not real conflicts: both copies are this repo.
# Skip them, and warn, since having both installed means duplicate skills.
SELF_PLUGIN="lguidolin-agent-skills"
if [[ -x "$SCRIPT_DIR/plugin-skills.sh" && "${ALLOW_PLUGIN_SKILL_COLLISION:-0}" != "1" ]]; then
  owned=$("$SCRIPT_DIR/plugin-skills.sh" --with-plugin 2>/dev/null | grep -v "^$SELF_PLUGIN"$'\t' || true)
  if "$SCRIPT_DIR/plugin-skills.sh" --with-plugin 2>/dev/null | grep -q "^$SELF_PLUGIN"$'\t'; then
    echo "NOTE: '$SELF_PLUGIN' is also installed as a plugin, which ships these same skills." >&2
    echo "      Pick one install path — plugin or this script — or you will carry duplicates." >&2
  fi
  if [[ -n "$owned" ]]; then
    collisions=0
    for skill in "${skills[@]}"; do
      owner=$(awk -F'\t' -v s="$skill" '$2 == s { print $1; exit }' <<<"$owned")
      if [[ -n "$owner" ]]; then
        echo "ERROR: skill '$skill' is already shipped by the installed plugin '$owner'." >&2
        collisions=$((collisions + 1))
      fi
    done
    if [[ "$collisions" -gt 0 ]]; then
      echo "" >&2
      echo "The plugin is the source of truth for its own skills. Remove or rename the" >&2
      echo "local copy. Override (not recommended): ALLOW_PLUGIN_SKILL_COLLISION=1" >&2
      exit 1
    fi
  fi
fi

is_stack_specific() {
  local s="$1"
  for ex in "${STACK_SPECIFIC[@]}"; do [[ "$s" == "$ex" ]] && return 0; done
  return 1
}

install_global() {
  local dest="$HOME/.claude/skills"
  mkdir -p "$dest"
  echo "[install] symlinking ${#skills[@]} skill(s) into $dest"
  local n=0 replaced=0
  for skill in "${skills[@]}"; do
    # A previous install may have left a real directory here; replace it with a
    # symlink so the skill tracks the repo instead of silently going stale.
    if [[ -d "$dest/$skill" && ! -L "$dest/$skill" ]]; then
      rm -rf "${dest:?}/$skill"
      replaced=$((replaced + 1))
    fi
    ln -sfn "$POOL/$skill" "$dest/$skill"
    n=$((n + 1))
  done
  # A skill renamed or removed upstream leaves its old symlink behind, pointing
  # at a path that no longer exists. Claude Code would list a skill it cannot
  # load, so prune links that resolve into this pool but no longer have a skill.
  local pruned=0
  for link in "$dest"/*; do
    [[ -L "$link" ]] || continue
    target="$(readlink "$link")"
    [[ "$target" == "$POOL/"* ]] || continue   # not ours; leave alone
    [[ -f "$target/SKILL.md" ]] && continue    # still valid
    rm -f "$link"
    echo "  pruned $(basename "$link") (no longer in the pool)"
    pruned=$((pruned + 1))
  done

  echo "  linked $n skill(s)${replaced:+, replaced $replaced stale copy/copies}${pruned:+, pruned $pruned stale link(s)}."
  echo "  They update automatically when you 'git pull' this repo."
}

install_project() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo "install.sh: no such directory: $dir" >&2; exit 1; }
  local dest
  dest="$(cd "$dir" && pwd)/.claude/skills"
  mkdir -p "$dest"
  echo "[install] copying skills into $dest"
  local n=0 skipped=0
  for skill in "${skills[@]}"; do
    if [[ "$INCLUDE_ALL" -eq 0 ]] && is_stack_specific "$skill"; then
      echo "  skip $skill (stack-specific; use --all to include)"
      skipped=$((skipped + 1))
      continue
    fi
    rm -rf "${dest:?}/$skill"
    cp -R "$POOL/$skill" "$dest/$skill"
    n=$((n + 1))
  done
  echo "  copied $n skill(s), skipped $skipped. Commit $dest to share with the team."
}

case "$MODE" in
  global)  install_global ;;
  project) install_project "$PROJECT_DIR" ;;
esac
