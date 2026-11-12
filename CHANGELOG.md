# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- TauLoop harness: `AGENTS.md` plus `.harness/` (brief, verification defaults,
  verification profiles, check scripts, hooks, templates).

### Changed

- Build artifacts (`build/`, `*.app/`) and harness sandbox state are now
  explicitly ignored, so a `git add -A` cannot publish a compiled binary.

## [1.1.0] - 2026-11-12

### Added

- Settings window (⌘,) with grouped cards: Launch at login, battery floor,
  permission status, language, and About.
- Runtime language switch — System, English, 简体中文 — applied immediately, no
  restart. Every user-facing string goes through one lookup table.
- Launch at login, registered through `SMAppService`.
- Permission status row that checks the `sudoers` rule without side effects and
  shows the exact one-line fix when it is missing.

### Changed

- The dropdown menu is cleaner: SF Symbols instead of emoji, no explanatory
  subtitles, `Settings…` (⌘,) added, and the armed state now reads
  `Armed · waiting for the lid` / `Running · lid closed`.
- The single 326-line source file is split into focused files under `Sources/`
  (`LidStayApp.swift`, `Guard.swift`, `SystemProbe.swift`, `L10n.swift`,
  `MenuContent.swift`, `SettingsView.swift`), with the comment load cut to under
  10% of non-blank lines.
- Both READMEs rewritten around the product: shorter, bilingual, with a designed
  mark and cover image.
- Project renamed from LidGuard to LidStay: new app name, bundle id
  `io.github.lidstay.app`, state directory `~/.config/lidstay`, and `sudoers`
  file `/etc/sudoers.d/lidstay`. No behavior change beyond the v1.1.0 work.

## [1.0.0] - 2026-11-12

### Added

- Menu-bar app that arms a keep-awake session on demand: click, close the lid,
  and the machine keeps running until the lid opens again.
- Three-state machine (`idle` → `armedOpen` → `armedClosed` → `idle`) driven by
  a 2-second poll of `IOPMrootDomain`'s `AppleClamshellState`.
- Battery floor (10–30%, default 15%) that disarms on battery so a machine left
  in a bag cannot run itself flat.
- Disarm on lid open, on manual cancel, on quit, and on reboot (the kernel flag
  is a runtime property and is not persisted).
- Scoped `sudoers` installer (`scripts/install.sh`) granting exactly two
  literal `pmset -a disablesleep` commands, validated with `visudo -cf` before
  installation.
- Headless CLI modes for scripting and debugging: `--status`, `--arm`,
  `--disarm`.
- English and Chinese README, MIT license, `make`-based build, GitHub Actions CI
  on `macos-latest`.

### Notes

- `pmset -a disablesleep` is undocumented. It is present and working on Apple
  Silicon through macOS 27, but Apple can remove it; the app fails safe if it
  does.
- The arm → lid-close → lid-open cycle is not covered by automated tests. It
  requires physically closing the lid.
