# Security Policy

## Supported Surface

The current `main` branch and tagged releases are supported for security fixes.

## Reporting

Do not open a public issue for a suspected vulnerability, a privilege-escalation
path, or anything involving the `sudoers` rule. Use GitHub's private security
advisory flow on this repository instead. Include the affected version, the
macOS version and Mac model, reproduction steps, and impact.

## Trust Boundary

LidGuard requests **one** privileged capability:

```
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

That is the entire grant. It is installed by `scripts/install.sh` into
`/etc/sudoers.d/lidguard` with mode `0440`, owner `root:wheel`, and only after
the generated rule passes `visudo -cf`. sudoers matches argument lists
literally, so the grant cannot be widened by appending flags — `pmset sleep 0`,
`pmset restoredefaults`, and every other subcommand still require a password.

The app itself:

- makes **no network connections** of any kind;
- collects **no telemetry** and writes nothing outside
  `~/.config/lidguard/` and its own `UserDefaults`;
- does **not** kill, signal, or inspect other processes;
- does not install a helper daemon, kernel extension, or launch agent.

The only state it writes is a two-line file at `~/.config/lidguard/armed`
containing `armed-open` or `armed-closed`.

## What this app is not

It is not a sandbox, an access-control tool, or a policy engine. It flips a
single undocumented macOS power-management flag and then flips it back. If that
flag is ever reachable without the sudoers rule on some future macOS, the rule
becomes redundant but not dangerous — the grant has no other use.

## Threat model of the sudoers rule

The realistic misuse of a `NOPASSWD: pmset` grant is wiping a user's power
configuration (`pmset restoredefaults`), which can leave a laptop unable to
sleep. This rule does not permit that: both entries name the full command line.
A local attacker who can execute arbitrary commands as the user can already do
far worse than change sleep settings, so the rule does not meaningfully widen
the local attack surface.

Uninstalling removes the grant:

```sh
sudo rm /etc/sudoers.d/lidguard
```
