#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for list scripts

CLI_SCRIPTS_DIR="src/scripts/cli"
ENC_SCRIPTS_DIR="src/scripts/encryption"
UTIL_SCRIPTS_DIR="src/scripts/util"
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
  cp "${UTIL_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
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

@test "list router: config target delegates" {
  run "${TEST_BIN}/kaptain-list" config --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dir"* ]]
}

# =============================================================================
# list-config argument handling
# =============================================================================

@test "list-config: --help shows usage" {
  run "${TEST_BIN}/kaptain-list-config" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
  [[ "$output" == *"--defaults-dir"* ]]
  [[ "$output" == *"--all"* ]]
}

@test "list-config: missing --dir value fails" {
  run "${TEST_BIN}/kaptain-list-config" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "list-config: missing --defaults-dir value fails" {
  run "${TEST_BIN}/kaptain-list-config" --defaults-dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --defaults-dir requires a value"* ]]
}

@test "list-config: nonexistent directory fails" {
  run "${TEST_BIN}/kaptain-list-config" --dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"Config directory not found"* ]]
}

@test "list-config: nonexistent defaults directory fails" {
  run "${TEST_BIN}/kaptain-list-config" --defaults-dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"Defaults directory not found"* ]]
}

@test "list-config: absolute path rejected" {
  run "${TEST_BIN}/kaptain-list-config" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"--dir must be a relative path"* ]]
}

@test "list-config: defaults-dir absolute path rejected" {
  run "${TEST_BIN}/kaptain-list-config" --defaults-dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"--defaults-dir must be a relative path"* ]]
}

@test "list-config: unknown option fails" {
  run "${TEST_BIN}/kaptain-list-config" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

# =============================================================================
# list-config functional tests
# =============================================================================

@test "list-config: empty directory shows no files" {
  mkdir -p "${TEST_LIST}/config"

  run "${TEST_BIN}/kaptain-list-config" --dir "${TEST_LIST}/config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Listing ${TEST_LIST}/config:"* ]] || false
  [[ "$output" == *"No files found"* ]] || false
}

@test "list-config: neither config nor defaults dir exists fails" {
  mkdir -p "${TEST_LIST}/nothing-here"

  run bash -c "cd '${TEST_LIST_ABS}/nothing-here' && '${TEST_BIN_ABS}/kaptain-list-config'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Neither src/config nor src/defaults exists"* ]]
}

@test "list-config: defaults-only directory uses 'defaults' label" {
  mkdir -p "${TEST_LIST}/defaults-only/defaults"
  echo "image-tag-value" > "${TEST_LIST}/defaults-only/defaults/image-tag"

  run bash -c "cd '${TEST_LIST_ABS}/defaults-only' && '${TEST_BIN_ABS}/kaptain-list-config' --defaults-dir defaults"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Listing defaults:"* ]]
  [[ "$output" != *"Listing config"* ]]
  [[ "$output" == *"image-tag:"*"image-tag-value"* ]]
  [[ "$output" == *"Summary: 1 one-newline"* ]]
}

@test "list-config: both config and defaults shows dual-section output" {
  local proj="${TEST_LIST}/dual"
  mkdir -p "${proj}/config" "${proj}/defaults"
  echo "localhost" > "${proj}/config/hostname"
  echo "5432" > "${proj}/config/port"
  echo "image-tag-default" > "${proj}/defaults/image-tag"

  run bash -c "cd '${TEST_LIST_ABS}/dual' && '${TEST_BIN_ABS}/kaptain-list-config' --dir config --defaults-dir defaults"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Listing config and defaults:"* ]]
  [[ "$output" == *"[config]"* ]]
  [[ "$output" == *"[defaults]"* ]]
  [[ "$output" == *"hostname:"*"localhost"* ]]
  [[ "$output" == *"port:"*"5432"* ]]
  [[ "$output" == *"image-tag:"*"image-tag-default"* ]]
  [[ "$output" == *"Summary:"* ]]
  [[ "$output" == *"config:"*"2 one-newline"* ]]
  [[ "$output" == *"defaults:"*"1 one-newline"* ]]
  [[ "$output" == *"Total: 3 values"* ]]
}

