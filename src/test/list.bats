#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for list scripts

CLI_SCRIPTS_DIR="src/scripts/cli"
ENC_SCRIPTS_DIR="src/scripts/encryption"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"

setup() {
  # Test directory matching bats filename
  TEST_LIST="${OUTPUT_SUB_PATH}/test/list"
  TEST_BIN="${TEST_LIST}/bin"

  # Absolute paths for --all tests that cd to different directories
  TEST_LIST_ABS="$(pwd)/${TEST_LIST}"
  TEST_BIN_ABS="$(pwd)/${TEST_BIN}"

  # Clean up from previous test runs to prevent pollution
  rm -rf "${TEST_LIST}"

  mkdir -p "${TEST_BIN}"
  mkdir -p "${TEST_LIST}/secrets"
  mkdir -p "${TEST_LIST}/secrets/nested"

  # Copy all scripts to test bin
  cp "${CLI_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
  cp "${ENC_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
}

# Helper to create files with specific timestamps
# $1 = file path, $2 = seconds offset from now (negative = older)
create_file_with_time() {
  local file="$1"
  local offset="$2"
  touch "${file}"
  # Use touch -d for relative time adjustment
  if [[ "$(uname)" == "Darwin" ]]; then
    touch -t "$(date -v${offset}S '+%Y%m%d%H%M.%S')" "${file}"
  else
    touch -d "${offset} seconds" "${file}"
  fi
}

# =============================================================================
# Router tests
# =============================================================================

@test "list router: no args shows usage" {
  run "${TEST_BIN}/kaptain-list"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"secrets"* ]]
}

