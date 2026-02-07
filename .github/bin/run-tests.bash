#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Run all tests in src/test/

set -euo pipefail

TEST_DIR="src/test"

echo "Running tests from ${TEST_DIR}"
echo ""

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Run check-*.bash scripts
for test_script in "${TEST_DIR}"/check-*.bash; do
  if [[ ! -f "${test_script}" ]]; then
    continue
  fi

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  test_name="$(basename "${test_script}")"

  echo "========================================"
  echo "Running: ${test_name}"
  echo "========================================"

  if "${test_script}"; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo ""
    echo "[PASSED] ${test_name}"
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo ""
    echo "[FAILED] ${test_name}"
  fi

  echo ""
done

# Run bats tests if any exist
bats_files=()
while IFS= read -r -d '' file; do
  bats_files+=("$file")
done < <(find "${TEST_DIR}" -name "*.bats" -type f -print0 2>/dev/null)

if [[ ${#bats_files[@]} -gt 0 ]]; then
  if ! command -v bats &> /dev/null; then
    echo "bats not found, attempting to install..."
    if ! sudo apt-get install -y bats 2>/dev/null; then
      echo "ERROR: bats is required but could not be installed" >&2
      echo "Install with: brew install bats-core (macOS) or apt-get install bats (Linux)" >&2
      exit 1
    fi
  fi

  echo "========================================"
  echo "Running: BATS tests (${#bats_files[@]} files)"
  echo "========================================"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if bats "${bats_files[@]}"; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo ""
    echo "[PASSED] BATS tests"
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo ""
    echo "[FAILED] BATS tests"
  fi

  echo ""
fi

echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total:  ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: ${FAILED_TESTS}"

if [[ ${FAILED_TESTS} -gt 0 ]]; then
  exit 1
fi
