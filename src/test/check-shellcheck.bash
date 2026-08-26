#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Lint every shell script with shellcheck
#
# src/flat/ is skipped because it holds generated copies of src/scripts/*/*,
# which would report every finding twice.

set -euo pipefail

# There are no repo-wide exclusions and there should not be. Every suppression
# lives next to the code it applies to, as an inline "# shellcheck disable=SCxxxx"
# with a comment saying why.

# Notes and style hints are not gated, only warnings and errors
SEVERITY="warning"

FAIL_COUNT=0
count=0

echo "=== Shellcheck ==="
echo ""

if ! command -v shellcheck &> /dev/null; then
  echo "FAIL: shellcheck is not installed"
  echo ""
  echo "  macOS:          brew install shellcheck"
  echo "  Debian/Ubuntu:  sudo apt install shellcheck"
  echo "  RHEL/Fedora:    sudo dnf install ShellCheck"
  exit 1
fi

echo "Using $(shellcheck --version | awk '/^version:/ {print $2}')"
echo "Severity: ${SEVERITY} and above, no repo-wide exclusions"
echo ""

# Everything under src/scripts is a script, whatever its name looks like. The
# encryption leaves have dots in their names, so no extension-based filter here.
files=()
while IFS= read -r -d '' file; do
  files+=("${file}")
done < <(find src/scripts -type f -print0 | sort -z)

# Elsewhere only .bash files, which skips the .bats suites
while IFS= read -r -d '' file; do
  files+=("${file}")
done < <(find .github/bin src/test -type f -name '*.bash' -print0 | sort -z)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "FAIL: No scripts found to check"
  exit 1
fi

for file in "${files[@]}"; do
  count=$((count + 1))
  if ! shellcheck --severity="${SEVERITY}" "${file}"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo ""
if [[ ${FAIL_COUNT} -eq 0 ]]; then
  echo "All ${count} scripts pass shellcheck"
  exit 0
else
  echo "${FAIL_COUNT} of ${count} script(s) have shellcheck findings"
  exit 1
fi
