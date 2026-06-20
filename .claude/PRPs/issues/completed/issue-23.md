# Investigation: ghar-pr-finalizer: call gh pr edit to update PR body

**Issue**: #23 (https://github.com/tbrandenburg/ghar/issues/23)
**Type**: BUG
**Investigated**: 2026-06-20T10:27:05+02:00

### Assessment

| Metric     | Value   | Reasoning |
| ---------- | ------- | --------- |
| Severity   | MEDIUM  | Every generated PR keeps the bootstrap body instead of the final summary, which misleads review but still has a manual workaround. |
| Complexity | LOW     | This is a single-file update in `.opencode/commands/ghar-pr-finalizer.md`, with no new workflow job or code module. |
| Confidence | HIGH    | The issue body, current command file, and workflow all show the PR body is created once and never refreshed by the finalizer. |

## Problem Statement

The workflow creates a PR with a placeholder body, then the finalizer never overwrites it with the completed run summary. That leaves reviewers with stale bootstrap text instead of the actual implementation, validation, and residual-risk context.

The finalizer already owns the last review/comment stage and already gathers the data needed for a human-ready summary, so the missing piece is a final `gh pr edit` publish step.

## Analysis

### Root Cause / Change Rationale

The root cause is not the absence of PR data. It is the absence of a publish step in `ghar-pr-finalizer.md` that takes the already-collected PR context and writes it back to GitHub after the review chain completes.

### Evidence Chain

WHY: PR bodies stay on the initial scaffold after the workflow finishes
↓ BECAUSE: the create-pr workflow step stamps a static placeholder body up front
Evidence: `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml:302-316` -

```bash
PR_BODY="Resolves #${ISSUE_NUMBER}

This pull request was created automatically by GHAR.
The branch is still under active development and will be updated by later workflow stages."

# Check for an existing open PR for this branch
PR_NUMBER=$(GH_TOKEN="$AUTH_TOKEN" gh pr list \
  --head "$BRANCH" --state open \
  --json number --jq '.[0].number // empty')

if [ -n "$PR_NUMBER" ]; then
  echo "Updating existing open PR #${PR_NUMBER}"
  GH_TOKEN="$AUTH_TOKEN" gh pr edit "$PR_NUMBER" \
    --title "$PR_TITLE" \
    --body "$PR_BODY"
```

↓ BECAUSE: the finalizer only describes the desired PR body in prose; it does not execute a body refresh
Evidence: `.opencode/commands/ghar-pr-finalizer.md:284-292` -

```markdown
### 7.1 Create or Update the Pull Request

Create exactly one pull request from `$BRANCH` to the repository default branch, or update the existing open/closed-unmerged PR for that head. Never create a duplicate. The PR body must:
- Link `Closes #$ISSUE_NUMBER`
- Summarize scope, implementation, TDD commit ordering, tests/checks, review, adversarial, residual-gap, and CI dispositions
- List all follow-up issues opened
- Note unresolved risks

