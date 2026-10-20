# CLAUDE.md

> Claude-Code-specific guidance. Project rules, structure, style and commands live in [`AGENTS.md`](./AGENTS.md) — read it first; it applies unchanged. `.claude/` is git-ignored personal tooling.

## Subagents (`.claude/agents/`)

| Task shape | Agent | Notes |
|---|---|---|
| Plan a new/changed method, root-cause an unknown failure, judge an API/naming choice | `planner` | Writes `work/plans/` / `work/analysis/`. Never touches source or `docs/`. |
| Apply an existing plan or a fully specified change | `implementer` | Dart + Java + Swift + tests; verifies with `fvm flutter analyze` / `fvm flutter test`. |
| Review finished work | `reviewer` | Writes `work/review.md` per `docs/ai-context/code_review.md`. |

Chain for a new method: `planner` → `implementer` → `reviewer`. For a one-file fix, edit directly.

## Slash commands (`.claude/commands/`)

| Command | Does |
|---|---|
| `/com_commit` | Commit current changes in logical groups, per `docs/ai-context/git.md`. Never pushes or tags. |
| `/com_review` | Delegates to `reviewer`; writes `work/review.md`. |
| `/com_release` | Checks the release checklist (`docs/ai-context/release.md`) and reports gaps. Never publishes or tags. |
