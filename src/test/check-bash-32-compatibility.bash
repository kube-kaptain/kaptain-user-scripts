#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Test scripts for bash 3.2 compatibility

set -euo pipefail

SCRIPTS_DIR="src/scripts"

FAIL_COUNT=0

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
  echo "PASS: $1"
}

echo "=== Bash 3.2 Compatibility Checks ==="
echo ""

# Check for associative arrays (declare -A)
echo "Checking for associative arrays (declare -A)..."
if grep -r "declare -A" "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found 'declare -A' (associative arrays require bash 4+)"
else
  pass "No associative arrays found"
fi

# Check for declare -g (global scope, bash 4.2+)
echo "Checking for declare -g..."
if grep -r "declare -g" "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found 'declare -g' (requires bash 4.2+)"
else
  pass "No declare -g found"
fi

# Check for case conversion ${var,,} and ${var^^}
echo "Checking for case conversion syntax..."
if grep -rE '\$\{[^}]+,,\}|\$\{[^}]+\^\^\}' "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found case conversion syntax (requires bash 4+)"
else
  pass "No case conversion syntax found"
fi

# Check for mapfile/readarray
echo "Checking for mapfile/readarray..."
if grep -rE '\b(mapfile|readarray)\b' "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found mapfile/readarray (requires bash 4+)"
else
  pass "No mapfile/readarray found"
fi

# Check for coproc
echo "Checking for coproc..."
if grep -rE '\bcoproc\b' "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found coproc (requires bash 4+)"
else
  pass "No coproc found"
fi

# Check for |& (pipe stderr)
echo "Checking for |& pipe syntax..."
if grep -rE '\|\&' "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found |& pipe syntax (requires bash 4+)"
else
  pass "No |& pipe syntax found"
fi

# Check for &>> (append stdout+stderr)
echo "Checking for &>> append syntax..."
if grep -rE '\&>>' "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found &>> append syntax (requires bash 4+)"
else
  pass "No &>> append syntax found"
fi

# Check for negative array indices
echo "Checking for negative array indices..."
if grep -rE '\$\{[^}]+\[-[0-9]+\]\}' "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found negative array indices (requires bash 4.3+)"
else
  pass "No negative array indices found"
fi

# Check for nameref (declare -n)
echo "Checking for nameref (declare -n)..."
if grep -r "declare -n" "${SCRIPTS_DIR}" 2>/dev/null; then
  fail "Found 'declare -n' (nameref requires bash 4.3+)"
else
  pass "No nameref found"
fi

echo ""
echo "=== Summary ==="
if [[ ${FAIL_COUNT} -eq 0 ]]; then
  echo "All checks passed!"
  exit 0
else
  echo "${FAIL_COUNT} check(s) failed"
  exit 1
fi
