# Contributing

## Scope

Keep this small. LidGuard governs exactly one thing — the kernel's
`SleepDisabled` flag — and everything else in the repo is a safety rail around
that. A change that turns it into a general keep-awake toolkit is out of scope,
no matter how small the first step looks.

## Changes

1. **Behavior changes need a spec.** Open `.harness/specs/NNN-<slug>.md` from
   the template before editing code, and keep its `Allowed files` as the change
   boundary. Docs-only edits can skip the spec.
2. **Every new system-state change needs an undo rail.** If a change can leave
   `disablesleep` set, it needs a path that clears it (lid open, quit, battery
   floor, or reboot) and a line in the spec saying which.
3. **`caffeinate` is not a mechanism here.** It holds an IOKit power assertion,
   and lid-close sleep sits below the assertion system. PRs that add a
   `caffeinate` path will be declined with this paragraph.
4. **Never widen the sudoers grant.** Two literal commands, no wildcards. If a
   feature needs a third `pmset` invocation, argue for it in an issue first.
5. **Do not kill or signal other processes.** LidGuard has no business managing
   anything except its own sleep flag.
6. Run the checks in `README.md` and include the output in the PR body:
   ```sh
   make lint
   make build
   ./build/LidGuard.app/Contents/MacOS/LidGuard --status
   plutil -lint build/LidGuard.app/Contents/Info.plist
   ```

## Pull Requests

Use a focused branch. Describe the user-visible behavior, what you actually ran,
the macOS version and Mac model you ran it on, and any residual risk — in
particular, say plainly when something was not verified on hardware. Do not
commit `build/`, local state files under `~/.config/lidguard/`, or machine paths.

## Releases

Semantic version tags. Update `CHANGELOG.md`, verify a clean `git clone` builds
with `make`, then create a GitHub release from the tagged commit.