Do not enable auto-merge or merge the PR.
```

↓ ROOT CAUSE: the finalizer is missing a terminal PR-body publish step that builds a structured summary from the collected artifacts and runs `gh pr edit`
Evidence: `.opencode/commands/ghar-pr-finalizer.md:308-321` currently ends with the `<!-- pr-final -->` issue comment and then the output phase, with no PR-body refresh.

### Affected Files

| File | Lines | Action | Description |
| ---- | ----- | ------ | ----------- |
| `.opencode/commands/ghar-pr-finalizer.md` | 39-52, 284-325 | UPDATE | Extend the fetched PR metadata, add a terminal PR-body refresh step, and record the body refresh in the phase checkpoint. |

### Integration Points

- `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml:1240-1263` runs `ghar-pr-finalizer` with `pull-requests: write` already granted.
- `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml:1170-1238` already computes the final CI status that the body summary should mirror.
- `.opencode/commands/ghar-pr-finalizer.md:296-303` already shows the repo’s preferred `--body-file` pattern for PR GitHub CLI calls.
- `.opencode/commands/ghar-review.md:455-463` uses the same `--body-file` pattern for PR review/comment publishing.

### Git History

- **Introduced**: `9637d1b` (2026-06-09) - `feat: add ci-retrigger-initial + ci-wait-initial after create-pr`
- **Last modified**: `acc4555` (2026-06-08) - `fix(pr-finalizer): remove local .claude/PRPs/reviews/ file generation`
- **Implication**: the PR body owner moved to `create-pr`, but the finalizer never gained a corresponding publish step to replace the bootstrap text.

## Implementation Plan

### Step 1: Extend PR metadata so the final body can describe the exact final state

**File**: `.opencode/commands/ghar-pr-finalizer.md`
**Lines**: 39-52
**Action**: UPDATE

**Current code:**

```markdown
### 2. Fetch the PR associated with `$BRANCH`:

```bash
# Get PR number for the branch
gh pr list --head "$BRANCH" --json number -q '.[0].number'

# Get comprehensive PR details
gh pr view {NUMBER} --json number,title,body,author,headRefName,baseRefName,state,additions,deletions,changedFiles,files,reviews,comments
```
```

**Required change:**

```markdown
# Get comprehensive PR details
gh pr view {NUMBER} --json number,title,body,author,headRefName,headRefOid,baseRefName,state,additions,deletions,changedFiles,files,reviews,comments
```

**Why**: the final PR body needs the head SHA to summarize the exact CI state at finalization time, using the same branch-head concept that the workflow wait jobs already use.

### Step 2: Add a terminal PR-body refresh block after `<!-- pr-final -->`

**File**: `.opencode/commands/ghar-pr-finalizer.md`
**Lines**: 308-325
**Action**: UPDATE

**Current code:**

```markdown
### 7.3 Publish `<!-- pr-final -->` Issue Comment

Publish `<!-- pr-final -->` with:

1. `# Final PR Readiness Report`
2. PR number and URL
3. Final commit and changed-file summary
4. Artifact-chain completeness
5. Code review findings table (critical / high / medium / low counts)
6. Validation results table (type-check / lint / tests / build)
7. Follow-up issues opened (with links), or "None"
8. Resolved and unresolved risk summary, including any tracked frontier gaps
9. Human review checklist and explicit merge decision request
```

**Required change:**

```markdown
### 7.4 Refresh the Pull Request Body

Write the final PR summary to a temp file, then update the PR body with `gh pr edit`.

```bash
PR_NUMBER=$(gh pr list --head "$BRANCH" --state open --json number -q '.[0].number // empty')
if [ -z "$PR_NUMBER" ]; then
  echo "No open PR found for $BRANCH; skipping PR body refresh"
else
  HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid -q '.headRefOid')
  CI_STATUS=$(GH_TOKEN="$GH_TOKEN" gh api \
    "repos/$GITHUB_REPOSITORY/actions/runs?head_sha=$HEAD_SHA" \
    --jq '
      [ .workflow_runs[] | select(.name != "GHAR Multi-Agent TDD Issue Resolution") ]
      | group_by(.workflow_id)
      | map(sort_by(.created_at) | last)
      | (length as $total
         | if $total == 0 then "no_ci"
           elif all(.[]; .status == "completed") and all(.[]; .conclusion == "success" or .conclusion == "skipped" or .conclusion == "neutral") then "green"
           else "failure"
           end)
    ')

  cat > /tmp/pr-final-body.md <<EOF
Closes #${ISSUE_NUMBER}

## Summary

{2-3 sentence summary of what was implemented and what was intentionally left alone}

## Artifact Chain

| Artifact | Status |
|----------|--------|
| spec-approved | present |
| tests-created | present |
| implementation-done | present |
| implementation-review-findings | present |
| maintainer-review-findings | present |
| adversarial-review-findings | present |
| residual-gap-findings | present |
| pr-seeded | present |
| e2e-evidence | present |
| fixer-summary | present |

## CI Status

${CI_STATUS}

## Changes

{list changed files with line counts from the PR metadata}

## Follow-up Issues

{URLs or None}

## Unresolved Risks

{risks or None}

---

_This PR body was automatically generated by GHAR's pr-finalizer._
EOF

  gh pr edit "$PR_NUMBER" --body-file /tmp/pr-final-body.md
fi
```