@test "list-config: dual mode with empty defaults shows empty in summary" {
  local proj="${TEST_LIST}/dual-empty-defaults"
  mkdir -p "${proj}/config" "${proj}/defaults"
  echo "v" > "${proj}/config/k"

  run bash -c "cd '${TEST_LIST_ABS}/dual-empty-defaults' && '${TEST_BIN_ABS}/kaptain-list-config' --dir config --defaults-dir defaults"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[config]"* ]]
  [[ "$output" == *"[defaults]"* ]]
  [[ "$output" == *"No files found"* ]]
  [[ "$output" == *"defaults:"*"empty"* ]]
  [[ "$output" == *"Total: 1 values"* ]]
}

@test "list-config: KAPTAIN_USER_SCRIPTS_DEFAULTS_DIR overrides default" {
  local proj="${TEST_LIST}/env-defaults"
  mkdir -p "${proj}/my-defaults"
  echo "ev" > "${proj}/my-defaults/ek"

  run bash -c "cd '${TEST_LIST_ABS}/env-defaults' && KAPTAIN_USER_SCRIPTS_DEFAULTS_DIR=my-defaults '${TEST_BIN_ABS}/kaptain-list-config'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Listing my-defaults:"* ]]
  [[ "$output" == *"ek:"*"ev"* ]]
}

@test "list-config: single file shows name and value" {
  mkdir -p "${TEST_LIST}/config"
  echo "localhost" > "${TEST_LIST}/config/hostname"

  run "${TEST_BIN}/kaptain-list-config" --dir "${TEST_LIST}/config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Listing ${TEST_LIST}/config:"* ]] || false
  [[ "$output" == *"One newline (run kaptain normalise config to strip):"* ]] || false
  [[ "$output" == *"hostname:"*"localhost"* ]] || false
  [[ "$output" == *"1 one-newline"* ]] || false
}

@test "list-config: nested file shows relative path" {
  mkdir -p "${TEST_LIST}/config/database"
  echo "5432" > "${TEST_LIST}/config/database/port"

  run "${TEST_BIN}/kaptain-list-config" --dir "${TEST_LIST}/config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"database/port:"*"5432"* ]]
}

@test "list-config: multiple files listed" {
  mkdir -p "${TEST_LIST}/config/database"
  echo "localhost" > "${TEST_LIST}/config/hostname"
  echo "5432" > "${TEST_LIST}/config/database/port"
  echo "mydb" > "${TEST_LIST}/config/database/name"

  run "${TEST_BIN}/kaptain-list-config" --dir "${TEST_LIST}/config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hostname:"*"localhost"* ]]
  [[ "$output" == *"database/port:"*"5432"* ]]
  [[ "$output" == *"database/name:"*"mydb"* ]]
  [[ "$output" == *"3 one-newline"* ]]
}

@test "list-config: newline categories" {
  mkdir -p "${TEST_LIST}/config"
  printf "no-trailing-newline" > "${TEST_LIST}/config/no-nl"
  echo "one-newline-value" > "${TEST_LIST}/config/one-nl"
  printf "line1\nline2\n" > "${TEST_LIST}/config/two-nl"
  printf "line1\nline2\nline3\nline4\n" > "${TEST_LIST}/config/multi"

  run "${TEST_BIN}/kaptain-list-config" --dir "${TEST_LIST}/config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No newline (usually correct):"* ]]
  [[ "$output" == *"no-nl:"*"no-trailing-newline"* ]]
  [[ "$output" == *"One newline (run kaptain normalise config to strip):"* ]]
  [[ "$output" == *"one-nl:"*"one-newline-value"* ]]
  [[ "$output" == *"Multiline (cat <file> to inspect):"* ]]
  [[ "$output" == *"two-nl:"*"2 lines"* ]]
  [[ "$output" == *"multi:"*"4 lines"* ]]
  [[ "$output" == *"1 no-newline"* ]]
  [[ "$output" == *"1 one-newline"* ]]
  [[ "$output" == *"2 multiline"* ]]
  # Verify comma-space separation in summary
  [[ "$output" == *"1 no-newline, 1 one-newline, 2 multiline"* ]]
}

