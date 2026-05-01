#!/usr/bin/env bash
set -euo pipefail

# Interactive first-time project setup
# Usage: claude-init.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "🔧 Agent Skills — Project Setup"
echo ""

# Step 1: Check AGENT_SKILLS_DIR env var
if [[ -z "${AGENT_SKILLS_DIR:-}" ]]; then
  # The variable isn't in the environment (we computed it from script location)
  echo "Environment variable AGENT_SKILLS_DIR is not set in your shell."
  echo "Detected clone location: $AGENT_SKILLS_DIR"
  echo ""

  # Detect shell config file
  shell_config=""
  if [[ -f "$HOME/.zshrc" ]]; then
    shell_config="$HOME/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    shell_config="$HOME/.bashrc"
  elif [[ -f "$HOME/.profile" ]]; then
    shell_config="$HOME/.profile"
  fi

  if [[ -n "$shell_config" ]]; then
    read -rp "Add 'export AGENT_SKILLS_DIR=\"$AGENT_SKILLS_DIR\"' to $shell_config? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      echo "" >> "$shell_config"
      echo "# Agent Skills context management" >> "$shell_config"
      echo "export AGENT_SKILLS_DIR=\"$AGENT_SKILLS_DIR\"" >> "$shell_config"
      echo "✓ Added to $shell_config (restart shell or run: source $shell_config)"
    fi
  else
    echo "Could not detect shell config. Add manually:"
    echo "  export AGENT_SKILLS_DIR=\"$AGENT_SKILLS_DIR\""
  fi
fi

# Step 2: Check/create Justfile import
echo ""
if [[ -f "Justfile" ]]; then
  if grep -q "agent-skills\|AGENT_SKILLS_DIR" Justfile 2>/dev/null; then
    echo "✓ Justfile already imports agent-skills"
  else
    read -rp "Add agent-skills import to existing Justfile? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      # Prepend import
      tmp=$(mktemp)
      {
        echo "# Agent Skills context management"
        echo "import \"$AGENT_SKILLS_DIR/Justfile\""
        echo ""
        cat Justfile
      } > "$tmp"
      mv "$tmp" Justfile
      echo "✓ Import added to Justfile"
    fi
  fi
else
  read -rp "No Justfile found. Create one with agent-skills import? [Y/n] " answer
  if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
    cat > Justfile <<EOF
# Project Justfile

# Agent Skills context management
import "$AGENT_SKILLS_DIR/Justfile"
EOF
    echo "✓ Justfile created"
  fi
fi

# Step 3: Detect project language
echo ""
echo "Detecting project..."
languages=()
if [[ -f "package.json" ]] || [[ -f "tsconfig.json" ]]; then
  languages+=("typescript")
  echo "  Found: TypeScript/JavaScript project"
fi
if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
  languages+=("python")
  echo "  Found: Python project"
fi
if [[ -f "Cargo.toml" ]]; then
  languages+=("rust")
  echo "  Found: Rust project"
fi
if [[ -f "go.mod" ]]; then
  languages+=("go")
  echo "  Found: Go project"
fi
if [[ ${#languages[@]} -eq 0 ]]; then
  echo "  No specific language detected"
fi

# Step 4: Suggest MCPs
echo ""
echo "Suggested MCPs:"
suggested_mcps=("context7")
echo "  ✓ context7 (always recommended)"

for mcp_file in "$AGENT_SKILLS_DIR"/mcps/*.yml; do
  [[ ! -f "$mcp_file" ]] && continue
  mcp_name=$(yq -r '.name' "$mcp_file")
  [[ "$mcp_name" == "context7" ]] && continue

  mcp_desc=$(yq -r '.description' "$mcp_file")
  mcp_langs=$(yq -r '.languages // [] | .[]' "$mcp_file" 2>/dev/null || true)
  relevant=false

  if [[ -z "$mcp_langs" ]]; then
    relevant=true  # Universal MCP
  else
    for lang in "${languages[@]}"; do
      if echo "$mcp_langs" | grep -q "$lang"; then
        relevant=true
        break
      fi
    done
  fi

  if [[ "$relevant" == true ]]; then
    read -rp "  ? $mcp_name — $mcp_desc [y/N] " answer
    if [[ "${answer:-N}" =~ ^[Yy]$ ]]; then
      suggested_mcps+=("$mcp_name")
    fi
  fi
done

# Step 5: Create .claude-profiles.yml
echo ""
if [[ ${#suggested_mcps[@]} -gt 0 ]]; then
  {
    echo "mcps:"
    for mcp in "${suggested_mcps[@]}"; do
      echo "  - $mcp"
    done
  } > .claude-profiles.yml
  echo "✓ Created .claude-profiles.yml"
fi

# Step 6: Set up directories
mkdir -p .github/skills
echo "✓ Created .github/skills/ directory"

# Step 7: Create .claudeignore with markers
if [[ ! -f ".claudeignore" ]]; then
  echo "" | "$SCRIPT_DIR/claudeignore-sync.sh" -
  echo "✓ Created .claudeignore with managed section"
else
  # Ensure markers exist
  if ! grep -qF "agent-skills:managed:start" .claudeignore; then
    echo "" | "$SCRIPT_DIR/claudeignore-sync.sh" -
    echo "✓ Added managed section to existing .claudeignore"
  else
    echo "✓ .claudeignore already has managed section"
  fi
fi

# Step 8: Suggest LSPs
echo ""
for lang in "${languages[@]}"; do
  lsp_file="$AGENT_SKILLS_DIR/lsps/${lang}.yml"
  if [[ -f "$lsp_file" ]]; then
    desc=$(yq -r '.description' "$lsp_file")
    read -rp "Install LSP for $lang ($desc)? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      install_cmd=$(yq -r '.install' "$lsp_file")
      echo "  Installing: $install_cmd"
      eval "$install_cmd" 2>&1 || echo "  ⚠ Failed (install manually later)"
    fi
  fi
done

# Done
echo ""
echo "════════════════════════════════════════"
echo "✓ Setup complete!"
echo ""
echo "Start with:"
echo "  just claude-brainstorm    — for ideation"
echo "  just claude-code          — for implementation"
echo "  just claude-help          — see all commands"
echo ""