**Why**: this keeps the PR body ownership in the finalizer, preserves multiline Markdown safely, and makes the body reflect the completed run rather than the bootstrap scaffold.

### Step 3: Mark the PR body refresh as part of the finalizer checkpoint

**File**: `.opencode/commands/ghar-pr-finalizer.md`
**Lines**: 322-325
**Action**: UPDATE

**Required change:**

```markdown
**PHASE_7_CHECKPOINT:**
- [ ] PR body refreshed
- [ ] PR created or updated
- [ ] GitHub review posted (approve or comment)
- [ ] `<!-- pr-final -->` comment published
```

**Why**: the checkpoint should verify the new ownership rule explicitly, so future regressions are obvious during review.

### Step 4: Keep the rest of the finalizer untouched

Do not change the create-pr workflow body template, the review/comment publishing pattern, or the marker-comment contract. The fix should be a final PR-body refresh owned by the finalizer, not a broader workflow redesign.

## Patterns to Follow

**From the workflow - current bootstrap PR body owner:**

```bash
PR_BODY="Resolves #${ISSUE_NUMBER}

This pull request was created automatically by GHAR.
The branch is still under active development and will be updated by later workflow stages."

if [ -n "$PR_NUMBER" ]; then
  GH_TOKEN="$AUTH_TOKEN" gh pr edit "$PR_NUMBER" \
    --title "$PR_TITLE" \
    --body "$PR_BODY"
```

**From the finalizer - existing body-file publishing pattern:**

```bash
# When CI green and ready to approve
gh pr review {NUMBER} --approve --body-file /tmp/pr-review-body.md

# When still draft / CI not green — comment only
gh pr comment {NUMBER} --body-file /tmp/pr-review-body.md
```

## Edge Cases & Risks

| Risk/Edge Case | Mitigation |
| -------------- | ---------- |
| No open PR exists for the branch | Guard with `PR_NUMBER` empty check and skip the edit with a clear log line. |
| CI status is stale or absent | Compute status from the current PR head SHA and fall back to `no_ci` when no runs exist. |
| Multiline Markdown breaks shell quoting | Write the body to `/tmp/pr-final-body.md` and use `gh pr edit --body-file`. |
| Manual edits get overwritten | Document that the finalizer owns the canonical PR body at the end of the run. |

## Validation

### Automated Checks

```bash
git diff --check
```

### Manual Verification

1. Confirm `ghar-pr-finalizer.md` now has a 7.4 body-refresh block after `<!-- pr-final -->`.
2. Confirm the body template includes artifact-chain status, CI status, follow-up issues, and unresolved risks.
3. Confirm the PR body update uses `gh pr edit --body-file` and not inline shell-escaped Markdown.

## Scope Boundaries

**IN SCOPE:**

- Add a final PR-body refresh step to `ghar-pr-finalizer.md`
- Add the minimum metadata needed to summarize the final PR state accurately
- Keep the body update aligned with the existing artifact chain and review flow

**OUT OF SCOPE (do not touch):**

- Do not change `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml`
- Do not modify the `create-pr` bootstrap body template
- Do not alter review/comment publishing markers or approval rules
- Do not add new scripts, helper files, or auto-merge logic

## Metadata

- **Investigated by**: issue-resolution-workflow
- **Timestamp**: 2026-06-20T10:27:05+02:00
- **Artifact**: `.agents/issues/issue-23.md`
