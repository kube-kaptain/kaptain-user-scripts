#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for encryption scripts

SCRIPTS_DIR="src/scripts/encryption"

# kaptain-encrypt router tests
@test "kaptain-encrypt: --help shows usage" {
  run "${SCRIPTS_DIR}/kaptain-encrypt" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--type"* ]]
  [[ "$output" == *"--dir"* ]]
}

@test "kaptain-encrypt: missing --dir value fails" {
  run "${SCRIPTS_DIR}/kaptain-encrypt" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "kaptain-encrypt: missing --type value fails" {
  run "${SCRIPTS_DIR}/kaptain-encrypt" --type
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --type requires a value"* ]]
}

@test "kaptain-encrypt: nonexistent directory fails" {
  run "${SCRIPTS_DIR}/kaptain-encrypt" --dir /nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Directory not found"* ]]
}

@test "kaptain-encrypt: unknown option fails" {
  run "${SCRIPTS_DIR}/kaptain-encrypt" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

# kaptain-decrypt router tests
@test "kaptain-decrypt: --help shows usage" {
  run "${SCRIPTS_DIR}/kaptain-decrypt" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--type"* ]]
  [[ "$output" == *"--dir"* ]]
}

@test "kaptain-decrypt: missing --dir value fails" {
  run "${SCRIPTS_DIR}/kaptain-decrypt" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "kaptain-decrypt: missing --type value fails" {
  run "${SCRIPTS_DIR}/kaptain-decrypt" --type
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --type requires a value"* ]]
}

@test "kaptain-decrypt: nonexistent directory fails" {
  run "${SCRIPTS_DIR}/kaptain-decrypt" --dir /nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Directory not found"* ]]
}

@test "kaptain-decrypt: unknown option fails" {
  run "${SCRIPTS_DIR}/kaptain-decrypt" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

# kaptain-keygen tests
@test "kaptain-keygen: --help shows usage" {
  run "${SCRIPTS_DIR}/kaptain-keygen" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--type"* ]]
}

@test "kaptain-keygen: -h shows usage" {
  run "${SCRIPTS_DIR}/kaptain-keygen" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-keygen: missing --type value fails" {
  run "${SCRIPTS_DIR}/kaptain-keygen" --type
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --type requires a value"* ]]
}

@test "kaptain-keygen: invalid type fails" {
  run "${SCRIPTS_DIR}/kaptain-keygen" --type bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown type"* ]]
}

@test "kaptain-keygen: unknown option fails" {
  run "${SCRIPTS_DIR}/kaptain-keygen" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

@test "kaptain-keygen: plain type generates 40 char hex key" {
  run "${SCRIPTS_DIR}/kaptain-keygen" --type plain
  [ "$status" -eq 0 ]
  # Output contains a 40 char hex key somewhere
  [[ "$output" =~ [0-9a-f]{40} ]]
}

@test "kaptain-keygen: age type generates AGE-SECRET-KEY" {
  if ! command -v age-keygen &> /dev/null; then
    skip "age-keygen not installed"
  fi
  run "${SCRIPTS_DIR}/kaptain-keygen" --type age
  [ "$status" -eq 0 ]
  [[ "$output" == *"AGE-SECRET-KEY-"* ]]
}

# kaptain-encryption-check-ignores tests
@test "kaptain-encryption-check-ignores: missing --dir value fails" {
  run "${SCRIPTS_DIR}/kaptain-encryption-check-ignores" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "kaptain-encryption-check-ignores: unknown option fails" {
  run "${SCRIPTS_DIR}/kaptain-encryption-check-ignores" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

@test "kaptain-encryption-check-ignores: nonexistent directory fails" {
  run "${SCRIPTS_DIR}/kaptain-encryption-check-ignores" --dir /nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Secrets dir"* ]]
}

@test "kaptain-encryption-check-ignores: absolute path does not hang" {
  # This test verifies the fix for infinite loop with absolute paths
  # Create a temp directory structure with absolute path
  TEST_REPO=$(mktemp -d)

  # Set up fake git repo
  mkdir -p "${TEST_REPO}/.git"
  mkdir -p "${TEST_REPO}/secrets"

  # Add proper gitignore patterns
  cat > "${TEST_REPO}/.gitignore" << 'EOF'
**/*secrets/*.raw
**/*secrets/*.txt
EOF

  # Run from the fake repo root with absolute path - should complete without hanging
  # Use timeout to catch infinite loop (5 seconds is plenty)
  local exit_code=0
  timeout 5 bash -c "cd '${TEST_REPO}' && '${PWD}/${SCRIPTS_DIR}/kaptain-encryption-check-ignores' --dir '${TEST_REPO}/secrets'" || exit_code=$?

  # Cleanup
  rm -rf "${TEST_REPO}"

  # Timeout exits with 124 - explicitly fail with message if that happens
  if [ "${exit_code}" -eq 124 ]; then
    echo "FAIL: Script timed out - infinite loop detected with absolute path" >&2
    return 1
  fi
}
