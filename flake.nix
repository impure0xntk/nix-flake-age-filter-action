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
          act

          # Nix tools
          nix
          nixpkgs-fmt

          # Utilities
          shellcheck
          shfmt
          yq-go
        ];

        shellHook = ''
          echo "\u001b[1;34mnix-flake-age-filter-action\u001b[0m development shell"
          echo "  \u001b[1;3mnix flake check\u001b[0m       - run offline checks"
          echo "  \u001b[1;3mcd tests && ./run.sh\u001b[0m - run full test suite"
          echo "  \u001b[1;3mact\u001b[0m              - run the action locally"
        '';
      };

      checks = {
        # Offline static check — valid action.yml, fixtures present
        static-check = pkgs.runCommand "static-check" {
          nativeBuildInputs = with pkgs; [ bash yq-go nixpkgs-fmt ];
        } ''
          export TMPDIR="$(mktemp -d)"
          cp -r --no-preserve=mode "${toString ./action.yml}" "$TMPDIR/action.yml"
          cp -r --no-preserve=mode "${toString ./tests}" "$TMPDIR/tests"
          cd "$TMPDIR"

          echo "=== Check: action.yml is valid YAML ==="
          yq eval '.' action.yml > /dev/null

          echo "=== Check: action.yml has required inputs ==="
          yq eval '.inputs.min-age' action.yml | grep -q .
          yq eval '.inputs.dry-run' action.yml | grep -q .

          echo "=== Check: fixtures exist ==="
          for f in flake.nix flake.lock all_new.lock mixed_age.lock; do
            test -f "tests/fixtures/$f" || { echo "Missing fixture: $f"; exit 1; }
          done

          echo "=== Check: run.sh is valid bash ==="
          bash -n tests/run.sh

          echo "=== Check: flake.nix formatting ==="
          nixpkgs-fmt --check "${toString ./flake.nix}"

          touch "$out"
        '';
      };

      formatter = pkgs.nixpkgs-fmt;
    });
}
