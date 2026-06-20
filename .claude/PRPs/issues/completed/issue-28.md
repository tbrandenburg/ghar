# Investigation: Wire post-run-nudge-prompt into TDD workflow agent jobs

**Issue**: #28 (https://github.com/tbrandenburg/ghar/issues/28)
**Type**: ENHANCEMENT
**Investigated**: 2026-06-20T07:25:18Z

### Assessment

| Metric | Value | Reasoning |
| --- | --- | --- |
| Priority | HIGH | All 21 TDD workflow agent jobs can still soft-stop without posting their required marker, which means the hard bash gate can fail avoidably across the entire pipeline. |
| Complexity | MEDIUM | The change is confined to one workflow file, but it touches 21 reusable-run call sites and each one needs a marker-specific prompt. |
| Confidence | HIGH | The reusable nudge input already exists in `core-opencode-run.yml`, the current workflow call sites are enumerated, and the marker contracts are already defined in the command files. |

---

## Problem Statement

`core-opencode-run.yml` already supports a `post-run-nudge-prompt` that re-enters the same OpenCode session after the main run succeeds. The TDD workflow does not pass that input to any of its 21 `core-opencode-run` jobs, so an agent that finishes its primary work but forgets its required marker gets no self-correction pass before the deterministic bash gate runs.

---

## Analysis

### Root Cause / Change Rationale

This is an omission, not a missing feature. The reusable workflow already has the continue-mode hook, and the TDD workflow already uses deterministic marker checks in `post-run-bash-command`; it just never wires the soft nudge into the caller jobs. Adding a short marker-specific nudge to every agent job gives each agent one cheap recovery attempt before the hard gate fails the run.

### Evidence Chain

WHY: Agents can still complete their primary work and fail later because the required marker was never posted.
BECAUSE: The TDD workflow passes only `run-name`, `command`, `prompt`, `timeout-minutes`, and `post-run-bash-command` to each `core-opencode-run` invocation; `post-run-nudge-prompt` is absent from every call site.
Evidence: `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml:58-1179` - 21 reusable-run jobs are present, and none include `post-run-nudge-prompt`.

BECAUSE: The reusable workflow already has the continue-mode hook and only runs it when the input is non-empty.
Evidence: `.github/workflows/core-opencode-run.yml:48-57`

```yml
post-run-nudge-prompt:
  description: >
    Optional prompt sent to OpenCode via continue mode (opencode run
    --continue) immediately after the main run completes successfully.
    Use as a hint for the agent to verify its own output, e.g.
    "check whether you posted the required issue comment".
    Skipped when empty.
  required: false
  type: string
  default: ''
```

BECAUSE: The workflow already relies on comment-based marker contracts for every agent command.
Evidence: `.opencode/commands/ghar-implementer.md:21-23`

```md
Use `gh api` with `GH_TOKEN` to read the issue and its comments.
...
To publish an issue comment, write the complete Markdown body to a temporary file.
```

ROOT CAUSE: The caller workflow never wired the existing nudge input into the 21 agent jobs.

### Affected Files

| File | Lines | Action | Description |
| --- | --- | --- | --- |
| `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml` | `58-1179` | UPDATE | Add `post-run-nudge-prompt` to every `core-opencode-run` job in the TDD workflow. |

### Integration Points

- `.github/workflows/core-opencode-run.yml:203-219` runs the nudge with `opencode run --continue` before the bash verification step.
- `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml` already has the deterministic `post-run-bash-command` gates for each job.
- `.opencode/commands/ghar-*.md` job contracts publish markers as issue comments, so the nudge should tell the agent to check/post the marker comment, not the issue body.

### Git History

- **Introduced**: `ce1d6b2` - 2026-06-18 - `feat(core-opencode-run): add post-run nudge and bash verification inputs`.
- **Workflow gates added**: `1fdfb98` - 2026-06-19 - `feat(tdd-workflow): wire post-run-bash-command marker gates (v0.13.0)`.
- **Implication**: The soft nudge capability exists already; the TDD workflow simply never adopted it.

---

## Implementation Plan

### Step 1: Add marker-specific nudge prompts to every TDD agent job

**File**: `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml`
**Lines**: `58-1179`
**Action**: UPDATE

Add `post-run-nudge-prompt` to each `uses: ./.github/workflows/core-opencode-run.yml` job, immediately after `timeout-minutes:` and before the existing `post-run-bash-command:` block.

Use this prompt shape for each job:

```yml
post-run-nudge-prompt: >
  Check the issue comments. If you have not yet posted the
  `<!-- MARKER -->` marker comment, do it now.
  Reply 'done' when complete.
```

#### Job / marker map