@test "list-config: one-newline-mid-file classified as Multiline, not One newline" {
  # A two-line file with no trailing newline has newline_count == 1 but the
  # newline is mid-file, so it is actually a multi-line value, not a strippable
  # trailing-newline file. Stripping it would lose data.
  mkdir -p "${TEST_LIST}/config"
  printf 'line1\nline2' > "${TEST_LIST}/config/mid-nl"

  run "${TEST_BIN}/kaptain-list-config" --dir "${TEST_LIST}/config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Multiline (cat <file> to inspect):"* ]]
  [[ "$output" == *"mid-nl:"*"1 lines"* ]]
  [[ "$output" != *"One newline (run kaptain normalise config to strip):"* ]]
  [[ "$output" == *"1 multiline"* ]]
}

@test "list-config: works with custom dir" {
  mkdir -p "${TEST_LIST}/my-config"
  echo "custom-value" > "${TEST_LIST}/my-config/key"

  run "${TEST_BIN}/kaptain-list-config" --dir "${TEST_LIST}/my-config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Listing ${TEST_LIST}/my-config:"* ]] || false
  [[ "$output" == *"key:"*"custom-value"* ]] || false
}

# =============================================================================
# list-config --all tests
# =============================================================================

@test "list-config: --all fails when not under projects directory" {
  run bash -c "cd /tmp && '${TEST_BIN_ABS}/kaptain-list-config' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot find branchout tree"* ]]
}

@test "list-config: --all fails when branchout files not found" {
  local fake_home="${TEST_LIST_ABS}/fake-home-config"
  mkdir -p "${fake_home}/projects/testproj/group/group-project"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-list-config' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Branchout root not found"* ]]
}

@test "list-config: --all finds branchout root and reports no projects" {
  local fake_home="${TEST_LIST_ABS}/fake-home-config-empty"
  mkdir -p "${fake_home}/projects/testproj/group/group-project/src"
  touch "${fake_home}/projects/testproj/Branchoutfile"
  touch "${fake_home}/projects/testproj/Branchoutprojects"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-list-config' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found branchout root:"* ]]
  [[ "$output" == *"No projects found with src/config"* ]]
}

@test "list-config: --all lists multiple projects" {
  local fake_home="${TEST_LIST_ABS}/fake-home-config-multi"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-alpha/src/config"
  mkdir -p "${branchout_root}/group/group-beta/src/config"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"

  # Add config files
  echo "localhost" > "${branchout_root}/group/group-alpha/src/config/hostname"
  printf "5432" > "${branchout_root}/group/group-beta/src/config/port"

  HOME="${fake_home}" run bash -c "cd '${branchout_root}/group/group-alpha' && '${TEST_BIN_ABS}/kaptain-list-config' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found branchout root:"* ]]
  [[ "$output" == *"Found 2 project(s) with src/config"* ]]
  [[ "$output" == *"group/group-alpha"* ]]
  [[ "$output" == *"group/group-beta"* ]]
  [[ "$output" == *"Listing src/config in group/group-alpha:"* ]]
  [[ "$output" == *"Listing src/config in group/group-beta:"* ]]
  [[ "$output" == *"hostname:"*"localhost"* ]]
  [[ "$output" == *"port:"*"5432"* ]]
  [[ "$output" == *"Done. Listed 2 project(s)."* ]]
}

