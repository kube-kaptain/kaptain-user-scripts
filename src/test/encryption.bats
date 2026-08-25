#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for encryption scripts

SCRIPTS_DIR="src/scripts/encryption"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"

# Setup: create a clean test directory for each test
setup() {
  TEST_DIR="${OUTPUT_SUB_PATH}/test/encryption"
  rm -rf "${TEST_DIR}"
  mkdir -p "${TEST_DIR}"
}

# Teardown: clean up test directory
teardown() {
  rm -rf "${OUTPUT_SUB_PATH}/test/encryption"
}

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
  run "${SCRIPTS_DIR}/kaptain-encrypt" --dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Directory not found"* ]]
}

@test "kaptain-encrypt: unknown option fails" {
  run "${SCRIPTS_DIR}/kaptain-encrypt" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

@test "kaptain-encrypt: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-encrypt" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
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
  run "${SCRIPTS_DIR}/kaptain-decrypt" --dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Directory not found"* ]]
}

@test "kaptain-decrypt: unknown option fails" {
  run "${SCRIPTS_DIR}/kaptain-decrypt" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

@test "kaptain-decrypt: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-decrypt" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
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

@test "kaptain-encryption-check-ignores: nonexistent directory warns and continues" {
  run "${SCRIPTS_DIR}/kaptain-encryption-check-ignores" --dir nonexistent/path
  [[ "$output" == *"WARNING: Secrets dir"* ]]
}

@test "kaptain-encryption-check-ignores: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-encryption-check-ignores" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

# Individual encrypt scripts - absolute path rejection
@test "kaptain-encrypt-age: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-encrypt-age" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-encrypt-sha256.aes256: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-encrypt-sha256.aes256.10k: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.10k" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-encrypt-sha256.aes256.100k: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.100k" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-encrypt-sha256.aes256.600k: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.600k" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

# Individual decrypt scripts - absolute path rejection
@test "kaptain-decrypt-age: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-decrypt-age" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-decrypt-sha256.aes256: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-decrypt-sha256.aes256.10k: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256.10k" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-decrypt-sha256.aes256.100k: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256.100k" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-decrypt-sha256.aes256.600k: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256.600k" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "kaptain-encryption-check-ignores: absolute path does not hang" {
  # This test verifies the fix for infinite loop with absolute paths
  # Set up fake git repo in TEST_DIR
  mkdir -p "${TEST_DIR}/.git"
  mkdir -p "${TEST_DIR}/secrets"

  # Add proper gitignore patterns
  cat > "${TEST_DIR}/.gitignore" << 'EOF'
**/*secrets/**/*.raw
**/*secrets/**/*.txt
EOF

  # Run from the fake repo root with absolute path - should complete without hanging
  # Use timeout to catch infinite loop (5 seconds is plenty)
  local exit_code=0
  timeout 5 bash -c "cd '${TEST_DIR}' && '${PWD}/${SCRIPTS_DIR}/kaptain-encryption-check-ignores' --dir '${TEST_DIR}/secrets'" || exit_code=$?

  # Timeout exits with 124 - explicitly fail with message if that happens
  if [ "${exit_code}" -eq 124 ]; then
    echo "FAIL: Script timed out - infinite loop detected with absolute path" >&2
    return 1
  fi
}

# kaptain-encryption-detect-type tests
@test "kaptain-encryption-detect-type: --help shows usage" {
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
  [[ "$output" == *"--list"* ]]
}

@test "kaptain-encryption-detect-type: unknown option fails" {
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

@test "kaptain-encryption-detect-type: --dir requires a value" {
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "kaptain-encryption-detect-type: absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path"* ]]
}

@test "kaptain-encryption-detect-type: nonexistent directory fails" {
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"Directory not found"* ]]
}

@test "kaptain-encryption-detect-type: --list prints every supported type" {
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --list
  [ "$status" -eq 0 ]

  # One line per decrypt leaf script, and every one of them present
  local expected
  expected=$(find "${SCRIPTS_DIR}" -name 'kaptain-decrypt-*' -type f | wc -l | tr -d ' ')
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq "${expected}" ]
  [[ "$output" == *"age"* ]]
  [[ "$output" == *"sha256.aes256"* ]]
  [[ "$output" == *"sha256.aes256.600k"* ]]
}

@test "kaptain-encryption-detect-type: detects a single type" {
  touch "${TEST_DIR}/secret.age"
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir "${TEST_DIR}"
  [ "$status" -eq 0 ]
  [ "$output" = "age" ]
}

@test "kaptain-encryption-detect-type: longer suffix is not confused with its prefix" {
  # sha256.aes256 is a prefix of sha256.aes256.10k - only the exact suffix counts
  touch "${TEST_DIR}/secret.sha256.aes256.10k"
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir "${TEST_DIR}"
  [ "$status" -eq 0 ]
  [ "$output" = "sha256.aes256.10k" ]
}

@test "kaptain-encryption-detect-type: detects nested files" {
  mkdir -p "${TEST_DIR}/nested"
  touch "${TEST_DIR}/nested/secret.age"
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir "${TEST_DIR}"
  [ "$status" -eq 0 ]
  [ "$output" = "age" ]
}

@test "kaptain-encryption-detect-type: mixed types fail" {
  touch "${TEST_DIR}/one.age"
  touch "${TEST_DIR}/two.sha256.aes256"
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir "${TEST_DIR}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Mixed encryption types"* ]]
}

@test "kaptain-encryption-detect-type: no encrypted files fails" {
  touch "${TEST_DIR}/plain.txt"
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir "${TEST_DIR}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No encrypted files found"* ]]
}

@test "kaptain-encryption-detect-type: --allow-none succeeds silently with nothing encrypted" {
  touch "${TEST_DIR}/plain.txt"
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir "${TEST_DIR}" --allow-none
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "kaptain-encryption-detect-type: --allow-none still reports the type when there is one" {
  touch "${TEST_DIR}/secret.age"
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir "${TEST_DIR}" --allow-none
  [ "$status" -eq 0 ]
  [ "$output" = "age" ]
}

@test "kaptain-encryption-detect-type: --allow-none does not excuse mixed types" {
  touch "${TEST_DIR}/one.age"
  touch "${TEST_DIR}/two.sha256.aes256"
  run "${SCRIPTS_DIR}/kaptain-encryption-detect-type" --dir "${TEST_DIR}" --allow-none
  [ "$status" -eq 1 ]
  [[ "$output" == *"Mixed encryption types"* ]]
}

@test "kaptain-encryption-detect-type: respects KAPTAIN_USER_SCRIPTS_SECRETS_DIR" {
  touch "${TEST_DIR}/secret.age"
  run env "KAPTAIN_USER_SCRIPTS_SECRETS_DIR=${TEST_DIR}" "${SCRIPTS_DIR}/kaptain-encryption-detect-type"
  [ "$status" -eq 0 ]
  [ "$output" = "age" ]
}
