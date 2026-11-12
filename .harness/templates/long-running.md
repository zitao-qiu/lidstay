# Long-Running Launcher

**When to read**: at the launch point of a long-running task (Mode A foreground watch or
Mode B shift agent) — not at startup. Mode selection and invariants: `AGENTS.md` →
Long-Running Tasks. Inspection rounds, shift-status format, environment disciplines:
`.harness/templates/shift-agent.md` (not duplicated here).

## 1. Launch decoupled (both modes)

Pick by platform; prefer the OS-owned mechanism:

- **Linux with systemd (preferred)** — a transient unit, decoupled from any session and
  process group (`nohup` background processes can be killed with the agent session's
  process group; observed in practice, died twice):
  ```bash
  systemd-run --user --unit=<name> --collect bash -c 'cd <root> && bash scripts/<stage>.sh >> logs/<stage>.log 2>&1'
  systemctl --user is-active <name>   # liveness; use the unit name as `pid` in the shift-status section
  ```
- **No systemd** — `nohup bash scripts/stage.sh > logs/stage.log 2>&1 &`, or
  `screen -dmS stage bash scripts/stage.sh` when you need to re-attach interactively.
- **Windows (PowerShell)**:
  ```powershell
  Start-Process python -ArgumentList "scripts/stage.py" -NoNewWindow -RedirectStandardOutput logs/stage.log -RedirectStandardError logs/stage.err -PassThru
  ```
  `screen` has no native Windows equivalent — drop re-attach or run under WSL/Git Bash.

Then record the process handle (PID or unit name), log path, status file, and expected
artifacts in the shift-status section of `.harness/plan.md`.

## 2. Mode A — orchestration script, polling, backup timer

Orchestration script: sequential steps, each appending one machine-readable line to a
status file; never abort on a failed step (record FAIL and continue):

```bash
echo "STEP=<name> START model=... run=..." >> logs/<task>.status
# ... step command ...
echo "STEP=<name> DONE exit=0" >> logs/<task>.status   # or FAIL exit=<n>
```

Poll in the foreground — a single bash call can run 10–20 minutes:

```bash
for i in $(seq 1 10); do
  sleep 120
  grep STEP= logs/<task>.status | tail -2    # progress
  systemctl --user is-active <unit>          # executor alive
done
```

Arm a backup shift-agent timer (recommended, 15 min) as a second pair of eyes; stop it at
closeout: `systemctl --user stop shift-<task>.timer && systemctl --user disable shift-<task>.timer`.

## 3. Mode B — arm the timer

Try in order, first that works wins (probe each, do not assume):

1. **systemd user timer** (Linux; survives reboots via `loginctl enable-linger`):
   ```bash
   export XDG_RUNTIME_DIR=/run/user/$(id -u)   # must be in the SAME Bash call as systemctl
   systemctl --user is-system-running           # if OK, proceed
   ```
   Write `~/.config/systemd/user/shift-<task>.{service,timer}` (service runs
   `headless_cmd`; timer `OnUnitActiveSec=15min`), then
   `systemctl --user daemon-reload && systemctl --user enable --now shift-<task>.timer`.
   "Failed to connect to bus" is almost always the missing `XDG_RUNTIME_DIR` above, not a
   broken system.
2. **macOS launchd**: a `LaunchAgent` plist running `headless_cmd` on an interval.
3. **Neither available → self-loop** (process-level fallback):
   ```bash
   setsid bash -c 'while :; do <headless_cmd>; sleep 900; done' > logs/shift-loop.log 2>&1 &
   ```
   Record its PID in `loop_pid`.
4. **Host already configured cron → consume it** (optional enhancement).

Record `timer_type: systemd-user | launchd | selfloop | cron` plus a `cron_note` with the
reason (e.g. "crontab blocked by NoNewPrivs → systemd user timer"). Never try `crontab`
or `sudo` from the agent shell on Linux: the command layer hard-sets
`PR_SET_NO_NEW_PRIVS` (process hardening, not a config flag), so setuid/setgid binaries
structurally fail — fall back to the self-loop and record it.
