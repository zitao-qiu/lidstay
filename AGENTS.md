# AGENTS.md

## Startup

Read `.harness/memory.md` first — it is the current source of truth. Then size the rest to the task:

| Tier | Read |
|---|---|
| Quick | `memory.md` only |
| Standard | + `plan.md`, and the active spec when one exists |
| Deep | + `brief.md`, `verification.md`, the matching `verification-profiles/` entry, and only the relevant section of `report.md` |

`brief.md` holds stable project foundation (scope, architecture, technology choices, onboarding); `verification.md` holds repo-level validation defaults. Read both only at the tier that needs them.

Read `.harness/failure-log.md` when the task resembles a known failure mode, or when a new reusable failure was discovered. `report.md` is never startup context — read it only when the task needs prior experiments, audit trail, design history, or regression context.

## Harness Scope

This harness governs non-trivial, multi-session, or long-running work.
Skip it when the overhead outweighs the work — YAGNI applies to the harness too:

- Pure mechanical edits (formatting, renames, typo fixes), no behavior change → fix directly. No spec, no hooks.
- One-shot scripts and throwaway experiments → run directly; note the outcome in `.harness/memory.md` only if it matters later.
- The user says "just do it" / "直接改" or otherwise opts out → follow the user, do not re-impose the flow.
- Unsure → take the lighter tier and say so in one line.

Off switch: `stop tau-loop` suspends the harness for the rest of the session (finish in-flight closeouts first). `raw mode` is the same command.
Intensity: `tau-lite` = work from memory.md, no spec, no hooks; default = full harness. The user sets the level per task or per session.

## Task Entry Ladder

Stop at the first rung that holds:
1. Mechanical edit, no behavior change → fix directly, zero harness artifacts.
2. Small task, nothing worth a durable contract → memory.md line + direct work.
3. An active spec already covers this change → extend that spec, never open a duplicate.
4. Otherwise → full flow: spec → plan entry → pre-task hook → closeout.

## Workflow

- Keep threads scoped to one subtask.
- For non-trivial work, create or update a task spec before code changes, and treat its `Allowed files` as the current change boundary; if scope changes, update the spec before continuing.
- Run the pre-task hook after shaping the task, and the pre-closeout hook before marking the task done, when hook entrypoints are installed: `.harness/hooks/*.sh` on bash hosts, `.harness/hooks/*.py` (via `python`/`py -3`) on Windows.
- Record verification in the spec before marking the task done.
- Treat repeated compaction as a warning sign, not normal workflow.
- Before ending a thread or switching scope, update `.harness/memory.md` and `.harness/plan.md`, plus the active spec when task-local state changed.
- Update `.harness/failure-log.md` when the task exposed a reusable failure or prevention. Update `.harness/report.md` only when the information is worth preserving as durable history.

## Debug Triage: Research First

When you hit a bug (test failure, command error, anomalous log, behavior mismatch, or a user-reported bug), default to **research first, fix second** — no blind fixes (trial-and-error patches, working around the symptom, or changing acceptance criteria to pass). The detailed workflow lives in `.harness/templates/debug-triage.md`; for unattended long-task rounds use `shift-agent.md` instead.

