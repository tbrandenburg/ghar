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

## ⚠️ Required: Add a `GH_PAT` Secret for CI Tests

GitHub **blocks `pull_request` events** on PRs created by `GITHUB_TOKEN`
(`github-actions[bot]`). This is an intentional platform-level security rule, not
a repo setting. Without a PAT, GHAR-created PRs will never trigger your test
workflows automatically.

**After installing GHAR, add a repository secret named `GH_PAT`:**

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Create a token scoped to your repo with permissions:
   - **Repository permissions → Contents: Read and write**
   - **Repository permissions → Pull requests: Read and write**
3. Go to **your repo → Settings → Secrets and variables → Actions → New repository secret**
4. Name it exactly `GH_PAT` and paste the token value

GHAR picks up `GH_PAT` automatically (`${{ secrets.GH_PAT || secrets.GITHUB_TOKEN }}`).
No workflow edits needed — it falls back to `GITHUB_TOKEN` silently if the secret is absent.

> Without `GH_PAT`, you can still trigger CI manually by pushing any commit to the
> agent branch or by closing and reopening the PR.

## 🎯 Current Features

- **Daily automated checks** for stale PRs and issues (>3 days old)
- **Auto issue investigation** - automatically investigates and posts implementation plan when new issues are opened
- **Issue workflow** - seeds a draft PR early, runs parallel review and CI evidence stages, then consolidates findings before final handoff
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
