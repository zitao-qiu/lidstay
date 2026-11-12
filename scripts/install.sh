#!/usr/bin/env bash
# Install the scoped passwordless sudo rule LidStay needs.
#
# It grants EXACTLY two commands and nothing else:
#   /usr/bin/pmset -a disablesleep 1
#   /usr/bin/pmset -a disablesleep 0
#
# sudoers matches arguments literally (no wildcards), so this cannot be widened
# by appending flags. `pmset restoredefaults`, `pmset sleep 0`, etc. all still
# require a password.
#
# Undo with: sudo rm /etc/sudoers.d/lidstay

set -euo pipefail

DEST="/etc/sudoers.d/lidstay"
ME="$(id -un)"

if [ -f "$DEST" ]; then
  echo "A rule already exists at $DEST:"
  echo
  cat "$DEST"
  echo
  read -r -p "Replace it? [y/N] " ans
  case "$ans" in [yY]*) ;; *) echo "Aborted."; exit 0 ;; esac
fi

RULE="$ME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"

echo "This will install the following rule at $DEST (root:wheel, mode 0440):"
echo
echo "  $RULE"
echo
echo "It permits ONLY toggling lid-close sleep. Nothing else."
read -r -p "Continue? [y/N] " ans
case "$ans" in [yY]*) ;; *) echo "Aborted."; exit 0 ;; esac

TMP="$(mktemp)"
printf '%s\n' "$RULE" > "$TMP"

# Validate before installing: a broken sudoers file can lock you out of sudo.
if ! sudo visudo -cf "$TMP"; then
  echo "error: generated rule failed validation; not installing." >&2
  rm -f "$TMP"
  exit 1
fi

sudo install -m 0440 -o root -g wheel "$TMP" "$DEST"
rm -f "$TMP"

echo
echo "== Verify =="
ls -l "$DEST"

if sudo grep -qE '^#?includedir[[:space:]]+/etc/sudoers\.d' /etc/sudoers; then
  echo "✅ /etc/sudoers includes sudoers.d"
else
  echo "⚠️  /etc/sudoers does NOT include sudoers.d — the rule will not take effect."
  echo "    Add it with: sudo sh -c 'echo \"#includedir /etc/sudoers.d\" >> /etc/sudoers'"
fi

# Idempotent probe: re-assert the current value so nothing changes.
if sudo -n /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1; then
  echo "✅ passwordless pmset works"
else
  echo "❌ passwordless pmset still fails; check with: sudo -n -l"
  exit 1
fi

echo
echo "Done. Build and run the app with:  make run"
