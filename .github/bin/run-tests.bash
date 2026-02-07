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

echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total:  ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: ${FAILED_TESTS}"

if [[ ${FAILED_TESTS} -gt 0 ]]; then
  exit 1
fi
