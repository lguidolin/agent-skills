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
    echo "  just test                    Run the test suite"
    echo "  scripts/install.sh --global  Install skills into ~/.claude/skills"
    echo ""
  '';
}
