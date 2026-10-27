#!/usr/bin/env bash
# Checks the permissions of the Android packages (GrapheneOS acceptance, ADR 0012):
# - flavor "offline": no permission at all except Flutter's own, app-internal
#   DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION.
# - flavor "sync": additionally exactly INTERNET.
# Usage: check_apk_permissions.sh <offline.apk> <sync.apk>
set -euo pipefail

aapt2="$(ls -d "${ANDROID_HOME:?ANDROID_HOME is not set}"/build-tools/*/ | sort -V | tail -1)aapt2"

permissions() {
  "$aapt2" dump permissions "$1" \
    | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" \
    | grep -v '\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION$' \
    | sort || true
}

offline="$(permissions "$1")"
sync="$(permissions "$2")"

echo "offline: ${offline:-(none)}"
echo "sync:    ${sync:-(none)}"

if [[ -n "$offline" ]]; then
  echo "::error::The \"offline\" flavor requests permissions: $offline"
  exit 1
fi
if [[ "$sync" != "android.permission.INTERNET" ]]; then
  echo "::error::The \"sync\" flavor should request exactly INTERNET, but has: $sync"
  exit 1
fi
echo "Permissions as expected."
