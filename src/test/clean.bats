#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for clean scripts

CLI_SCRIPTS_DIR="src/scripts/cli"
ENC_SCRIPTS_DIR="src/scripts/encryption"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"

setup() {
  # Test directory matching bats filename
  TEST_CLEAN="${OUTPUT_SUB_PATH}/test/clean"
  TEST_BIN="${TEST_CLEAN}/bin"

  # Absolute paths for --all tests that cd to different directories
  TEST_CLEAN_ABS="$(pwd)/${TEST_CLEAN}"
  TEST_BIN_ABS="$(pwd)/${TEST_BIN}"

  # Clean up from previous test runs to prevent pollution
  rm -rf "${TEST_CLEAN}"

  mkdir -p "${TEST_BIN}"
  mkdir -p "${TEST_CLEAN}/secrets"
  mkdir -p "${TEST_CLEAN}/my-secrets"
  mkdir -p "${TEST_CLEAN}/secrets/nested"

  # Copy all scripts to test bin
  cp "${CLI_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
  cp "${ENC_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
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

# =============================================================================
# clean-secrets --all tests
# =============================================================================

@test "clean-secrets: --all shown in help" {
  run "${TEST_BIN}/kaptain-clean-secrets" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--all"* ]]
  [[ "$output" == *"branchout"* ]]
}

@test "clean-secrets: --all fails when not under ~/projects/" {
  # Run from /tmp which is definitely not under ~/projects/
  run bash -c "cd /tmp && '${TEST_BIN_ABS}/kaptain-clean-secrets' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not under ~/projects/"* ]]
}

@test "clean-secrets: --all fails when branchout files not found" {
  # Create a fake projects structure without branchout files
  local fake_home="${TEST_CLEAN_ABS}/fake-home"
  mkdir -p "${fake_home}/projects/testproj/group/group-project"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-clean-secrets' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Branchout root not found"* ]]
}

@test "clean-secrets: --all finds branchout root and reports no projects" {
  # Create a fake branchout structure with no secrets dirs
  local fake_home="${TEST_CLEAN_ABS}/fake-home-empty"
  mkdir -p "${fake_home}/projects/testproj/group/group-project/src"
  touch "${fake_home}/projects/testproj/Branchoutfile"
  touch "${fake_home}/projects/testproj/Branchoutprojects"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-clean-secrets' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found branchout root:"* ]]
  [[ "$output" == *"No projects found with src/secrets"* ]]
}

@test "clean-secrets: --all cleans multiple projects" {
  # Create a fake branchout structure with multiple projects
  local fake_home="${TEST_CLEAN_ABS}/fake-home-multi"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-alpha/src/secrets"
  mkdir -p "${branchout_root}/group/group-beta/src/secrets"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"

  # Add files to clean in both projects
  touch "${branchout_root}/group/group-alpha/src/secrets/secret1.raw"
  touch "${branchout_root}/group/group-alpha/src/secrets/secret1.txt"
  touch "${branchout_root}/group/group-alpha/src/secrets/secret1.age"
  touch "${branchout_root}/group/group-beta/src/secrets/secret2.raw"
  touch "${branchout_root}/group/group-beta/src/secrets/secret2.age"

  HOME="${fake_home}" run bash -c "cd '${branchout_root}/group/group-alpha' && '${TEST_BIN_ABS}/kaptain-clean-secrets' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found branchout root:"* ]]
  [[ "$output" == *"Found 2 project(s) with src/secrets"* ]]
  [[ "$output" == *"group/group-alpha"* ]]
  [[ "$output" == *"group/group-beta"* ]]
  [[ "$output" == *"Cleaning src/secrets in group/group-alpha"* ]]
  [[ "$output" == *"Cleaning src/secrets in group/group-beta"* ]]
  [[ "$output" == *"Done. Cleaned 2 project(s)."* ]]

  # Verify files were cleaned
  [ ! -f "${branchout_root}/group/group-alpha/src/secrets/secret1.raw" ]
  [ ! -f "${branchout_root}/group/group-alpha/src/secrets/secret1.txt" ]
  [ ! -f "${branchout_root}/group/group-beta/src/secrets/secret2.raw" ]

  # Encrypted files should remain
  [ -f "${branchout_root}/group/group-alpha/src/secrets/secret1.age" ]
  [ -f "${branchout_root}/group/group-beta/src/secrets/secret2.age" ]
}

@test "clean-secrets: --all with --dry-run does not delete" {
  local fake_home="${TEST_CLEAN_ABS}/fake-home-dry"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-proj/src/secrets"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"
  touch "${branchout_root}/group/group-proj/src/secrets/secret.raw"
  touch "${branchout_root}/group/group-proj/src/secrets/secret.txt"

  HOME="${fake_home}" run bash -c "cd '${branchout_root}/group/group-proj' && '${TEST_BIN_ABS}/kaptain-clean-secrets' --all --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry run"* ]]
  [[ "$output" == *"Would clean 1 project(s)"* ]]

  # Files should still exist
  [ -f "${branchout_root}/group/group-proj/src/secrets/secret.raw" ]
  [ -f "${branchout_root}/group/group-proj/src/secrets/secret.txt" ]
}

@test "clean-secrets: --all with --dir uses custom secrets path" {
  local fake_home="${TEST_CLEAN_ABS}/fake-home-custom"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-proj/config/secrets"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"
  touch "${branchout_root}/group/group-proj/config/secrets/secret.raw"

  HOME="${fake_home}" run bash -c "cd '${branchout_root}/group/group-proj' && '${TEST_BIN_ABS}/kaptain-clean-secrets' --all --dir config/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 1 project(s) with config/secrets"* ]]
  [[ "$output" == *"Cleaning config/secrets in group/group-proj"* ]]

  [ ! -f "${branchout_root}/group/group-proj/config/secrets/secret.raw" ]
}
