# Issue 27 Archive

Source: GitHub issue #27 investigation comment.

## Issue

`gh pr review --approve` was gated on a fragile artifact chain, so the finalizer could skip approval and still exit green.

## Type

BUG

## Implementation Plan

1. Recast Phase 1 as context reading, not the approval gate.
2. Add a live issue-comment check immediately before `gh pr review --approve`.
3. Update the phase checkpoint to reflect the hard approval gate.

## Validation

`git diff --check`

## Notes

The workspace did not contain `.claude/PRPs/issues/issue-27.md`, so this archive was created from the GitHub investigation comment.
