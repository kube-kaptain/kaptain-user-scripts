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
