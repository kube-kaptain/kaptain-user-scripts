#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for clean scripts

CLI_SCRIPTS_DIR="src/scripts/cli"
ENC_SCRIPTS_DIR="src/scripts/encryption"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"

setup() {
  # Create test directory structure
  TEST_BIN="${OUTPUT_SUB_PATH}/test/bin"
  TEST_CLEAN="${OUTPUT_SUB_PATH}/test/clean"

  mkdir -p "${TEST_BIN}"
  mkdir -p "${TEST_CLEAN}/secrets"
  mkdir -p "${TEST_CLEAN}/my-secrets"
  mkdir -p "${TEST_CLEAN}/secrets/nested"

  # Copy clean scripts to test bin
  cp "${CLI_SCRIPTS_DIR}/kaptain-clean" "${TEST_BIN}/"
  cp "${ENC_SCRIPTS_DIR}/kaptain-clean-secrets" "${TEST_BIN}/"
}

# Helper to create simulated encryption workflow files
create_workflow_files() {
  local dir="$1"
  local basename="$2"
  local enc_type="${3:-age}"

  # Pre-encryption input
  touch "${dir}/${basename}.raw"
  # Encrypted output
  touch "${dir}/${basename}.${enc_type}"
  # Post-decryption output
  touch "${dir}/${basename}.txt"
}

# =============================================================================
# Router tests
# =============================================================================

@test "clean router: no args shows usage" {
  run "${TEST_BIN}/kaptain-clean"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"secrets"* ]]
}

@test "clean router: --help shows usage" {
  run "${TEST_BIN}/kaptain-clean" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "clean router: unknown target fails" {
  run "${TEST_BIN}/kaptain-clean" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown clean target"* ]]
}

@test "clean router: secrets target delegates" {
  run "${TEST_BIN}/kaptain-clean" secrets --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dry-run"* ]]
}

# =============================================================================
# clean-secrets argument handling
# =============================================================================

@test "clean-secrets: --help shows usage" {
  run "${TEST_BIN}/kaptain-clean-secrets" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "clean-secrets: missing --dir value fails" {
  run "${TEST_BIN}/kaptain-clean-secrets" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "clean-secrets: nonexistent directory fails" {
  run "${TEST_BIN}/kaptain-clean-secrets" --dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "clean-secrets: absolute path rejected" {
  run "${TEST_BIN}/kaptain-clean-secrets" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "clean-secrets: unknown option fails" {
  run "${TEST_BIN}/kaptain-clean-secrets" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

# =============================================================================
# clean-secrets functional tests
# =============================================================================

@test "clean-secrets: empty directory exits cleanly" {
  run "${TEST_BIN}/kaptain-clean-secrets" --dir "${TEST_CLEAN}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No .raw or .txt files found"* ]]
}

@test "clean-secrets: dry-run shows files without deleting" {
  create_workflow_files "${TEST_CLEAN}/secrets" "secret1" "age"
  create_workflow_files "${TEST_CLEAN}/secrets" "secret2" "age"

  run "${TEST_BIN}/kaptain-clean-secrets" --dir "${TEST_CLEAN}/secrets" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry run"* ]]
  [[ "$output" == *"secret1.raw"* ]]
  [[ "$output" == *"secret1.txt"* ]]
  [[ "$output" == *"secret2.raw"* ]]
  [[ "$output" == *"secret2.txt"* ]]

  # Files should still exist
  [ -f "${TEST_CLEAN}/secrets/secret1.raw" ]
  [ -f "${TEST_CLEAN}/secrets/secret1.txt" ]
  [ -f "${TEST_CLEAN}/secrets/secret1.age" ]
}

@test "clean-secrets: deletes .raw and .txt but keeps encrypted" {
  create_workflow_files "${TEST_CLEAN}/secrets" "secret1" "age"
  create_workflow_files "${TEST_CLEAN}/secrets" "secret2" "sha256.aes256"

  run "${TEST_BIN}/kaptain-clean-secrets" --dir "${TEST_CLEAN}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deleted"* ]]

  # .raw and .txt should be gone
  [ ! -f "${TEST_CLEAN}/secrets/secret1.raw" ]
  [ ! -f "${TEST_CLEAN}/secrets/secret1.txt" ]
  [ ! -f "${TEST_CLEAN}/secrets/secret2.raw" ]
  [ ! -f "${TEST_CLEAN}/secrets/secret2.txt" ]

  # Encrypted files should remain
  [ -f "${TEST_CLEAN}/secrets/secret1.age" ]
  [ -f "${TEST_CLEAN}/secrets/secret2.sha256.aes256" ]
}

@test "clean-secrets: handles nested directories" {
  create_workflow_files "${TEST_CLEAN}/secrets" "top-secret" "age"
  create_workflow_files "${TEST_CLEAN}/secrets/nested" "deep-secret" "age"

  run "${TEST_BIN}/kaptain-clean-secrets" --dir "${TEST_CLEAN}/secrets"
  [ "$status" -eq 0 ]

  # All .raw and .txt should be gone
  [ ! -f "${TEST_CLEAN}/secrets/top-secret.raw" ]
  [ ! -f "${TEST_CLEAN}/secrets/top-secret.txt" ]
  [ ! -f "${TEST_CLEAN}/secrets/nested/deep-secret.raw" ]
  [ ! -f "${TEST_CLEAN}/secrets/nested/deep-secret.txt" ]

  # Encrypted should remain
  [ -f "${TEST_CLEAN}/secrets/top-secret.age" ]
  [ -f "${TEST_CLEAN}/secrets/nested/deep-secret.age" ]
}

@test "clean-secrets: only .raw files present" {
  touch "${TEST_CLEAN}/secrets/only-raw.raw"

  run "${TEST_BIN}/kaptain-clean-secrets" --dir "${TEST_CLEAN}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 .raw file(s) and 0 .txt file(s)"* ]]
  [[ "$output" == *"Deleted 1 file(s)"* ]]

  [ ! -f "${TEST_CLEAN}/secrets/only-raw.raw" ]
}

@test "clean-secrets: only .txt files present" {
  touch "${TEST_CLEAN}/secrets/only-txt.txt"

  run "${TEST_BIN}/kaptain-clean-secrets" --dir "${TEST_CLEAN}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 .raw file(s) and 1 .txt file(s)"* ]]
  [[ "$output" == *"Deleted 1 file(s)"* ]]

  [ ! -f "${TEST_CLEAN}/secrets/only-txt.txt" ]
}

@test "clean-secrets: works with custom secrets dir name" {
  create_workflow_files "${TEST_CLEAN}/my-secrets" "custom-secret" "age"

  run "${TEST_BIN}/kaptain-clean-secrets" --dir "${TEST_CLEAN}/my-secrets"
  [ "$status" -eq 0 ]

  [ ! -f "${TEST_CLEAN}/my-secrets/custom-secret.raw" ]
  [ ! -f "${TEST_CLEAN}/my-secrets/custom-secret.txt" ]
  [ -f "${TEST_CLEAN}/my-secrets/custom-secret.age" ]
}

@test "clean-secrets: reports correct count" {
  touch "${TEST_CLEAN}/secrets/a.raw"
  touch "${TEST_CLEAN}/secrets/b.raw"
  touch "${TEST_CLEAN}/secrets/c.raw"
  touch "${TEST_CLEAN}/secrets/x.txt"
  touch "${TEST_CLEAN}/secrets/y.txt"

  run "${TEST_BIN}/kaptain-clean-secrets" --dir "${TEST_CLEAN}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 .raw file(s) and 2 .txt file(s)"* ]]
  [[ "$output" == *"Deleted 5 file(s)"* ]]
}
