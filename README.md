# GHAR - GitHub Agent Routines

GHAR installs GitHub Actions workflows and OpenCode commands that help a repository triage issues, plan work, review changes, and keep PRs moving.

## Who It Is For

GHAR is for maintainers who want opinionated automation without wiring each workflow by hand.

## What It Installs

### Workflows

- Daily checks for stale PRs and issues
- Automatic investigation when a new issue is opened
- Issue comment command execution for maintainers
- New-issue command and agent listings
- Multi-agent TDD issue resolution
- End-to-end autonomous issue resolution pipelines
- A reusable OpenCode runner used by the other workflows

### OpenCode Commands

- Planning: requirements, architecture, risks, research
- Spec work: synthesis, red-teaming, finalization
- Implementation: seeding, coding, testing, fixing
- Review work: implementation review, maintainability review, security review, adversarial review
- Recovery work: CI repair, merge-conflict handling, final PR polish

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/tbrandenburg/ghar/main/Makefile.ghar | make -f - install

# Install from another source repo
curl -fsSL https://raw.githubusercontent.com/tbrandenburg/ghar/main/Makefile.ghar | make -f - install SOURCE_REPO=owner/repo

# Overwrite existing files
curl -fsSL https://raw.githubusercontent.com/tbrandenburg/ghar/main/Makefile.ghar | make -f - install-force
```

## Setup

1. Run the install command in the target repository.
2. Commit the generated `.github/` and `.opencode/` files.
3. Add `GH_PAT` if you want GHAR-created PRs to trigger downstream CI.

### Recommended `GH_PAT`

GitHub blocks `pull_request` events from PRs created with `GITHUB_TOKEN` (`github-actions[bot]`).

Create a fine-grained PAT with these repository permissions:

- `Contents: write`
- `Pull requests: write`

Add it as the `GH_PAT` repository secret. GHAR uses `secrets.GH_PAT || secrets.GITHUB_TOKEN`, so it still runs without the secret, but CI on GHAR-created PRs may not fire automatically.

## Commands

```bash
make -f Makefile.ghar install       # Install GHAR files
make -f Makefile.ghar install-dry   # Preview what would be installed
make -f Makefile.ghar install-force # Replace existing GHAR files
make -f Makefile.ghar validate      # Validate the installer
make -f Makefile.ghar info          # Show current configuration
make -f Makefile.ghar clean         # Remove installed files
make -f Makefile.ghar publish       # Bump the patch version and release
```

## Requirements

- `git`
- `make`
- `gh` (for publishing)
- `act` (optional, for local workflow testing)

## Local Testing

```bash
act workflow_dispatch -j stale-check -W .github/workflows/ghar-daily-routine.yml -s GITHUB_TOKEN="$(gh auth token)"
act workflow_dispatch -j security-check -W .github/workflows/ghar-daily-routine.yml -s GITHUB_TOKEN="$(gh auth token)"
act workflow_dispatch -W .github/workflows/ghar-daily-routine.yml -s GITHUB_TOKEN="$(gh auth token)"
```

## Release Notes

Installed repos record the version in `.ghar-version`.
