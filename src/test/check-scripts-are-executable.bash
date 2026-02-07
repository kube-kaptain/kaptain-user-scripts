#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Test that all scripts have executable bits set

set -euo pipefail

SCRIPTS_DIR="src/scripts"

FAIL_COUNT=0
count=0

fail() {
  echo "FAIL: Not executable: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "=== Script Executable Bit Checks ==="
echo ""

echo "Checking executable bits on scripts in ${SCRIPTS_DIR}..."
while IFS= read -r -d '' file; do
  count=$((count + 1))
  if [[ ! -x "${file}" ]]; then
    fail "${file}"
  fi
done < <(find "${SCRIPTS_DIR}" -type f -print0)

echo ""
if [[ ${FAIL_COUNT} -eq 0 ]]; then
  echo "All ${count} scripts have the executable bit set"
  exit 0
else
  echo "${FAIL_COUNT} script(s) missing executable bit"
  exit 1
fi
