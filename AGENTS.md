# Agent Guidelines

## Introduction

`Makefile.ghar` installs Github workflow files and needed opencode commands and agents in other repo contexts.

## Version

The authoritative version is the `GHAR_VERSION` variable at the top of `Makefile.ghar`. Git tags and commit messages must match this value. Always read `Makefile.ghar` before deciding the next version number.

## Guidelines

* If there are files added or renamed the impact on `Makefile.ghar` has to be checked
* `Makefile.ghar` has to worked in a piped mode
* "GHAR TDD workflow" means `.github/workflows/ghar-multi-agent-tdd-issue-resolution.yml`
* Review/scoring docs under `dev/` may be gitignored; if `glob` does not find `dev/frontier-scoring.md`, verify it with `git ls-files -oi --exclude-standard -- dev/frontier-scoring.md` or `rg --hidden --no-ignore "frontier-scoring" dev`