@test "list router: --help shows usage" {
  run "${TEST_BIN}/kaptain-list" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "list router: unknown target fails" {
  run "${TEST_BIN}/kaptain-list" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown list target"* ]]
}

@test "list router: secrets target delegates" {
  run "${TEST_BIN}/kaptain-list" secrets --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dir"* ]]
}

# =============================================================================
# list-secrets argument handling
# =============================================================================

@test "list-secrets: --help shows usage" {
  run "${TEST_BIN}/kaptain-list-secrets" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
  [[ "$output" == *"--all"* ]]
}

@test "list-secrets: missing --dir value fails" {
  run "${TEST_BIN}/kaptain-list-secrets" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "list-secrets: nonexistent directory fails" {
  run "${TEST_BIN}/kaptain-list-secrets" --dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "list-secrets: absolute path rejected" {
  run "${TEST_BIN}/kaptain-list-secrets" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path"* ]]
}

@test "list-secrets: unknown option fails" {
  run "${TEST_BIN}/kaptain-list-secrets" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

# =============================================================================
# list-secrets functional tests - raw files
# =============================================================================

@test "list-secrets: empty directory shows no files" {
  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No raw or decrypted files found"* ]]
}

@test "list-secrets: raw without enc shows pending encryption" {
  touch "${TEST_LIST}/secrets/new-secret.raw"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pending encryption:"* ]]
  [[ "$output" == *"new-secret.raw"* ]]
  [[ "$output" == *"1 pending encryption"* ]]
}

@test "list-secrets: raw newer than enc shows pending encryption" {
  # Create enc first (older)
  touch "${TEST_LIST}/secrets/secret.age"
  sleep 1
  # Create raw after (newer)
  touch "${TEST_LIST}/secrets/secret.raw"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pending encryption:"* ]]
  [[ "$output" == *"secret.raw"* ]]
}

@test "list-secrets: raw older than enc shows stale" {
  # Create raw first (older)
  touch "${TEST_LIST}/secrets/secret.raw"
  sleep 1
  # Create enc after (newer)
  touch "${TEST_LIST}/secrets/secret.age"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stale, should remove:"* ]]
  [[ "$output" == *"secret.raw"* ]]
  [[ "$output" == *"1 stale raw"* ]]
}

# =============================================================================
# list-secrets functional tests - txt files
# =============================================================================

@test "list-secrets: txt newer than enc shows exposed current" {
  # Create enc first (older)
  touch "${TEST_LIST}/secrets/secret.age"
  sleep 1
  # Create txt after (newer)
  touch "${TEST_LIST}/secrets/secret.txt"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exposed current:"* ]]
  [[ "$output" == *"secret.txt"* ]]
  [[ "$output" == *"1 exposed"* ]]
}

@test "list-secrets: txt older than enc shows stale" {
  # Create txt first (older)
  touch "${TEST_LIST}/secrets/secret.txt"
  sleep 1
  # Create enc after (newer)
  touch "${TEST_LIST}/secrets/secret.age"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stale, should remove:"* ]]
  [[ "$output" == *"secret.txt"* ]]
  [[ "$output" == *"1 stale txt"* ]]
}

@test "list-secrets: txt without enc shows unknown" {
  touch "${TEST_LIST}/secrets/orphan.txt"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unknown files found:"* ]]
  [[ "$output" == *"orphan.txt"* ]]
}

# =============================================================================
# list-secrets functional tests - unknown files
# =============================================================================

@test "list-secrets: unknown file types listed separately" {
  touch "${TEST_LIST}/secrets/notes.md"
  touch "${TEST_LIST}/secrets/.DS_Store"
  touch "${TEST_LIST}/secrets/backup.bak"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unknown files found:"* ]]
  [[ "$output" == *"notes.md"* ]]
  [[ "$output" == *".DS_Store"* ]]
  [[ "$output" == *"backup.bak"* ]]
  [[ "$output" == *"3 unknown"* ]]
}

# =============================================================================
# list-secrets functional tests - enc file counts
# =============================================================================

@test "list-secrets: counts enc files by type" {
  touch "${TEST_LIST}/secrets/a.age"
  touch "${TEST_LIST}/secrets/b.age"
  touch "${TEST_LIST}/secrets/c.sha256.aes256"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 age"* ]]
  [[ "$output" == *"1 sha256.aes256"* ]]
}

@test "list-secrets: mixed scenario summary" {
  # Pending encryption (raw, no enc)
  touch "${TEST_LIST}/secrets/new.raw"

  # Stale raw (enc newer than raw)
  touch "${TEST_LIST}/secrets/old.raw"
  sleep 1
  touch "${TEST_LIST}/secrets/old.age"

  # Exposed txt (txt newer than enc)
  touch "${TEST_LIST}/secrets/current.age"
  sleep 1
  touch "${TEST_LIST}/secrets/current.txt"

  # Unknown file
  touch "${TEST_LIST}/secrets/readme.md"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 pending encryption"* ]]
  [[ "$output" == *"1 stale raw"* ]]
  [[ "$output" == *"1 exposed"* ]]
  [[ "$output" == *"1 unknown"* ]]
  [[ "$output" == *"2 age"* ]]
}

# =============================================================================
# list-secrets --all tests
# =============================================================================

@test "list-secrets: --all shown in help" {
  run "${TEST_BIN}/kaptain-list-secrets" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--all"* ]]
  [[ "$output" == *"branchout"* ]]
}

@test "list-secrets: --all fails when not under ~/projects/" {
  run bash -c "cd /tmp && '${TEST_BIN_ABS}/kaptain-list-secrets' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not under ~/projects/"* ]]
}

@test "list-secrets: --all fails when branchout files not found" {
  local fake_home="${TEST_LIST_ABS}/fake-home"
  mkdir -p "${fake_home}/projects/testproj/group/group-project"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-list-secrets' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Branchout root not found"* ]]
}

@test "list-secrets: --all finds branchout root and reports no projects" {
  local fake_home="${TEST_LIST_ABS}/fake-home-empty"
  mkdir -p "${fake_home}/projects/testproj/group/group-project/src"
  touch "${fake_home}/projects/testproj/Branchoutfile"
  touch "${fake_home}/projects/testproj/Branchoutprojects"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-list-secrets' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found branchout root:"* ]]
  [[ "$output" == *"No projects found with src/secrets"* ]]
}

@test "list-secrets: --all lists multiple projects" {
  local fake_home="${TEST_LIST_ABS}/fake-home-multi"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-alpha/src/secrets"
  mkdir -p "${branchout_root}/group/group-beta/src/secrets"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"

  # Add files to list
  touch "${branchout_root}/group/group-alpha/src/secrets/secret.raw"
  touch "${branchout_root}/group/group-beta/src/secrets/secret.age"

  HOME="${fake_home}" run bash -c "cd '${branchout_root}/group/group-alpha' && '${TEST_BIN_ABS}/kaptain-list-secrets' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found branchout root:"* ]]
  [[ "$output" == *"Found 2 project(s) with src/secrets"* ]]
  [[ "$output" == *"group/group-alpha"* ]]
  [[ "$output" == *"group/group-beta"* ]]
  [[ "$output" == *"Listing src/secrets in group/group-alpha"* ]]
  [[ "$output" == *"Listing src/secrets in group/group-beta"* ]]
  [[ "$output" == *"Done. Listed 2 project(s)."* ]]
}
