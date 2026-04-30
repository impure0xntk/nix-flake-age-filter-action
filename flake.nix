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
        };

        checks = {
          test-action-check = pkgs.runCommand "test-action-check"
            {
              buildInputs = [ pkgs.yq-go ];
            }
            ''
              yq eval '.' ${self}/action.yml > /dev/null
              touch $out
            '';

          test-action-workflow-check = pkgs.runCommand "test-action-workflow-check"
            {
              buildInputs = [ pkgs.yq-go pkgs.actionlint ];
            }
            ''
              yq eval '.' ${self}/tests/test-action.yml > /dev/null
              actionlint ${self}/tests/test-action.yml
              touch $out
            '';

          test-action-syntax-check = pkgs.runCommand "test-action-syntax-check"
            {
              buildInputs = [ pkgs.yq-go ];
            }
            ''
              yq eval '.jobs.*.steps[] | select(.uses == "./") | .uses' ${self}/tests/test-action.yml > /dev/null
              touch $out
            '';
        };
      });
}
