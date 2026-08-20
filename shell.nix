{
  pkgs ? import <nixpkgs> { config.allowUnfree = true; },
  unstable ? import <nixpkgs-unstable> { config.allowUnfree = true; }
}:

pkgs.mkShell {
  name = "agent-skills";

  buildInputs = with pkgs; [
    just
    git
    gh

    # yq-go is Mike Farah's Go implementation (v4) — used by index-rebuild.sh.
    # The Python kislyuk yq has a different DSL, so pin the flavor here.
    yq-go
  ];

  shellHook = ''
    if [ -f ~/.bash_profile ]; then
      source ~/.bash_profile
    fi

    echo ""
    echo "---------------------------------------------------------"
    echo "  agent-skills shell"
    echo "---------------------------------------------------------"
    echo ""
    echo "  yq:   $(yq --version)"
    echo ""
    echo "  just test                    Run the test suite"
    echo "  scripts/install.sh --global  Install skills into ~/.claude/skills"
    echo ""
  '';
}
