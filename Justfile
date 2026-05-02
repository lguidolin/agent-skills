# Agent Skills — Context Management Toolkit
# Import this from your project: import "/path/to/agent-skills/Justfile"

# Path to this repo (auto-detected from source file location)
_agent_skills_dir := source_directory()

# --- Profiles ---

# Activate brainstorm profile (ideation, specs, plans)
claude-brainstorm:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh brainstorm

# Activate design profile (UI/UX, mockups, browser)
claude-design:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh design

# Activate code profile (implementation, debug, test, commit)
claude-code:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh code

# Activate ship profile (push, PR, archive, cleanup)
claude-ship:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh ship

# Deactivate all — dormant state
claude-minimal:
    @{{_agent_skills_dir}}/scripts/profile-activate.sh minimal

# Show current profile and any overrides
claude-active-profile:
    @{{_agent_skills_dir}}/scripts/profile-lock.sh current

# --- Skills ---

# List all available skills with descriptions and profile associations
claude-list-skills:
    #!/usr/bin/env bash
    echo "Available skills:"
    echo ""
    for dir in "{{_agent_skills_dir}}"/.github/skills/*/; do
      [[ ! -d "$dir" ]] && continue
      skill=$(basename "$dir")
      desc=""
      if [[ -f "$dir/SKILL.md" ]]; then
        desc=$(grep -m1 '^description:' "$dir/SKILL.md" 2>/dev/null | sed 's/^description: *//' | head -c 80 || true)
      fi
      # Find which profiles include this skill
      profiles=""
      for pfile in "{{_agent_skills_dir}}"/profiles/*.yml; do
        pname=$(basename "$pfile" .yml)
        if yq -r '.skills // [] | .[]' "$pfile" 2>/dev/null | grep -qx "$skill"; then
          profiles+="$pname,"
        fi
      done
      profiles="${profiles%,}"
      printf "  %-40s [%s]\n" "$skill" "${profiles:-none}"
      if [[ -n "$desc" ]]; then
        printf "    %s\n" "$desc"
      fi
    done

# List currently active skills with descriptions
claude-list-active-skills:
    #!/usr/bin/env bash
    echo "Active skills:"
    echo ""
    found=0
    for link in .github/skills/*/; do
      [[ ! -d "$link" ]] && continue
      [[ ! -L "${link%/}" ]] && continue
      skill=$(basename "$link")
      desc=""
      if [[ -f "${link}SKILL.md" ]]; then
        desc=$(grep -m1 '^description:' "${link}SKILL.md" 2>/dev/null | sed 's/^description: *//' | head -c 80 || true)
      fi
      echo "  - $skill"
      if [[ -n "$desc" ]]; then
        echo "    $desc"
      fi
      found=$((found + 1))
    done
    if [[ $found -eq 0 ]]; then
      echo "  (none — run 'just claude-<profile>' to activate a profile)"
    fi

# Add a skill on top of current profile
claude-add-skill skill:
    @{{_agent_skills_dir}}/scripts/skill-add.sh {{skill}}

# Remove a skill from current profile
claude-rm-skill skill:
    @{{_agent_skills_dir}}/scripts/skill-rm.sh {{skill}}

# --- MCPs ---

