# nix-flake-age-filter-action

A GitHub Action that uses [nix-flake-age-filter](https://github.com/impure0xntk/nix-flake-age-filter) to update Nix flake inputs older than a specified minimum age.

## Features

- **Min-age filtering**: Only updates flake inputs older than the specified number of days. Recent inputs are skipped.
- **Supply chain protection**: Same concept as npm's `min-release-age` — creates a cooling-off period that lets the community flag malicious releases before they reach your builds.
- **Scheduled & manual triggers**: Works with `schedule` events and `workflow_dispatch`.
- **Dry-run mode**: Preview what would change without modifying your `flake.lock`.
- **Auto PR creation**: Integrates with `peter-evans/create-pull-request` for automated updates.

## Usage

### Minimal

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: impure0xntk/nix-flake-age-filter-action@v1
    with:
      min-age: 30
```

### All options

```yaml
- uses: impure0xntk/nix-flake-age-filter-action@v1
  with:
    # Minimum age in days (required, default: 30)
    min-age: 30

    # Path to flake.lock (default: flake.lock)
    flake-lock: flake.lock

    # Dry-run mode (default: false)
    dry-run: "false"
```

### Scheduled update with auto PR

See [`examples/update-flake-inputs.yml`](examples/update-flake-inputs.yml) for a full workflow example.

```yaml
# .github/workflows/update-flake-inputs.yml
name: Weekly Nix Flake Input Update

on:
  schedule:
    - cron: "0 3 * * 1"  # Every Monday at 03:00 UTC
  workflow_dispatch:
    inputs:
      min-age:
        description: Minimum age in days
        required: true
        default: "30"

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: impure0xntk/nix-flake-age-filter-action@v1
        with:
          min-age: ${{ github.event_name == 'schedule' && '30' || inputs.min-age }}
      - uses: peter-evans/create-pull-request@v7
        with:
          commit-message: "chore: update flake inputs (min-age filter)"
          branch: chore/update-flake-inputs
          delete-branch: true
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `min-age` | ✅ | `30` | Minimum age in days for flake inputs |
| `flake-lock` | ❌ | `flake.lock` | Path to flake.lock |
| `dry-run` | ❌ | `false` | Dry-run mode (no changes) |

## Development

```bash
# Enter the Nix development shell
nix develop

# Validate the action
actionlint

# Check shell scripts
shellcheck *.sh
```

## Related projects

- [impure0xntk/nix-flake-age-filter](https://github.com/impure0xntk/nix-flake-age-filter) — The CLI tool used internally by this action

## License

MIT
