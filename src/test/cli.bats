#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for CLI scripts
#
# Assembles all scripts into a single directory (as they would be when installed)
# so that routing and help delegation work correctly.

setup() {
  SCRIPTS_DIR="${BATS_TEST_TMPDIR}/scripts"
  rm -rf "${SCRIPTS_DIR}"
  mkdir -p "${SCRIPTS_DIR}"
  # Copy all scripts into one directory, matching installed layout
  cp src/scripts/cli/* "${SCRIPTS_DIR}/"
  cp src/scripts/encryption/* "${SCRIPTS_DIR}/"
  cp src/scripts/util/* "${SCRIPTS_DIR}/"
}

# kaptain main router tests
@test "kaptain: no args shows help" {
  run "${SCRIPTS_DIR}/kaptain"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain: --help shows help" {
  run "${SCRIPTS_DIR}/kaptain" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain: -h shows help" {
  run "${SCRIPTS_DIR}/kaptain" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain: help subcommand shows help" {
  run "${SCRIPTS_DIR}/kaptain" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain: unknown subcommand fails" {
  run "${SCRIPTS_DIR}/kaptain" bogus-command-xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown subcommand"* ]]
}

# kaptain-help tests
@test "kaptain-help: shows help output" {
  run "${SCRIPTS_DIR}/kaptain-help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kaptain CLI"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-help: delegates to command --help" {
  run "${SCRIPTS_DIR}/kaptain-help" encrypt
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--type"* ]]
}

@test "kaptain-help: delegates to multi-word command --help" {
  run "${SCRIPTS_DIR}/kaptain-help" list secrets
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
}

@test "kaptain-help: delegates to router --help" {
  run "${SCRIPTS_DIR}/kaptain-help" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Targets:"* ]]
}

@test "kaptain-help: unknown command fails" {
  run "${SCRIPTS_DIR}/kaptain-help" bogus-command-xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command"* ]]
}

@test "kaptain: help encrypt delegates" {
  run "${SCRIPTS_DIR}/kaptain" help encrypt
  [ "$status" -eq 0 ]
  [[ "$output" == *"--type"* ]]
}
