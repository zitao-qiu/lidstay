# Brief

## Product Scope

LidGuard is a macOS menu-bar utility that keeps a MacBook running with the lid
closed — but only for the session the user explicitly asks for.

The problem it solves: with a long job running (a build, a download, a render,
a batch run) the user has to close the lid and carry the machine away. macOS
sleeps on lid close. That sleep is a hardware event fired by the lid sensor at
`IOPMrootDomain`, so `caffeinate` and every IOKit power assertion miss it
completely. The only override is the kernel's undocumented `SleepDisabled`
flag, reachable as `sudo pmset -a disablesleep 1`.

In scope:

- A menu-bar toggle that arms a keep-awake session on demand.
- Automatic disarm when the lid opens again.
- Safety rails so an armed machine cannot quietly cook or drain itself: a
  battery floor, disarm-on-quit, and reboot clearing the kernel flag.

Out of scope:

- Replacing macOS power management generally.
- Anything that requires a kernel extension, a privileged helper daemon, or an
  App Store sandbox (none of which can touch `SleepDisabled`).
- Remote control, telemetry, accounts, or a cloud component. There is no
  network code in this project at all.

## Architecture

Three layers, one process:

```
MenuBarExtra (SwiftUI)      presentation only
      |
Guard (ObservableObject)    2 s poll loop + state machine + battery floor
      |
Sys (enum)                  IOKit reads (lid, SleepDisabled, battery)
                            Process calls: sudo -n pmset, osascript notify
```

- **Presentation** — a `MenuBarExtra` with a menu. No window, no Dock icon
  (`LSUIElement`).
- **State machine** — `idle → armedOpen → armedClosed → idle`. The only state
  that matters to the system is whether `disablesleep` is 1; the other two
  exist so the app can tell "waiting for the lid" from "lid already shut".
- **System layer** — all privileged or kernel-facing work is isolated in `Sys`.
  Everything else is pure Swift.

**The state file** (`~/.config/lidguard/armed`) is the one piece of shared
state. It holds `armed-open` or `armed-closed`. An external watchdog reads it
to distinguish *the user just pressed the button* (lid still open — do nothing)
from *the app died after the lid shut* (lid open again — disarm on its behalf).
Collapsing those two cases is a real bug, not a simplification: it makes a
watchdog disarm you the moment you arm.

## Tech Context

- **Language/runtime**: Swift, single file, no dependencies, no Xcode project.
  Built with `swiftc` directly; `make` wraps it.
- **Minimum OS**: macOS 13 (for `MenuBarExtra`).
- **Frameworks**: SwiftUI, AppKit, IOKit (`IOPMrootDomain` properties),
  IOKit.ps (battery).
- **Build**: `make` → `build/LidGuard.app` (ad-hoc signed). `make install`
  copies to `~/Applications`.
- **Privilege**: one scoped `/etc/sudoers.d/` rule permitting two literal
  `pmset -a disablesleep` invocations. No helper daemon, no XPC, no kext.
- **CI**: GitHub Actions (`macos-latest`) runs `make lint`, `make build`, a
  `--status` smoke test, and `plutil -lint` on the generated Info.plist.
- **No Windows/Linux support by design** — the whole subject matter is macOS
  power management.

## Patterns

- **Privileged work is confined to one enum.** If a new feature needs root,
  it goes through `Sys`, not scattered through the UI.
- **Headless CLI modes for every user-facing action.** `--status`, `--arm`,
  `--disarm` mean the state machine can be exercised without clicking a menu,
  which is how CI and manual debugging validate it.
- **Timers over event streams** for lid state: IOKit clamshell notifications
  are not a stable public API; a 2 s poll of `AppleClamshellState` is boring
  and reliable.
- **Everything that changes system state must have a rail that undoes it.**
  Arm has lid-open, quit, battery floor, and reboot.

## Non-Negotiables

1. **Sleep stays the default.** The app must never leave `disablesleep` set
   without an armed session the user initiated.
2. **Opening the lid must always disarm**, regardless of how the app got into
   `armedClosed`.
3. **The sudoers grant stays two literal commands.** No wildcards, no
   `pmset` subcommand beyond `-a disablesleep 0/1`, no generic `NOPASSWD: pmset`.
4. **No process is ever killed or signalled.** LidGuard governs the machine's
   sleep flag; it does not manage other applications' lifecycles.
5. **No network.** The app must not make outbound connections.