- **Research priority**: ① official docs (current version, matching platform) → ② upstream repo (source + issue tracker; search GitHub with a distinctive fragment of the raw error message, not the whole message) → ③ open-source community (Stack Overflow, similar projects) → ④ papers / arXiv / technical reports (**research projects move this to ②**: research repos, bugs in algorithm/method implementation, or the user declaring a research scenario).
- **Before you fix, you must have**: a minimal reproduction, the raw evidence (error text / stack / log tail), a falsifiable root-cause hypothesis, and a research trail with specific sources (URL / issue # / commit / paper title).
- **Skipping research is allowed only for**: pure formatting/typing/mechanical edits with no behavior change; no network access (then record "not researched" and the residual risk). State the skip in the spec's debug-evidence section.
- **Evidence lands in the spec**: for fix tasks, record 现象 (symptom) / 查证记录 (research trail) / 根因结论 (root cause) / 修复依据 (fix rationale) / 残余风险 (residual risk) in the spec's debug-evidence section; reusable failure modes go into `.harness/failure-log.md`.
- **Hand over instead of fabricating**: when research is exhausted and there is still no fix, stop and hand over (observed / tried / researched / suggested next step) — never invent sources or conclusions.

## Specs

- A `spec` (`.harness/specs/*.md`) is the task's durable contract: goal, boundaries, allowed files, acceptance. Start every task as a spec.
- Rule: always write the task as a spec first. A spec is the single source of truth for what the task must do; keep it updated as scope changes.
- Name spec files `.harness/specs/NNN-<slug>.md` (`NNN` zero-padded from `001`); details in `specs/README.md`.
- A deliberate simplification with a known ceiling (global lock, O(n²) scan, naive heuristic) gets a code-level marker naming the ceiling and upgrade path: `# tau: global lock, per-account locks if throughput matters`. Mirror the marker into the spec's residual-risk section so the next window sees it without reading the code.

## Long-Running Tasks

**Host-native first**: if your runtime has its own long-task mechanism (background job + wake-up, e.g. DSH background jobs, ZCode background tasks), prefer it — the host knows how to wake this session, and the host's own prompt already documents how to drive it. Do not restate or second-guess it here.

What stays ours on every host: write the task as a spec; keep one machine-readable status file the flow appends to as it advances (`STEP=START|DONE|FAIL model=... exit=...`); and close out from that file plus real artifacts — **never from a "process still running" signal**. Long machine-supervised command sequences (download, build, assemble, train, ...) run in-session by default; hand them to the host's mechanism only when it exists and is the better owner.

On a host with no native mechanism, long work is owned by the OS (or the host), never the session: a foreground sleep does not exist in turn-based runtimes, and session-spawned processes can die with the session's process group. Never trust "process still running" as success there either. Launch commands, timer-arming procedures, platform traps, the two watch modes, and the shift-status format live in `.harness/templates/long-running.md` — read it when you reach this point, not at startup. On failure: backup → minimal change → smoke → relaunch.

## Active Window-Switch

When the context window is nearly full, or you want to separate discussion from execution, offer:

> "Please hand off to the next window."

Then, in order:

1. **Decide the intent** (required): state in one line what the next window should do, plus one line of why. Reference intents: *continue running* / *decision→execution separation* / *fresh review* / *explore a branch*. If none fit, decide yourself — intent is a declaration, not a menu.
2. **Confirm the facts are current**: `spec` / `plan` / `memory` are maintained as usual; just make sure they reflect the latest state.
3. **Write the handoff** to `.harness/handoffs/<id>.md`, carrying only:
   - `intent` + one-line reason
   - `spec_path` — the current contract
   - `progress` — completed stages, current stage, artifacts
   - `evidence` — verified receipts
   - `constraints` — decisions, allowed_files, next_action
   - Never chat history.
4. **Produce the prompt** for the user to copy: ≤5 lines, no role-play boilerplate. Three elements: intent in one line, handoff path, one action line derived from the intent.

The user opens a fresh session and pastes the prompt. The new window reads AGENTS.md, then the handoff, verifies its listed evidence before acting, and follows the intent — no further explanation needed.

Hand off at semantic boundaries (stage done, spec switch, decision frozen). Do not hand off for short tasks or when the window is not full — official compact is enough there.

## Checkpoint Rule

If the current thread has compacted once and is growing again, checkpoint and start a fresh thread instead of relying on another compaction.

## Working Agreement

- `.harness/memory.md` is the current source of truth; `.harness/plan.md` is the active execution plan; `.harness/specs/*.md` are task execution contracts.
- `.harness/brief.md` is stable project foundation, `.harness/verification.md` repo-level validation defaults, and `.harness/verification-profiles/*.md` task-type checklists — all read only at the tier that needs them.
- `.harness/failure-log.md` stores reusable failures and prevention changes; `.harness/report.md` is historical record and is not startup context.

## Large Repos

If this repository has clearly separate subsystems, add local `AGENTS.md` files inside those subdirectories with more specific guidance. Keep the root file short.
This follows the emerging hierarchical AGENT/AGENTS pattern used by multi-agent tooling.