@test "list-config: --all mixed config-only and defaults-only projects" {
  local fake_home="${TEST_LIST_ABS}/fake-home-config-mixed"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-alpha/src/config"
  mkdir -p "${branchout_root}/group/group-beta/src/defaults"
  mkdir -p "${branchout_root}/group/group-gamma/src/config"
  mkdir -p "${branchout_root}/group/group-gamma/src/defaults"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"

  echo "alpha-host" > "${branchout_root}/group/group-alpha/src/config/hostname"
  echo "beta-tag" > "${branchout_root}/group/group-beta/src/defaults/image-tag"
  echo "gamma-host" > "${branchout_root}/group/group-gamma/src/config/hostname"
  echo "gamma-tag" > "${branchout_root}/group/group-gamma/src/defaults/image-tag"

  HOME="${fake_home}" run bash -c "cd '${branchout_root}/group/group-alpha' && '${TEST_BIN_ABS}/kaptain-list-config' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 3 project(s) with src/config or src/defaults"* ]]
  [[ "$output" == *"group/group-alpha"* ]]
  [[ "$output" == *"group/group-beta"* ]]
  [[ "$output" == *"group/group-gamma"* ]]
  # Config-only project: "Listing src/config in group/group-alpha"
  [[ "$output" == *"Listing src/config in group/group-alpha:"* ]]
  [[ "$output" == *"hostname:"*"alpha-host"* ]]
  # Defaults-only project: "Listing src/defaults in group/group-beta"
  [[ "$output" == *"Listing src/defaults in group/group-beta:"* ]]
  [[ "$output" == *"image-tag:"*"beta-tag"* ]]
  # Dual-section project: "Listing src/config and src/defaults in group/group-gamma"
  [[ "$output" == *"Listing src/config and src/defaults in group/group-gamma:"* ]]
  [[ "$output" == *"hostname:"*"gamma-host"* ]]
  [[ "$output" == *"image-tag:"*"gamma-tag"* ]]
  [[ "$output" == *"Done. Listed 3 project(s)."* ]]
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
  [[ "$output" == *"--verbose"* ]]
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
  [[ "$output" == *"No raw, decrypted, or encrypted files found"* ]]
}

@test "list-secrets: raw without enc shows pending encryption" {
  touch "${TEST_LIST}/secrets/new-secret.raw"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pending encryption:"* ]]
  [[ "$output" == *"new-secret.raw"* ]]
  [[ "$output" == *"1 pending encryption"* ]]
  [[ "$output" == *"0 encrypted"* ]]
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

@test "list-secrets: txt without enc shows orphaned txt" {
  touch "${TEST_LIST}/secrets/orphan.txt"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orphaned txt files"* ]]
  [[ "$output" == *"orphan.txt"* ]]
  [[ "$output" == *"1 orphaned txt"* ]]
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

@test "list-secrets: single enc type shows no warning" {
  touch "${TEST_LIST}/secrets/a.age"
  touch "${TEST_LIST}/secrets/b.age"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 age"* ]]
  [[ "$output" != *"WARNING"* ]]
}

@test "list-secrets: mixed enc types shows warning" {
  touch "${TEST_LIST}/secrets/a.age"
  touch "${TEST_LIST}/secrets/b.age"
  touch "${TEST_LIST}/secrets/c.sha256.aes256"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: Mixed encryption types found"* ]]
  [[ "$output" == *"2 age"* ]]
  [[ "$output" == *"1 sha256.aes256"* ]]
  [[ "$output" == *"kaptain encrypt --type"* ]]
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
# list-secrets --verbose tests
# =============================================================================

@test "list-secrets: verbose lists encrypted files" {
  touch "${TEST_LIST}/secrets/a.age"
  touch "${TEST_LIST}/secrets/b.age"
  touch "${TEST_LIST}/secrets/nested/c.age"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets" --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"Encrypted files:"* ]]
  [[ "$output" == *"age:"* ]]
  [[ "$output" == *"a.age"* ]]
  [[ "$output" == *"b.age"* ]]
  [[ "$output" == *"c.age"* ]]
}

@test "list-secrets: without verbose does not list encrypted files" {
  touch "${TEST_LIST}/secrets/a.age"
  touch "${TEST_LIST}/secrets/b.age"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Encrypted files:"* ]]
  [[ "$output" == *"2 age"* ]]
}

@test "list-secrets: verbose with -v shorthand" {
  touch "${TEST_LIST}/secrets/a.age"

  run "${TEST_BIN}/kaptain-list-secrets" --dir "${TEST_LIST}/secrets" -v
  [ "$status" -eq 0 ]
  [[ "$output" == *"Encrypted files:"* ]]
  [[ "$output" == *"a.age"* ]]
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

@test "list-secrets: --all fails when not under projects directory" {
  run bash -c "cd /tmp && '${TEST_BIN_ABS}/kaptain-list-secrets' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot find branchout tree"* ]]
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

# =============================================================================
# list-secrets --all tests
# =============================================================================

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

  # Paths should show key name only, not full or partial path
  [[ "$output" == *"secret.raw"* ]]
  [[ "$output" != *"src/secrets/secret.raw"* ]]
}

# =============================================================================
# list-manifests router
# =============================================================================

@test "list router: manifests target delegates" {
  run "${TEST_BIN}/kaptain-list" manifests --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dir"* ]]
}

# =============================================================================
# list-manifests argument handling
# =============================================================================

@test "list-manifests: --help shows usage" {
  run "${TEST_BIN}/kaptain-list-manifests" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
  [[ "$output" == *"--all"* ]]
}

@test "list-manifests: missing --dir value fails" {
  run "${TEST_BIN}/kaptain-list-manifests" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "list-manifests: nonexistent directory fails" {
  run "${TEST_BIN}/kaptain-list-manifests" --dir no/such/dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Manifests directory not found"* ]]
}

@test "list-manifests: absolute path rejected" {
  run "${TEST_BIN}/kaptain-list-manifests" --dir /tmp/nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir must be a relative path"* ]]
}

@test "list-manifests: unknown option fails" {
  run "${TEST_BIN}/kaptain-list-manifests" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

# =============================================================================
# list-manifests functionality
# =============================================================================

@test "list-manifests: empty directory shows no files" {
  mkdir -p "${TEST_LIST}/manifests-empty"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/manifests-empty"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No manifest files found"* ]]
}

@test "list-manifests: valid yaml shows line count" {
  mkdir -p "${TEST_LIST}/manifests-valid"
  printf 'apiVersion: v1\nkind: Service\nmetadata:\n  name: test\n' > "${TEST_LIST}/manifests-valid/service.yaml"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/manifests-valid"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Valid:"* ]]
  [[ "$output" == *"service.yaml"* ]]
  [[ "$output" == *"4 lines"* ]]
  [[ "$output" == *"Summary: 1 valid"* ]]
}

