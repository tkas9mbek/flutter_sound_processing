# Git Workflow — AI Context

## Branches

`<category>/[<TICKET-ID>_]<kebab-case-description>`

| Category | Use when |
|----------|----------|
| `feature/` | Any ticketed work (**regardless of work type**) or a new feature without a ticket |
| `fix/` | Bug fix without a ticket |
| `refactor/` | Cleanup / restructuring without a ticket |
| `research/` | PoC / experiment |
| `release/` | Release prep — named by bare version: `release/1.0.0` |

Long-lived: `master` is stable, its tip is the last published version. `release/<version>` is cut from `master`, collects the next version's work, and merges back when the version ships. There is no `dev` branch.

## Commits (and PR titles — usually the primary commit message)

```
TICKET-ID: Capitalized imperative description       # with ticket
type: Capitalized imperative description            # without ticket
type(scope): Capitalized imperative description     # optional scope: api, android, ios, example
```

`type` ∈ `{feature|feat, fix, refactor, research, release, docs, style, test, chore}`. Capitalized first letter, no trailing period, subject ≤ 72 chars, imperative mood, one logical change per commit.

A channel-contract change (Dart + Android + iOS) is one commit — splitting it leaves a broken intermediate state.

## Examples

```
release/1.0.0      feature/PROJ-12_mel-spectrogram      fix/ios-empty-signal-crash
feat(api): Add calculateMFCCsFromFile and calculateMFCCsFromPcm16
fix(ios): Compute MFCC in the plugin instead of RosaKit mfcc
chore(example): Add audio fixtures and file checks
docs: Document file and PCM16 input
release: Bump version to 1.0.0
```

## Never commit

`work/` (plans, analysis, review reports) and `.claude/` are git-ignored scratch; `pubspec.lock`, `build/`, `Pods/`, `.dart_tool/` likewise. Don't force-add them, and don't link to `work/` from committed docs.

## Tags

Tag the published commit on `master` as `v<version>` (`v1.0.0`). Only on explicit request (`R4`).