| Job | Lines | Marker |
| --- | --- | --- |
| `planner-requirements` | `58-70` | `<!-- plan-requirements -->` |
| `planner-architecture` | `73-85` | `<!-- plan-architecture -->` |
| `planner-risks` | `88-100` | `<!-- plan-risks -->` |
| `planner-research` | `103-115` | `<!-- plan-research -->` |
| `spec-synthesizer` | `118-134` | `<!-- spec-final -->` |
| `spec-redteam` | `137-149` | `<!-- spec-redteam -->` |
| `tdd-reviewer` | `152-164` | `<!-- spec-tdd-review -->` |
| `spec-finalizer` | `167-179` | `<!-- spec-approved -->` |
| `test-agent` | `182-194` | `<!-- tests-created -->` |
| `implementer` | `197-209` | `<!-- implementation-done -->` |
| `pr-seeder` | `212-224` | `<!-- pr-seeded -->` |
| `implementation-review` | `432-444` | `<!-- implementation-review-findings -->` |
| `maintainer-review` | `447-459` | `<!-- maintainer-review-findings -->` |
| `adversarial-review` | `462-474` | `<!-- adversarial-review-findings -->` |
| `residual-gap-review` | `477-489` | `<!-- residual-gap-findings -->` |
| `e2e-evidence` | `492-510` | `<!-- e2e-evidence -->` |
| `review-fixer` | `512-533` | `<!-- fixer-summary -->` |
| `ci-fixer-1` | `674-693` | `<!-- fixer-summary -->` |
| `ci-fixer-2` | `836-855` | `<!-- fixer-summary -->` |
| `ci-fixer-3` | `998-1017` | `<!-- fixer-summary -->` |
| `pr-finalizer` | `1160-1179` | `<!-- pr-final -->` |

Why: this is the complete set of `core-opencode-run` jobs in the TDD workflow, and each one already has a marker gate that can benefit from a second self-check pass.

### Step 2: Keep the hard gate unchanged

**File**: `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml`
**Action**: DO NOT CHANGE

Leave every existing `post-run-bash-command` intact. The bash gate remains the authoritative pass/fail signal; the nudge only gives the agent a chance to recover before that gate runs.

### Step 3: Keep reusable workflow implementation unchanged

**File**: `.github/workflows/core-opencode-run.yml`
**Action**: DO NOT CHANGE

The continue-mode step already exists and already runs only when `inputs.post-run-nudge-prompt` is non-empty. No new plumbing is needed there.

---

## Patterns to Follow

**From codebase - mirror these exactly:**

```yml
# SOURCE: .github/workflows/core-opencode-run.yml:203-219
- name: Post-run nudge (continue session)
  if: ${{ success() && inputs.post-run-nudge-prompt != '' }}
  env:
    OPENCODE_GH_TOKEN: ${{ github.token }}
    NUDGE_PROMPT: ${{ inputs.post-run-nudge-prompt }}
  run: |
    RESULTS_FILE="${{ inputs.run-name }}-results.txt"
    printf '\n---\n## Post-run nudge\n\n' >> "$RESULTS_FILE"
    printf '%s' "$NUDGE_PROMPT" | env -i \
      PATH="$HOME/.opencode/bin:$PATH" \
      HOME="$HOME" \
      GH_TOKEN="$OPENCODE_GH_TOKEN" \
      opencode run \
        --continue \
        --model "${{ inputs.model }}" \
        --agent "${{ inputs.agent }}" \
        >> "$RESULTS_FILE"
```

```yml
# SOURCE: .github/workflows/ghar-multi-agent-tdd-issue-resolution.yml:182-193
uses: ./.github/workflows/core-opencode-run.yml
with:
  run-name: test-agent
  command: ghar-test-agent
  prompt: ${{ inputs.issue_number }}
  timeout-minutes: 45
  post-run-bash-command: |
    gh api --paginate "repos/${{ github.repository }}/issues/${{ inputs.issue_number }}/comments" \
      --jq '.[].body' | grep -q '<!-- tests-created -->'
```

---

## Edge Cases & Risks

| Risk / Edge Case | Mitigation |
| --- | --- |
| Missing one of the 21 job blocks | Use the job / marker map above and verify the final diff has 21 `post-run-nudge-prompt:` entries. |
| Nudge wording points at the issue body instead of issue comments | Use `Check the issue comments...` so the prompt matches the command contracts and the existing comment-based gates. |
| Nudge prompt is too long or too clever | Keep it short and mechanical; it should only ask the agent to verify/post the marker comment and reply `done`. |
| Accidental change to the bash gate | Do not edit any `post-run-bash-command` blocks; they remain the hard gate. |

---

## Validation

### Automated Checks

```bash
python3 -c "import pathlib, yaml; yaml.safe_load(pathlib.Path('.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml').read_text())"
grep -c 'post-run-nudge-prompt:' .github/workflows/ghar-multi-agent-tdd-issue-resolution.yml
make -f Makefile.ghar validate
```

### Manual Verification

1. Confirm every `core-opencode-run` job in `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml` now has a `post-run-nudge-prompt` entry.
2. Confirm each prompt names the correct marker for that job.
3. Confirm the existing `post-run-bash-command` lines are unchanged.

---

## Scope Boundaries

**IN SCOPE:**

- Add `post-run-nudge-prompt` to the 21 `core-opencode-run` jobs in `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml`.
- Use the correct marker string for each job.

**OUT OF SCOPE (do not touch):**

- `.github/workflows/core-opencode-run.yml`
- Any `.opencode/commands/*.md` files
- Any `post-run-bash-command` logic
- Any non-TDD workflows
- Any job that is not a `core-opencode-run` call site

---

## Metadata

- **Investigated by**: Claude
- **Timestamp**: 2026-06-20T07:25:18Z
- **Artifact**: `.claude/PRPs/issues/issue-28.md`
