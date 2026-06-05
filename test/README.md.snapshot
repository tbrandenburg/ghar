# GHAR - Github Agent Routines

Agent routines in Github workflows

## ⚡ Quick Install

```bash
# One-liner installation
curl -fsSL https://raw.githubusercontent.com/tbrandenburg/ghar/main/Makefile.ghar | make -f - install

# One-liner force installation
curl -fsSL https://raw.githubusercontent.com/tbrandenburg/ghar/main/Makefile.ghar | make -f - install-force

# Commit and push the changes
git add .github .opencode && git commit -m "feat: Add GHAR auto-routine"
git push
```

## 🎯 Current Features

- **Daily automated checks** for stale PRs and issues (>3 days old)
- **Auto issue investigation** - automatically investigates and posts implementation plan when new issues are opened
- **Smart filtering** - ignores drafts, WIP labels, long-term items
- **One-time notifications** - won't spam the same item
- **OpenCode integration** - trigger checks via `opencode run --command ghar-stale-check` or `opencode run --command ghar-issue-investigate`

## 📋 Commands

```bash
make -f Makefile.ghar install    # Install GHAR system
make -f Makefile.ghar validate   # Validate installation
make -f Makefile.ghar info       # Show configuration
make -f Makefile.ghar clean      # Remove installed files
```

## 🧪 Local Testing

Test workflows locally with [act](https://github.com/nektos/act):

```bash
# Run stale check
act workflow_dispatch -j stale-check -W .github/workflows/ghar-daily-routine.yml -s GITHUB_TOKEN="$(gh auth token)"

# Run security check  
act workflow_dispatch -j security-check -W .github/workflows/ghar-daily-routine.yml -s GITHUB_TOKEN="$(gh auth token)"

# Run full daily routine
act workflow_dispatch -W .github/workflows/ghar-daily-routine.yml -s GITHUB_TOKEN="$(gh auth token)"
```

## 🔧 Requirements

- `git` and `gh` (GitHub CLI)
- `make` (pre-installed on most systems)
- `act` (optional, for local testing)
