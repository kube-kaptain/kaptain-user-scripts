#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for kaptain-setup router and kaptain-setup-brew leaf.
#
# Assembles all scripts into a flat directory (matching installed layout) so
# routing works. Interactive sections are not exercised here; we test the
# non-interactive surfaces: --help, flag parsing, router dispatch.

setup() {
  SCRIPTS_DIR="${BATS_TEST_TMPDIR}/scripts"
  rm -rf "${SCRIPTS_DIR}"
  mkdir -p "${SCRIPTS_DIR}"
  cp src/scripts/cli/* "${SCRIPTS_DIR}/"
  cp src/scripts/encryption/* "${SCRIPTS_DIR}/"
  cp src/scripts/util/* "${SCRIPTS_DIR}/"
  cp src/scripts/build/* "${SCRIPTS_DIR}/"
}

# Router tests

@test "kaptain-setup: no args shows usage and exits 1" {
  run "${SCRIPTS_DIR}/kaptain-setup"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: kaptain setup"* ]]
  [[ "$output" == *"Targets:"* ]]
}

@test "kaptain-setup: --help shows usage and exits 0" {
  run "${SCRIPTS_DIR}/kaptain-setup" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kaptain setup"* ]]
}

@test "kaptain-setup: -h shows usage and exits 0" {
  run "${SCRIPTS_DIR}/kaptain-setup" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kaptain setup"* ]]
}

@test "kaptain-setup: lists brew as a target" {
  run "${SCRIPTS_DIR}/kaptain-setup" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew"* ]]
}

@test "kaptain-setup: unknown target fails with error" {
  run "${SCRIPTS_DIR}/kaptain-setup" bogus-target-xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown setup target"* ]]
}

@test "kaptain-setup: dispatches to brew leaf with --help" {
  run "${SCRIPTS_DIR}/kaptain-setup" brew --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--copy-fred"* ]]
  [[ "$output" == *"--apps-in-home"* ]]
}

# Leaf tests (non-interactive surfaces)

@test "kaptain-setup-brew: --help shows flags and exits 0" {
  run "${SCRIPTS_DIR}/kaptain-setup-brew" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kaptain setup brew"* ]]
  [[ "$output" == *"--copy-fred"* ]]
  [[ "$output" == *"--apps-in-home"* ]]
}

@test "kaptain-setup-brew: -h shows flags and exits 0" {
  run "${SCRIPTS_DIR}/kaptain-setup-brew" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kaptain setup brew"* ]]
}

@test "kaptain-setup-brew: unknown flag fails with error" {
  run "${SCRIPTS_DIR}/kaptain-setup-brew" --not-a-flag
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

# Main router integration

@test "kaptain: setup subcommand dispatches to setup router" {
  run "${SCRIPTS_DIR}/kaptain" setup --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kaptain setup"* ]]
}

@test "kaptain: setup brew --help works end-to-end" {
  run "${SCRIPTS_DIR}/kaptain" setup brew --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--copy-fred"* ]]
}

# Profile block writing (drives the leaf with a sourced helper extraction)

@test "kaptain-setup-brew: managed profile block writes and replaces idempotently" {
  # Extract write_managed_block by sourcing the script up to main()
  # Easier: re-implement the awk filter logic in a sub-shell using the script.
  # We test by calling brew --help in a way that exercises the awk filter directly.
  # Skip if we cannot easily isolate. Instead, do a minimal end-to-end of the awk
  # block by writing a tiny shim that calls into the function.
  local profile="${BATS_TEST_TMPDIR}/profile"
  cat > "${profile}" <<'EOF'
# user line 1
# user line 2
EOF

  # Extract write_managed_block from leaf and call it
  local shim="${BATS_TEST_TMPDIR}/shim.bash"
  cat > "${shim}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
# Source helper definitions by extracting lines up to (but not including) main()
awk '/^main$/{exit} {print}' "${SCRIPTS_DIR}/kaptain-setup-brew" > "${BATS_TEST_TMPDIR}/lib.bash"
# Strip the trailing "main" function call wrapper if present
# shellcheck source=/dev/null
source "${BATS_TEST_TMPDIR}/lib.bash" || true
write_managed_block "${profile}" "export FOO=1" "export BAR=2"
EOF
  chmod +x "${shim}"
  run "${shim}"
  [ "$status" -eq 0 ]

  # Run again to confirm idempotent replacement
  run "${shim}"
  [ "$status" -eq 0 ]

  # File should contain user lines exactly once and exactly one block
  local user_lines block_starts block_ends foo_lines
  user_lines=$(grep -c "user line" "${profile}")
  block_starts=$(grep -c "BEGIN kaptain-setup-brew" "${profile}")
  block_ends=$(grep -c "END kaptain-setup-brew" "${profile}")
  foo_lines=$(grep -c "export FOO=1" "${profile}")
  [ "${user_lines}" -eq 2 ]
  [ "${block_starts}" -eq 1 ]
  [ "${block_ends}" -eq 1 ]
  [ "${foo_lines}" -eq 1 ]
}
