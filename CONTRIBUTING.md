# Contributing to Grau

Thanks for the interest. Grau is a single-developer project on a 5-slice
plan; the way to help is to pick a task from `docs/TASKS.md` or to file
a well-scoped issue.

## Ground rules

- **Open an issue first for any non-trivial change.** Grau has a long
  design history documented in `docs/PLAN.md` and `docs/REVIEW.md`. Most
  "obvious" additions already have a deferred entry in `docs/TASKS.md`
  or a `## v2` note in `docs/REVIEW.md`. Read those before opening a PR
  that adds scope.
- **Don't bump the version or tag releases.** The maintainer does that.
- **Don't add third-party runtime dependencies in v1.** v1 has zero
  runtime deps. Sparkle is added in v1.1.
- **Keep public APIs documented.** `graucore` is consumed by the app
  target. Anything you `public` needs a doc comment.

## Development setup

```bash
brew install xcodegen
git clone https://github.com/lucianodiisouza/grau
cd grau
xcodegen generate
cd graucore && swift test  # 155 tests
cd .. && xcodebuild -project grau.xcodeproj -scheme grau -configuration Debug build
```

## Commit conventions

Grau uses [Conventional Commits](https://www.conventionalcommits.org/)
with a scope tag. Examples from this repo:

```
feat(2.1-2.3): Uninstaller engine — AppScanner, ResidualFinder, Uninstaller
fix(1.7): JunkCleanerView confirmsheet cancel reverts to results
docs(4.5): MANUAL-TEST Phase 4 + CHANGELOG Beta 4
refactor(0.3): graucore Swift Package + linked into app target
test(5.5): Phase 5 dev-mode test coverage
chore(deps): bump XcodeGen to 2.42
```

Scopes map to the phase: `0.*` for scaffold, `1.*` for junk, `2.*` for
uninstaller, `3.*` for disk lens, `4.*` for duplicates, `5.*` for dev
mode, `6a.*` for v1.0 polish.

## Pull request checklist

- [ ] `cd graucore && swift test` — all 155 tests pass
- [ ] `xcodebuild -project grau.xcodeproj -scheme grau -configuration Debug build` — clean
- [ ] `xcodebuild -project grau.xcodeproj -scheme grau -configuration Release build` — clean
- [ ] New public types have a doc comment
- [ ] New destructive actions are gated by a confirmation
- [ ] New features update `docs/MANUAL-TEST.md`
- [ ] No new third-party runtime dependencies
- [ ] No SwiftData (project decision — see `docs/REVIEW.md` B6)

## Filing an issue

Use one of the templates. If you're filing a bug:

1. Reproduce on a clean `~/.grau/` (delete it and try again).
2. Include `~/Library/Logs/grau/grau.log` if the app crashed.
3. Include the macOS version (`sw_vers`) and architecture
   (`uname -m`).

If you're filing a feature request, check `docs/TASKS.md` first —
most of the ideas you're going to have are already there as
"deferred to v1.1" or "v2 idea".

## Security disclosures

Email security concerns to the maintainer rather than filing a
public issue. See the GitHub profile for contact.
