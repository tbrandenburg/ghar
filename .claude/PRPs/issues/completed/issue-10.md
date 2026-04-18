# Investigation: ci: upgrade GitHub Actions to Node.js 24 compatible versions

**Issue**: #10 (https://github.com/tbrandenburg/ghar/issues/10)
**Type**: CHORE
**Investigated**: 2026-04-18T13:00:00Z

### Assessment

| Metric     | Value  | Reasoning                                                                                         |
| ---------- | ------ | ------------------------------------------------------------------------------------------------- |
| Priority   | HIGH   | Node.js 20 removed from runners September 16, 2026; workflows will break without upgrade          |
| Complexity | LOW    | Only action version bumps in 3 YAML files; no logic changes required                             |
| Confidence | HIGH   | All target versions confirmed via GitHub API; exact lines identified in codebase                  |

---

## Problem Statement

Five action usages across three workflow files use Node.js 20 runtime, which is deprecated and will be removed on September 16, 2026. Starting June 2, 2026, Node.js 24 becomes the default. Latest versions of all affected actions support Node.js 24 and are available now.

---

## Analysis

### Change Rationale

Bump each action to the latest major version that uses Node.js 24 runtime. No logic or behavior changes are needed — these are pure version upgrades.

### Evidence Chain

WHY: Workflows will fail after September 16, 2026
↓ BECAUSE: actions run on Node.js 20 which is being removed
Evidence:
- `.github/workflows/ghar-issue-commands-list.yml:53` - `actions/github-script@v7`
- `.github/workflows/ghar-issue-command-executor.yml:30,143` - `actions/github-script@v7`
- `.github/workflows/core-opencode-run.yml:73` - `astral-sh/setup-uv@v5`
- `.github/workflows/core-opencode-run.yml:193` - `actions/upload-artifact@v4`

↓ ROOT CAUSE: Action versions pinned to old Node.js 20 based releases

**Latest versions confirmed via GitHub API:**
- `actions/github-script`: latest is `v9.0.0` (upgrade from v7)
- `actions/upload-artifact`: latest is `v7.0.1` (upgrade from v4)
- `astral-sh/setup-uv`: latest is `v8.1.0` (upgrade from v5)

### Affected Files

| File                                              | Lines   | Action | Description                                          |
| ------------------------------------------------- | ------- | ------ | ---------------------------------------------------- |
| `.github/workflows/ghar-issue-commands-list.yml`  | 53      | UPDATE | Upgrade actions/github-script@v7 → @v9               |
| `.github/workflows/ghar-issue-command-executor.yml` | 30, 143 | UPDATE | Upgrade actions/github-script@v7 → @v9 (2 instances) |
| `.github/workflows/core-opencode-run.yml`         | 73      | UPDATE | Upgrade astral-sh/setup-uv@v5 → @v8                  |
| `.github/workflows/core-opencode-run.yml`         | 193     | UPDATE | Upgrade actions/upload-artifact@v4 → @v7             |

### Integration Points

- `ghar-issue-commands-list.yml:53` - github-script used for commenting on issues
- `ghar-issue-command-executor.yml:30` - github-script used for emoji reactions
- `ghar-issue-command-executor.yml:143` - github-script used for posting execution results
- `core-opencode-run.yml:73` - setup-uv used to install the uv Python package manager
- `core-opencode-run.yml:193` - upload-artifact used to archive run results

---

## Implementation Plan

### Step 1: Upgrade actions/github-script in ghar-issue-commands-list.yml

**File**: `.github/workflows/ghar-issue-commands-list.yml`
**Line**: 53
**Action**: UPDATE

**Current code:**
```yaml
        uses: actions/github-script@v7
```

**Required change:**
```yaml
        uses: actions/github-script@v9
```

---

### Step 2: Upgrade actions/github-script in ghar-issue-command-executor.yml

**File**: `.github/workflows/ghar-issue-command-executor.yml`
**Lines**: 30, 143
**Action**: UPDATE

Replace both occurrences of `actions/github-script@v7` with `actions/github-script@v9`.

---

### Step 3: Upgrade astral-sh/setup-uv in core-opencode-run.yml

**File**: `.github/workflows/core-opencode-run.yml`
**Line**: 73
**Action**: UPDATE

**Current code:**
```yaml
        uses: astral-sh/setup-uv@v5
```

**Required change:**
```yaml
        uses: astral-sh/setup-uv@v8
```

---

### Step 4: Upgrade actions/upload-artifact in core-opencode-run.yml

**File**: `.github/workflows/core-opencode-run.yml`
**Line**: 193
**Action**: UPDATE

**Current code:**
```yaml
        uses: actions/upload-artifact@v4
```

**Required change:**
```yaml
        uses: actions/upload-artifact@v7
```

---

## Edge Cases & Risks

| Risk/Edge Case                                | Mitigation                                              |
| --------------------------------------------- | ------------------------------------------------------- |
| Breaking API changes in github-script v8/v9   | Review changelogs; JS API surface is backward compatible |
| upload-artifact v5/v6/v7 input schema changes | Check `with:` parameters in workflow match new schema   |
| setup-uv v6/v7/v8 option renames              | Verify `with:` keys match new action inputs             |

---

## Validation

```bash
# Validate YAML syntax after changes
python3 -c "import yaml, glob; [yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.yml')]" && echo "YAML valid"

# Confirm all old versions are gone
grep -rn "github-script@v7\|upload-artifact@v4\|setup-uv@v5" .github/workflows/ && echo "OLD VERSIONS FOUND" || echo "All updated"
```

### Manual Verification

1. Trigger any workflow and confirm no "Node.js 20 deprecated" warnings in run logs
2. Verify `ghar-issue-command-executor` workflow still posts comments and reactions correctly

---

## Scope Boundaries

**IN SCOPE:**
- `actions/github-script`: v7 → v9
- `astral-sh/setup-uv`: v5 → v8
- `actions/upload-artifact`: v4 → v7

**OUT OF SCOPE:**
- Other workflow logic
- `actions/checkout` (already on compatible version)
- Any other actions not listed in the issue

---

## Metadata

- **Investigated by**: Claude
- **Timestamp**: 2026-04-18T13:00:00Z
- **Artifact**: `.claude/PRPs/issues/issue-10.md`