@test "list-manifests: nested files show relative path" {
  mkdir -p "${TEST_LIST}/manifests-nested/base"
  printf 'line1\nline2\n' > "${TEST_LIST}/manifests-nested/base/deploy.yaml"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/manifests-nested"
  [ "$status" -eq 0 ]
  [[ "$output" == *"base/deploy.yaml"* ]]
  [[ "$output" == *"2 lines"* ]]
}

@test "list-manifests: yml files shown as invalid with wrong suffix" {
  mkdir -p "${TEST_LIST}/manifests-yml"
  printf 'a\n' > "${TEST_LIST}/manifests-yml/ingress.yml"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/manifests-yml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid:"* ]]
  [[ "$output" == *"ingress.yml"* ]]
  [[ "$output" == *"wrong suffix"* ]]
  [[ "$output" == *"Summary: 1 invalid"* ]]
}

@test "list-manifests: uppercase yaml shown as invalid" {
  mkdir -p "${TEST_LIST}/manifests-upper"
  printf 'a\n' > "${TEST_LIST}/manifests-upper/Deployment.yaml"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/manifests-upper"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid:"* ]]
  [[ "$output" == *"Deployment.yaml"* ]]
  [[ "$output" == *"uppercase in name"* ]]
}

@test "list-manifests: uppercase yml shows both reasons" {
  mkdir -p "${TEST_LIST}/manifests-both"
  printf 'a\n' > "${TEST_LIST}/manifests-both/Omg.yml"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/manifests-both"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Omg.yml"* ]]
  [[ "$output" == *"wrong suffix, uppercase in name"* ]]
}

