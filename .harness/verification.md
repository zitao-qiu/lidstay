# Verification

## Global Rules

- Every non-trivial task must record what verification was run.
- If verification was intentionally skipped, state why and what residual risk remains.
- Prefer targeted verification over broad, expensive sweeps.
- Verification belongs in the task spec first. This file defines repo-level defaults.
- Keep this file short. Detailed checklists live in `.harness/verification-profiles/` and should be read only when they match the task.

## Default Closeout Checklist

- Confirm the change stayed inside the spec's `Allowed files`.
- Typecheck: `make lint`
- Build the bundle: `make build`
- Exercise the state machine headlessly:
  ```sh
  ./build/LidStay.app/Contents/MacOS/LidStay --status   # expect lid/sleepDisabled/battery/marker
  ./build/LidStay.app/Contents/MacOS/LidStay --arm      # expect "armed"
  ./build/LidStay.app/Contents/MacOS/LidStay --status   # expect sleepDisabled: true
  ./build/LidStay.app/Contents/MacOS/LidStay --disarm   # expect "disarmed"
  ./build/LidStay.app/Contents/MacOS/LidStay --status   # expect sleepDisabled: false, marker: (none)
  ```
- Lint the generated plist: `plutil -lint build/LidStay.app/Contents/Info.plist`
- Run `.harness/hooks/pre-closeout.sh` when hook entrypoints are installed.
- Confirm no build artifacts are staged: `git status --short` must not list `build/`.
- Restore the machine to `SleepDisabled = No` before ending the session.
- Update memory, plan, and the active spec before ending the thread.

## What "verified" means here

A running process is not evidence. For this project the evidence is always one
of:

- `--status` output showing the expected `sleepDisabled` and `marker` values;
- `ioreg -r -d 1 -n IOPMrootDomain | grep -E 'SleepDisabled|AppleClamshellState'`;
- `plutil -lint` on the plist;
- a green CI run on the pushed commit.

Anything that requires physically closing the lid (does the machine actually
stay awake? does it wake on open?) cannot be automated. When a task depends on
that behavior, state it as **unverified on hardware** in the spec and say who
must confirm it.

## Profile Selector

- `code-change`
  Use for feature work, bug fixes, and behavior-changing code edits.

- `refactor`
  Use when the goal is structural change with intended behavior parity.

- `docs-workflow`
  Use for workflow docs, templates, onboarding docs, and bootstrap logic.

- `reliability`
  Use when fixing recurring failures, adding prevention, or tightening the harness.

Read only the matching file under `.harness/verification-profiles/` instead of loading every checklist.
