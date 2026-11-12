# Task Specs

Task specs turn non-trivial work into durable execution contracts.

## Status Model

Use one of these task-level statuses near the top of each spec:

- `draft`: the task is still being shaped
- `ready`: the spec is complete and implementation can start
- `in_progress`: implementation is underway
- `blocked`: implementation cannot continue until a stated unblock condition is met
- `done`: implementation and verification are complete

## Checklist States

Use these markers inside the implementation checklist:

- `[ ]` not started
- `[-]` blocked
- `[x]` done

## Recovery Rule

- On restart, read the active spec and continue from the first unchecked or blocked item.
- If the task changed materially, update the spec before touching code.
- If the solution requires new files, update `Allowed files` first.

## Verification Profile

- If the task needs a reusable task-type checklist, set `Verification profile` in the spec header.
- Use a path under `.harness/verification-profiles/`.
- Read only the selected profile, not the whole directory.

## Naming

- One file per non-trivial task: `.harness/specs/NNN-<slug>.md` (`NNN` zero-padded from `001`; `README.md`/`TEMPLATE.md` are excluded from the counter).
- `NNN` is the next integer after the highest existing `NNN-` prefix; start at `001` when the directory has none.
- `<slug>` is short lowercase kebab-case, e.g. `001-add-oauth-device-flow.md`.
- Keep the active spec in `.harness/plan.md` as a plain path, no trailing comment: `Spec: .harness/specs/NNN-<slug>.md`.
