# GHAR - Github Agent Routines

Agent routines in Github workflows

## ⚡ Quick Install

```bash
# One-liner installation
curl -fsSL https://raw.githubusercontent.com/tbrandenburg/ghar/main/Makefile.ghar | make -f - install

# Commit and push the changes
git add .github .opencode && git commit -m "feat: Add GHAR auto-routine"
git push
```

## 🎯 Current Features

- **Daily automated checks** for stale PRs and issues (>3 days old)
- **Smart filtering** - ignores drafts, WIP labels, long-term items
- **One-time notifications** - won't spam the same item
- **OpenCode integration** - trigger checks via `opencode run --command ghar-stale-check`

## 📋 Commands

```bash
make -f Makefile.ghar install    # Install GHAR system
make -f Makefile.ghar validate   # Validate installation
make -f Makefile.ghar info       # Show configuration
make -f Makefile.ghar clean      # Remove installed files
```

## 🔧 Requirements

- `git` and `gh` (GitHub CLI)
- `make` (pre-installed on most systems)
