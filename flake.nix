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
            act
            actionlint
            yamllint
            nixpkgs-fmt
            shellcheck
            yq-go
          ];
          shellHook = ''
            echo -e "\033[1;34mnix-flake-age-filter-action\033[0m"
          '';
        };

        checks.static-check = pkgs.runCommand "static-check" {
          buildInputs = [ pkgs.yq-go ];
        } ''
          export TMPDIR="$(mktemp -d)"
          yq eval '.' ${self}/action.yml > /dev/null
          touch $out
        '';
      }
    );
}
