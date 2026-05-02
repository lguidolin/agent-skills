{
  pkgs ? import <nixpkgs> { config.allowUnfree = true; },
  unstable ? import <nixpkgs-unstable> { config.allowUnfree = true; }
}:

pkgs.mkShell {
  name = "agent-skills";

  buildInputs = with pkgs; [
    # Node.js 20 LTS + pnpm (matches Dockerfiles and CI)
    nodejs_20
    nodePackages.pnpm

    just
    git
    gh

    # yq-go is Mike Farah's Go implementation (v4). Pin via nix so all projects
    # share the same flavor — the Python kislyuk yq has a different DSL.
    yq-go
    jq
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.zlib}/lib:$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH="${pkgs.postgresql_16.lib}/lib:$LD_LIBRARY_PATH"

    if [ -f ~/.bash_profile ]; then
      source ~/.bash_profile
    fi

    echo ""
    echo "---------------------------------------------------------"
    echo "  agent-skills shell"
    echo "---------------------------------------------------------"
    echo ""
    echo "  Node.js:  $(node --version)"
    echo "  pnpm:     $(pnpm --version)"
    echo "  yq:       $(yq --version)"
    echo "  jq:       $(jq --version)"
    echo ""
    echo "  pnpm install        Install dependencies"
    echo "  docker compose up   Start all services"
    echo ""
  '';
}
