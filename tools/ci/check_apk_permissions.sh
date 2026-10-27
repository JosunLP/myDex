#!/usr/bin/env bash
# Prüft die Berechtigungen der Android-Pakete (GrapheneOS-Abnahme, ADR 0012):
# - Ausgabe „offline“: keinerlei Berechtigung außer der von Flutter
#   selbst vergebenen, app-internen DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION.
# - Ausgabe „sync“: zusätzlich genau INTERNET.
# Aufruf: check_apk_permissions.sh <offline.apk> <sync.apk>
set -euo pipefail

aapt2="$(ls -d "${ANDROID_HOME:?ANDROID_HOME fehlt}"/build-tools/*/ | sort -V | tail -1)aapt2"

permissions() {
  "$aapt2" dump permissions "$1" \
    | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" \
    | grep -v '\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION$' \
    | sort || true
}

offline="$(permissions "$1")"
sync="$(permissions "$2")"

echo "offline: ${offline:-(keine)}"
echo "sync:    ${sync:-(keine)}"

if [[ -n "$offline" ]]; then
  echo "::error::Die Ausgabe „offline“ fordert Berechtigungen an: $offline"
  exit 1
fi
if [[ "$sync" != "android.permission.INTERNET" ]]; then
  echo "::error::Die Ausgabe „sync“ soll genau INTERNET anfordern, hat aber: $sync"
  exit 1
fi
echo "Berechtigungen wie erwartet."
