#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for CLI scripts

SCRIPTS_DIR="src/scripts/cli"

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