@test "list-manifests: non-yaml files shown as not a manifest" {
  mkdir -p "${TEST_LIST}/manifests-other"
  printf 'hello\n' > "${TEST_LIST}/manifests-other/README.md"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/manifests-other"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid:"* ]]
  [[ "$output" == *"README.md"* ]]
  [[ "$output" == *"not a manifest"* ]]
}

@test "list-manifests: mixed valid and invalid" {
  mkdir -p "${TEST_LIST}/manifests-mixed"
  printf 'a\nb\nc\n' > "${TEST_LIST}/manifests-mixed/deployment.yaml"
  printf 'a\n' > "${TEST_LIST}/manifests-mixed/service.yml"
  printf 'a\n' > "${TEST_LIST}/manifests-mixed/ConfigMap.yaml"
  printf 'a\n' > "${TEST_LIST}/manifests-mixed/notes.txt"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/manifests-mixed"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Valid:"* ]]
  [[ "$output" == *"deployment.yaml"* ]]
  [[ "$output" == *"3 lines"* ]]
  [[ "$output" == *"Invalid:"* ]]
  [[ "$output" == *"service.yml"* ]]
  [[ "$output" == *"wrong suffix"* ]]
  [[ "$output" == *"ConfigMap.yaml"* ]]
  [[ "$output" == *"uppercase in name"* ]]
  [[ "$output" == *"notes.txt"* ]]
  [[ "$output" == *"not a manifest"* ]]
  [[ "$output" == *"Summary: 1 valid, 3 invalid"* ]]
}

@test "list-manifests: works with custom dir" {
  mkdir -p "${TEST_LIST}/custom-k8s"
  printf 'line\n' > "${TEST_LIST}/custom-k8s/pod.yaml"
  run "${TEST_BIN}/kaptain-list-manifests" --dir "${TEST_LIST}/custom-k8s"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pod.yaml"* ]]
}

# =============================================================================
# list-manifests --all tests
# =============================================================================

@test "list-manifests: --all shown in help" {
  run "${TEST_BIN}/kaptain-list-manifests" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--all"* ]]
}

@test "list-manifests: --all fails when not under projects directory" {
  run bash -c "cd /tmp && '${TEST_BIN_ABS}/kaptain-list-manifests' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot find branchout tree"* ]]
}

@test "list-manifests: --all fails when branchout files not found" {
  local fake_home="${TEST_LIST_ABS}/fake-home-manifests-nobo"
  mkdir -p "${fake_home}/projects/testproj/group/group-project"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-list-manifests' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Branchout root not found"* ]]
}

@test "list-manifests: --all finds branchout root and reports no projects" {
  local fake_home="${TEST_LIST_ABS}/fake-home-manifests-empty"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-project"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-list-manifests' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No projects found with src/kubernetes"* ]]
}

@test "list-manifests: --all lists multiple projects" {
  local fake_home="${TEST_LIST_ABS}/fake-home-manifests-multi"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-alpha/src/kubernetes"
  mkdir -p "${branchout_root}/group/group-beta/src/kubernetes"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"

  printf 'a\nb\nc\n' > "${branchout_root}/group/group-alpha/src/kubernetes/deploy.yaml"
  printf 'x\n' > "${branchout_root}/group/group-beta/src/kubernetes/service.yaml"

  HOME="${fake_home}" run bash -c "cd '${branchout_root}/group/group-alpha' && '${TEST_BIN_ABS}/kaptain-list-manifests' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found branchout root:"* ]]
  [[ "$output" == *"Found 2 project(s) with src/kubernetes"* ]]
  [[ "$output" == *"group/group-alpha"* ]]
  [[ "$output" == *"group/group-beta"* ]]
  [[ "$output" == *"Listing src/kubernetes in group/group-alpha"* ]]
  [[ "$output" == *"Listing src/kubernetes in group/group-beta"* ]]
  [[ "$output" == *"Valid:"* ]]
  [[ "$output" == *"deploy.yaml"* ]]
  [[ "$output" == *"3 lines"* ]]
  [[ "$output" == *"service.yaml"* ]]
  [[ "$output" == *"1 lines"* ]]
  [[ "$output" == *"Done. Listed 2 project(s)."* ]]
}
