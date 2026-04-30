{
  description = "GitHub Action to update Nix flake inputs with min-age filtering";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "nix-flake-age-filter-action-dev";

          buildInputs = with pkgs; [
            # Action development & testing
            actionlint

            # Nix tools
            nix
            nixpkgs-fmt

            # Shell utilities
            shellcheck
            shfmt
          ];

          shellHook = ''
            echo "
              ╔══════════════════════════════════════════════╗
              ║  nix-flake-age-filter-action  dev shell     ║
              ╠══════════════════════════════════════════════╣
              ║  Tools: actionlint, shellcheck, shfmt       ║
              ║  Usage: actionlint                          ║
              ╚══════════════════════════════════════════════╝
            "
          '';
        };

        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
