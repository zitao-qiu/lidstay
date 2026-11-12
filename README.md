# LidGuard

**Keep your MacBook working with the lid closed — but only for the one trip you ask for.**

A tiny macOS menu-bar app. Click it, close the lid, put the machine in your bag, and your job keeps running. Open the lid when you arrive and normal sleep comes straight back.

```
lid close → sleep        (default, safe)
lid close → keep running (only while armed)
```

[中文说明](README.zh-CN.md) · MIT · macOS 13+

---

## The problem

You start a long job — a build, a download, a render, a batch run — and then you have to close the lid and leave.

macOS sleeps on lid close. This is not idle sleep; it is a hardware event fired by the lid sensor to `IOPMrootDomain`. That means **`caffeinate` cannot help**, and neither can any app built on IOKit power assertions (`KeepingYouAwake`, plain `Amphetamine` sessions, and friends). They hold off the idle timer. They do not see the lid.

The one thing that does override it is the kernel's `SleepDisabled` flag:

```sh
sudo pmset -a disablesleep 1   # lid close no longer sleeps
sudo pmset -a disablesleep 0   # back to normal
```

`disablesleep` is undocumented — it is not in `man pmset` — but it is present and working on Apple Silicon through macOS 27.

## Why not just leave it on?

Because a MacBook that never sleeps inside a bag has no airflow and no way to stop. It gets hot and it drains flat. That is the failure mode every "just disable sleep" guide warns about, and it is why this is a **menu bar toggle with an expiry**, not a system setting.

LidGuard's position: **sleep is the correct default. Keep-awake is a deliberate, temporary exception that ends by itself.**

## How it works

```
         click "Keep running when lid closes"
idle ──────────────────────────────────────► armedOpen
  ▲                                              │
  │                                              │ lid closes (polled @2s)
  │                                              ▼
  │                                         armedClosed
  │                                              │
  └──────────────────────────────────────────────┘
     lid opens / battery floor / cancel / quit
```

- **arm** → `sudo -n pmset -a disablesleep 1`, and write a state file
- **disarm** → `sudo -n pmset -a disablesleep 0`, and remove it
- Lid state is read from `IOPMrootDomain` → `AppleClamshellState` every 2 seconds
- Battery level comes from `IOPSGetPowerSourcesInfo`

The state file records `armed-open` or `armed-closed`, so an external watchdog can tell *"the user just pressed the button"* apart from *"the app died after the lid already closed"*. Without that distinction a watchdog would disarm you the moment you arm, before the lid is even shut.

## Install

```sh
git clone https://github.com/TTT-qq-TT/lidguard.git
cd lidguard

make            # build LidGuard.app into ./build
make install    # copy to ~/Applications

# one-time: install the scoped passwordless sudo rule
./scripts/install.sh
```

`install.sh` writes exactly this to `/etc/sudoers.d/lidguard`:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

sudoers matches arguments literally, with no wildcards, so the grant cannot be widened. It permits toggling lid-close sleep and nothing else. The script runs `visudo -cf` before installing, so a malformed rule can never break your sudo.

Requires the Swift toolchain (`xcode-select --install`). No Xcode project, no dependencies, no notarization — the build is ad-hoc signed locally.

## Usage

1. Launch `~/Applications/LidGuard.app`. A laptop icon appears in the menu bar.
2. About to close the lid with a job running → click the icon → **⚡ Keep running when lid closes**.
   The icon changes to a bolt.
3. Close the lid. Put it in your bag.
4. Open the lid when you arrive — sleep is restored automatically.

Right-click for a menu, or use the CLI:

```sh
LidGuard.app/Contents/MacOS/LidGuard --status
LidGuard.app/Contents/MacOS/LidGuard --arm
LidGuard.app/Contents/MacOS/LidGuard --disarm
```

`--status` output:

```
lid            : open
sleepDisabled  : false
battery        : 98% (battery)
marker         : (none)
```

## Safety

| Rail | What it does |
|---|---|
| **Lid-open auto-off** | `AppleClamshellState` Yes→No disarms immediately |
| **Battery floor** | Disarms at or below 15% (configurable 10–30%) when off AC |
| **Quit disarms** | Quitting the app while armed restores sleep |
| **Reboot clears** | `disablesleep` is a runtime flag, not persisted |
| **Crash watchdog** | The `armed-open`/`armed-closed` marker lets an external watcher finish the job if the app dies |

Two rules still apply, and no app can enforce them for you:

- **Never leave an armed, closed MacBook in a bag for hours on battery.** The battery floor helps, not saves.
- **Prefer AC when you can.** On AC many MacBooks already stay awake with the lid closed — check before assuming you need this at all.

## Do you even need this?

Worth testing first. On some MacBooks running macOS with `sleep 0` on AC, closing the lid already does not sleep the machine. Check with:

```sh
pmset -g log | grep -i "Clamshell Sleep"
```

If every `Clamshell Sleep` line says `Using Batt` and none say `Using AC`, then on AC you are already fine and LidGuard is only useful on battery.

## How it compares

| | LidGuard | Sleepless | Amphetamine | `caffeinate` |
|---|:---:|:---:|:---:|:---:|
| Survives lid close | ✅ | ✅ | ⚠️ | ❌ |
| Ends by itself | ✅ lid opens | ✅ timer | manual | ✅ on process exit |
| Battery floor | ✅ | ✅ | ✅ | ❌ |
| Open source | ✅ MIT | ✅ MIT | ❌ | Apple |
| Handles the "just arm, lid still open" race | ✅ | n/a | n/a | n/a |

The mechanism is the same as every project in this space — `pmset disablesleep`. What LidGuard adds is the **carry-trip session model**: arm on demand, expire on lid-open, with a state file a watchdog can reason about.

Related projects worth reading: [Sleepless](https://github.com/Aboudjem/Sleepless), [awake](https://github.com/pistachionet/awake), [Awayke](https://github.com/daemonphantom/Awayke), [lid-awake](https://github.com/austinginder/lid-awake), [Amphetamine](https://github.com/x74353/Amphetamine).

## Uninstall

```sh
make uninstall
sudo rm /etc/sudoers.d/lidguard
rm -rf ~/.config/lidguard
```

If the app is armed when you uninstall, disarm first (`--disarm`) or run `sudo pmset -a disablesleep 0`.

## Layout

```
Sources/LidGuardApp.swift    the whole app, one file (~330 lines)
scripts/install.sh           scoped sudoers rule
Makefile                     build / install / run / clean / lint
```

## License

MIT