# List all available MCPs with descriptions
claude-list-mcps:
    #!/usr/bin/env bash
    echo "Available MCPs:"
    echo ""
    for mcp_file in "{{_agent_skills_dir}}"/mcps-available/*.yml; do
      [[ ! -f "$mcp_file" ]] && continue
      name=$(yq -r '.name' "$mcp_file")
      desc=$(yq -r '.description' "$mcp_file")
      profiles=$(yq -r '.profiles // [] | join(", ")' "$mcp_file")
      printf "  %-20s [%s]\n" "$name" "$profiles"
      printf "    %s\n" "$desc"
    done

# List MCPs configured for this project
claude-list-active-mcps:
    #!/usr/bin/env bash
    echo "Active MCPs for this project:"
    echo ""
    if command -v claude &>/dev/null; then
      claude mcp list 2>/dev/null || echo "  (could not query claude mcp list)"
    else
      echo "  (claude CLI not found — showing config only)"
    fi
    echo ""
    if [[ -f ".claude-profiles.yml" ]]; then
      echo "Project config (.claude-profiles.yml):"
      yq -r '.mcps // [] | .[]' .claude-profiles.yml 2>/dev/null | sed 's/^/  - /'
    else
      echo "  No .claude-profiles.yml found. Run 'just claude-init' or 'just claude-add-mcp <name>'."
    fi

# Add an MCP to this project
claude-add-mcp mcp:
    #!/usr/bin/env bash
    mcp_file="{{_agent_skills_dir}}/mcps-available/{{mcp}}.yml"
    if [[ ! -f "$mcp_file" ]]; then
      echo "ERROR: MCP '{{mcp}}' not found." >&2
      echo "Available:" >&2
      ls "{{_agent_skills_dir}}"/mcps-available/*.yml 2>/dev/null | xargs -I{} basename {} .yml >&2
      exit 1
    fi
    # Add to .claude-profiles.yml
    if [[ ! -f ".claude-profiles.yml" ]]; then
      echo "mcps:" > .claude-profiles.yml
      echo "  - {{mcp}}" >> .claude-profiles.yml
    elif ! yq -r '.mcps // [] | .[]' .claude-profiles.yml 2>/dev/null | grep -qx "{{mcp}}"; then
      yq -i '.mcps += ["{{mcp}}"]' .claude-profiles.yml
    else
      echo "'{{mcp}}' already in .claude-profiles.yml"
      exit 0
    fi
    echo "✓ Added '{{mcp}}' to .claude-profiles.yml"
    # Install
    install_cmd=$(yq -r '.install' "$mcp_file")
    echo "Installing: $install_cmd"
    eval "$install_cmd"

# Remove an MCP from this project
claude-rm-mcp mcp:
    #!/usr/bin/env bash
    if [[ -f ".claude-profiles.yml" ]]; then
      yq -i 'del(.mcps[] | select(. == "{{mcp}}"))' .claude-profiles.yml 2>/dev/null
      echo "✓ Removed '{{mcp}}' from .claude-profiles.yml"
    else
      echo "No .claude-profiles.yml found."
    fi
    mcp_file="{{_agent_skills_dir}}/mcps-available/{{mcp}}.yml"
    if [[ -f "$mcp_file" ]]; then
      remove_cmd=$(yq -r '.remove // ""' "$mcp_file")
      if [[ -n "$remove_cmd" && "$remove_cmd" != "null" ]]; then
        echo "Removing: $remove_cmd"
        eval "$remove_cmd" || true
      fi
    fi

# --- LSPs ---

# List all available LSPs
claude-list-lsps:
    #!/usr/bin/env bash
    echo "Available LSPs:"
    echo ""
    for lsp_file in "{{_agent_skills_dir}}"/lsps/*.yml; do
      [[ ! -f "$lsp_file" ]] && continue
      name=$(yq -r '.name' "$lsp_file")
      desc=$(yq -r '.description' "$lsp_file")
      detect=$(yq -r '.detect // [] | join(", ")' "$lsp_file")
      printf "  %-20s %s\n" "$name" "$desc"
      printf "    Detected by: %s\n" "$detect"
    done

# Install an LSP server
claude-setup-lsp lsp:
    #!/usr/bin/env bash
    lsp_file="{{_agent_skills_dir}}/lsps/{{lsp}}.yml"
    if [[ ! -f "$lsp_file" ]]; then
      echo "ERROR: LSP '{{lsp}}' not found." >&2
      echo "Available:" >&2
      ls "{{_agent_skills_dir}}"/lsps/*.yml 2>/dev/null | xargs -I{} basename {} .yml >&2
      exit 1
    fi
    install_cmd=$(yq -r '.install' "$lsp_file")
    echo "Installing LSP: {{lsp}}"
    eval "$install_cmd"
    echo "✓ LSP '{{lsp}}' installed"

# --- Docs & Archive ---

# Identify unconverted specs/plans and generate conversion prompt
claude-update-archive:
    @{{_agent_skills_dir}}/scripts/doc-archive.sh

# Rebuild master decision index from decision records
claude-rebuild-index:
    @{{_agent_skills_dir}}/scripts/index-rebuild.sh

# --- Setup ---

# Interactive first-time project setup
claude-init:
    @{{_agent_skills_dir}}/scripts/claude-init.sh

# Show all available commands
claude-help:
    #!/usr/bin/env bash
    echo ""
    echo "Agent Skills — Context Management Toolkit"
    echo "=========================================="
    echo ""
    echo "PROFILES (activate a mode for your Claude session):"
    echo "  just claude-brainstorm      Ideation, specs, plans"
    echo "  just claude-design          UI/UX, mockups, browser testing"
    echo "  just claude-code            Implementation, debug, test, commit"
    echo "  just claude-ship            Push, PR, archive decisions, cleanup"
    echo "  just claude-minimal         Deactivate all (dormant state)"
    echo "  just claude-active-profile  Show current profile"
    echo ""
    echo "SKILLS (manage individual skills):"
    echo "  just claude-list-skills         All skills + profile associations"
    echo "  just claude-list-active-skills  Currently active skills"
    echo "  just claude-add-skill <name>    Add skill to current profile"
    echo "  just claude-rm-skill <name>     Remove skill from current profile"
    echo ""
    echo "MCPs (Model Context Protocol servers):"
    echo "  just claude-list-mcps           All available MCPs"
    echo "  just claude-list-active-mcps    MCPs configured for this project"
    echo "  just claude-add-mcp <name>      Add + install MCP"
    echo "  just claude-rm-mcp <name>       Remove MCP"
    echo ""
    echo "LSPs (Language Server Protocol):"
    echo "  just claude-list-lsps           All available LSPs"
    echo "  just claude-setup-lsp <name>    Install an LSP"
    echo ""
    echo "DOCS & ARCHIVE:"
    echo "  just claude-update-archive      Find unconverted specs, generate prompt"
    echo "  just claude-rebuild-index       Rebuild decision index"
    echo ""
    echo "SETUP:"
    echo "  just claude-init                First-time project setup"
    echo "  just claude-help                This help message"
    echo ""
