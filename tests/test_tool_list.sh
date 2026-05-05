#!/usr/bin/env bash
# tests/test_tool_list.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/assert.sh"
source "$REPO_ROOT/tests/lib/fixture.sh"

setup_fixture
trap teardown_fixture EXIT

REG="$AGENT_SKILLS_DIR/registry.yml"
LIB="$AGENT_SKILLS_DIR/scripts/registry.sh"
TOOL_LIST="$AGENT_SKILLS_DIR/scripts/tool-list.sh"

# Populate the registry
"$LIB" init

# skill-a: active in /work/proj-a, in profile "code"
"$LIB" add skill-a type=skill source=/tmp/skill-a
"$LIB" set-profiles skill-a code
"$LIB" add-active skill-a /work/proj-a

# skill-b: no active_in, in profile "brainstorm"
"$LIB" add skill-b type=skill source=/tmp/skill-b
"$LIB" set-profiles skill-b brainstorm

# agent-x: no active_in, no profiles
"$LIB" add agent-x type=agent source=/tmp/agent-x

# browser: type=mcp, in profile "design"
"$LIB" add browser type=mcp source=/tmp/browser
"$LIB" set-profiles browser design

# --- 1. Default output: section headers present
out=$("$TOOL_LIST")
echo "$out" | grep -Fq 'SKILLS'  && _pass || _fail "default output missing SKILLS section"
echo "$out" | grep -Fq 'AGENTS'  && _pass || _fail "default output missing AGENTS section"
echo "$out" | grep -Fq 'MCPS'    && _pass || _fail "default output missing MCPS section"

# --- 2. skill-a marked active (●), skill-b inactive (○)
echo "$out" | grep -F 'skill-a' | grep -Fq '●' && _pass || _fail "skill-a should be marked ● (active)"
echo "$out" | grep -F 'skill-b' | grep -Fq '○' && _pass || _fail "skill-b should be marked ○ (inactive)"

# --- 3. --type=skill excludes browser (mcp)
out_skill=$("$TOOL_LIST" --type=skill)
echo "$out_skill" | grep -Fq 'skill-a'  && _pass || _fail "--type=skill should show skill-a"
echo "$out_skill" | grep -Fq 'browser'  && { _fail "--type=skill should not show browser (mcp)"; } || _pass

# --- 4. --profile=design shows browser, excludes skill-b
out_design=$("$TOOL_LIST" --profile=design)
echo "$out_design" | grep -Fq 'browser'  && _pass || _fail "--profile=design should show browser"
echo "$out_design" | grep -Fq 'skill-b'  && { _fail "--profile=design should not show skill-b"; } || _pass

# --- 5. --project=/work/proj-a shows skill-a, excludes skill-b
out_proj=$("$TOOL_LIST" --project=/work/proj-a)
echo "$out_proj" | grep -Fq 'skill-a'  && _pass || _fail "--project=/work/proj-a should show skill-a"
echo "$out_proj" | grep -Fq 'skill-b'  && { _fail "--project=/work/proj-a should not show skill-b"; } || _pass

report_results
