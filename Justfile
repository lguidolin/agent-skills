# Agent Skills — house skills for Claude Code
# Import this from your project: import "/path/to/agent-skills/Justfile"

# Path to this repo (auto-detected from source file location)
_agent_skills_dir := source_directory()

# --- Install ---

# Symlink every skill into ~/.claude/skills (personal, all projects)
claude-install-global:
    @{{_agent_skills_dir}}/scripts/install.sh --global

# Copy skills into this project's .claude/skills (committed, team-shared)
claude-install-project:
    @{{_agent_skills_dir}}/scripts/install.sh --project .

# Copy skills into this project, including stack-specific ones
claude-install-project-all:
    @{{_agent_skills_dir}}/scripts/install.sh --project . --all

# --- Skills ---

# List the skills in the pool with their trigger descriptions
claude-list-skills:
    #!/usr/bin/env bash
    echo "Skills in the pool:"
    echo ""
    for dir in "{{_agent_skills_dir}}"/skills/*/; do
      [ -f "$dir/SKILL.md" ] || continue
      name=$(basename "$dir")
      desc=$(grep -m1 '^description:' "$dir/SKILL.md" | sed 's/^description:[[:space:]]*//; s/^"//; s/"$//')
      printf '  \033[1m%s\033[0m\n      %s\n\n' "$name" "$desc"
    done

# Show which skill names installed plugins already own (do not reuse these)
claude-plugin-skills:
    @{{_agent_skills_dir}}/scripts/plugin-skills.sh --with-plugin

# --- Docs & Archive ---

# Identify unconverted specs/plans and generate conversion prompt
claude-update-archive:
    @{{_agent_skills_dir}}/scripts/doc-archive.sh

# Rebuild master decision index from decision records
claude-rebuild-index:
    @{{_agent_skills_dir}}/scripts/index-rebuild.sh

# --- Tests ---

# Run the test suite (skill lint + install)
test:
    @{{_agent_skills_dir}}/tests/run.sh

# --- Help ---

# Show available commands
claude-help:
    @just --justfile {{_agent_skills_dir}}/Justfile --list
