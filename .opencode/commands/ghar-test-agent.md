---
description: Create and commit failing tests from the approved spec
argument-hint: <issue-number>
---

# Test Agent

**Input**: $ARGUMENTS

---


## Runtime Contract

Extract the GitHub issue number from `$ARGUMENTS`. Set `ISSUE_NUMBER` to that numeric value and set:

```bash
BRANCH="agent/issue-${ISSUE_NUMBER}-implementation"
```

Use `gh api` with `GH_TOKEN` to read the issue and its comments. Never push to `main` or the repository default branch. Do not expose private reasoning; publish only the requested artifact.

To publish an artifact, write the complete Markdown body to a temporary file. Its first line must be the exact marker shown below. Find comments with `gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments?per_page=100"`, selecting an exact first-line marker match. If one exists, update that comment with `gh api --method PATCH`; otherwise create it with `gh api --method POST`. If legacy duplicates exist, update the newest matching comment and delete the older matching duplicates. Do not create a second artifact comment.


## Mission

Require the `spec-approved` artifact. Fetch and check out the shared branch with `git fetch origin "$BRANCH"` and `git checkout -B "$BRANCH" "origin/$BRANCH"`. Inspect existing tests, then encode the approved acceptance criteria as the smallest deterministic set of tests that fail for the intended missing behavior.

Before editing, record the baseline changed-file list. Modify only test files, fixtures, snapshots, and test-only helpers. Run the narrow relevant tests and preserve evidence that the new tests fail for the expected reason—not due to syntax, environment, or unrelated failures. Commit with a TDD-focused message and push only `HEAD:refs/heads/$BRANCH`.

Publish `<!-- tests-created -->` with:

1. `# Tests Created`
2. Commit SHA
3. Test-only files changed
4. Acceptance criteria and edge cases covered
5. Exact commands run and expected initial failures
6. Any untestable criterion or blocker

## Boundaries

Do not modify production code or the approved spec, weaken assertions, skip relevant failures, or add brittle tests. Before committing, inspect `git diff --name-only` and revert any file outside your allowed ownership.
