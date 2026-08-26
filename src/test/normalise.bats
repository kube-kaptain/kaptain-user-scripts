#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for normalise scripts

CLI_SCRIPTS_DIR="src/scripts/cli"
ENC_SCRIPTS_DIR="src/scripts/encryption"
UTIL_SCRIPTS_DIR="src/scripts/util"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"

setup() {
  TEST_NORM="${OUTPUT_SUB_PATH}/test/normalise"
  TEST_BIN="${TEST_NORM}/bin"
  TEST_NORM_ABS="$(pwd)/${TEST_NORM}"
  TEST_BIN_ABS="$(pwd)/${TEST_BIN}"

  rm -rf "${TEST_NORM}"

  mkdir -p "${TEST_BIN}"
  mkdir -p "${TEST_NORM}/src/config"
  mkdir -p "${TEST_NORM}/src/defaults"

  cp "${CLI_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
  cp "${ENC_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
  cp "${UTIL_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
}

# =============================================================================
# Router tests
# =============================================================================

@test "normalise router: no args shows usage" {
  run "${TEST_BIN}/kaptain-normalise"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"config"* ]]
}

@test "normalise router: --help shows usage" {
  run "${TEST_BIN}/kaptain-normalise" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "normalise router: unknown target fails" {
  run "${TEST_BIN}/kaptain-normalise" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown normalise target"* ]]
}

@test "normalise router: config target delegates" {
  run "${TEST_BIN}/kaptain-normalise" config --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dry-run"* ]]
}

# =============================================================================
# normalise-config argument handling
# =============================================================================

@test "normalise-config: --help shows usage" {
  run "${TEST_BIN}/kaptain-normalise-config" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
  [[ "$output" == *"--defaults-dir"* ]]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--all"* ]]
}

@test "normalise-config: missing --dir value fails" {
  run "${TEST_BIN}/kaptain-normalise-config" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "normalise-config: missing --defaults-dir value fails" {
  run "${TEST_BIN}/kaptain-normalise-config" --defaults-dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --defaults-dir requires a value"* ]]
}

@test "normalise-config: nonexistent --dir fails" {
  run "${TEST_BIN}/kaptain-normalise-config" --dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "normalise-config: absolute --dir rejected" {
  run "${TEST_BIN}/kaptain-normalise-config" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "normalise-config: absolute --defaults-dir rejected" {
  run "${TEST_BIN}/kaptain-normalise-config" --defaults-dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path, i.e. a sub path of this repo"* ]]
}

@test "normalise-config: unknown option fails" {
  run "${TEST_BIN}/kaptain-normalise-config" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "normalise-config: errors when neither dir exists" {
  rm -rf "${TEST_NORM}/src/config" "${TEST_NORM}/src/defaults"
  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Neither src/config nor src/defaults exists"* ]]
}

# =============================================================================
# normalise-config functional tests
# =============================================================================

@test "normalise-config: empty dirs exit cleanly" {
  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No files found"* ]]
  [[ "$output" == *"Normalised 0 files"* ]]
}

@test "normalise-config: strips trailing newline from one-newline file" {
  printf 'value\n' > "${TEST_NORM}/src/config/a"

  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"normalised: src/config/a"* ]]
  [[ "$output" == *"Normalised 1 file."* ]]

  # File should now have no trailing newline
  [ "$(wc -c < "${TEST_NORM}/src/config/a" | tr -d '[:space:]')" -eq 5 ]
  [ "$(cat "${TEST_NORM}/src/config/a")" = "value" ]
}

@test "normalise-config: leaves no-newline file alone" {
  printf 'value' > "${TEST_NORM}/src/config/a"
  local before
  before="$(wc -c < "${TEST_NORM}/src/config/a" | tr -d '[:space:]')"

  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"normalised: src/config/a"* ]]
  [[ "$output" == *"Normalised 0 files"* ]]

  [ "$(wc -c < "${TEST_NORM}/src/config/a" | tr -d '[:space:]')" -eq "${before}" ]
}

@test "normalise-config: leaves multi-newline file alone (2 newlines)" {
  printf 'line1\nline2\n' > "${TEST_NORM}/src/config/a"
  local before
  before="$(wc -c < "${TEST_NORM}/src/config/a" | tr -d '[:space:]')"

  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"normalised: src/config/a"* ]]
  [[ "$output" == *"and 1 multi-newline files alone"* ]]

  [ "$(wc -c < "${TEST_NORM}/src/config/a" | tr -d '[:space:]')" -eq "${before}" ]
}

@test "normalise-config: leaves multi-newline file alone (3 trailing newlines)" {
  printf 'value\n\n\n' > "${TEST_NORM}/src/config/a"
  local before
  before="$(wc -c < "${TEST_NORM}/src/config/a" | tr -d '[:space:]')"

  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"normalised: src/config/a"* ]]
  [[ "$output" == *"and 1 multi-newline files alone"* ]]

  [ "$(wc -c < "${TEST_NORM}/src/config/a" | tr -d '[:space:]')" -eq "${before}" ]
}

@test "normalise-config: treats one-newline-mid-file as multi-line (not strippable)" {
  # Two-line file with no trailing newline: "valu\ne" has newline_count == 1
  # but the newline is mid-file. Must not be treated as a strippable file.
  printf 'valu\ne' > "${TEST_NORM}/src/config/two-line"
  local before
  before="$(wc -c < "${TEST_NORM}/src/config/two-line" | tr -d '[:space:]')"

  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"normalised: src/config/two-line"* ]]
  [[ "$output" == *"and 1 multi-newline files alone"* ]]

  [ "$(wc -c < "${TEST_NORM}/src/config/two-line" | tr -d '[:space:]')" -eq "${before}" ]
}

@test "normalise-config: --dry-run does not write" {
  printf 'value\n' > "${TEST_NORM}/src/config/a"

  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would normalise: src/config/a"* ]]
  [[ "$output" == *"Dry run"* ]]

  # File still has trailing newline
  [ "$(wc -c < "${TEST_NORM}/src/config/a" | tr -d '[:space:]')" -eq 6 ]
}

@test "normalise-config: processes both config and defaults dirs" {
  printf 'one\n' > "${TEST_NORM}/src/config/a"
  printf 'two\n' > "${TEST_NORM}/src/defaults/b"

  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[src/config]"* ]]
  [[ "$output" == *"[src/defaults]"* ]]
  [[ "$output" == *"normalised: src/config/a"* ]]
  [[ "$output" == *"normalised: src/defaults/b"* ]]
  [[ "$output" == *"Normalised 2 files"* ]]

  [ "$(cat "${TEST_NORM}/src/config/a")" = "one" ]
  [ "$(cat "${TEST_NORM}/src/defaults/b")" = "two" ]
}

@test "normalise-config: handles mixed categories in one run" {
  printf 'fix-me\n' > "${TEST_NORM}/src/config/one-nl"
  printf 'already-fine' > "${TEST_NORM}/src/config/no-nl"
  printf 'a\nb\n' > "${TEST_NORM}/src/config/multi"

  run bash -c "cd '${TEST_NORM_ABS}' && '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Normalised 1 file."* ]]
  [[ "$output" == *"and 1 multi-newline files alone"* ]]

  [ "$(cat "${TEST_NORM}/src/config/one-nl")" = "fix-me" ]
  [ "$(cat "${TEST_NORM}/src/config/no-nl")" = "already-fine" ]
  [ "$(cat "${TEST_NORM}/src/config/multi")" = "$(printf 'a\nb')" ]
}

@test "normalise-config: respects KAPTAIN_USER_SCRIPTS_CONFIG_DIR env var" {
  mkdir -p "${TEST_NORM}/custom-cfg"
  printf 'value\n' > "${TEST_NORM}/custom-cfg/x"
  rm -rf "${TEST_NORM}/src"

  KAPTAIN_USER_SCRIPTS_CONFIG_DIR=custom-cfg run bash -c "cd '${TEST_NORM_ABS}' && KAPTAIN_USER_SCRIPTS_CONFIG_DIR=custom-cfg '${TEST_BIN_ABS}/kaptain-normalise-config'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"normalised: custom-cfg/x"* ]]

  [ "$(cat "${TEST_NORM}/custom-cfg/x")" = "value" ]
}

# =============================================================================
# --all tests
# =============================================================================

@test "normalise-config: --all fails when not under projects directory" {
  run bash -c "cd /tmp && '${TEST_BIN_ABS}/kaptain-normalise-config' --all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot find branchout tree"* ]]
}

@test "normalise-config: --all finds branchout root and reports no projects" {
  local fake_home="${TEST_NORM_ABS}/fake-home-empty"
  mkdir -p "${fake_home}/projects/testproj/group/group-project/src"
  touch "${fake_home}/projects/testproj/Branchoutfile"
  touch "${fake_home}/projects/testproj/Branchoutprojects"

  HOME="${fake_home}" run bash -c "cd '${fake_home}/projects/testproj/group/group-project' && '${TEST_BIN_ABS}/kaptain-normalise-config' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found branchout root:"* ]]
  [[ "$output" == *"No projects found with src/config or src/defaults"* ]]
}

@test "normalise-config: --all normalises across multiple projects" {
  local fake_home="${TEST_NORM_ABS}/fake-home-multi"
  local branchout_root="${fake_home}/projects/testproj"

  mkdir -p "${branchout_root}/group/group-alpha/src/config"
  mkdir -p "${branchout_root}/group/group-beta/src/defaults"
  touch "${branchout_root}/Branchoutfile"
  touch "${branchout_root}/Branchoutprojects"

  printf 'alpha-val\n' > "${branchout_root}/group/group-alpha/src/config/key"
  printf 'beta-val\n' > "${branchout_root}/group/group-beta/src/defaults/key"

  HOME="${fake_home}" run bash -c "cd '${branchout_root}/group/group-alpha' && '${TEST_BIN_ABS}/kaptain-normalise-config' --all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 2 project(s)"* ]]
  [[ "$output" == *"group/group-alpha"* ]]
  [[ "$output" == *"group/group-beta"* ]]
  [[ "$output" == *"Normalised 2 files"* ]]

  [ "$(cat "${branchout_root}/group/group-alpha/src/config/key")" = "alpha-val" ]
  [ "$(cat "${branchout_root}/group/group-beta/src/defaults/key")" = "beta-val" ]
}

# =============================================================================
# normalise secrets
# =============================================================================

SECRETS_PASSPHRASE="test-passphrase-for-ci-only"

# Build a secrets dir with one token of each category, encrypted and committed.
# The script refuses to rewrite ciphertext that is not accounted for in git, and
# resolves git from its working directory, so this is a throwaway repo that the
# tests run inside.
setup_secrets_repo() {
  mkdir -p "${TEST_NORM}/secrets/nested"
  printf 'no-newline-value'     > "${TEST_NORM}/secrets/canonical.raw"
  printf 'one-newline-value\n'  > "${TEST_NORM}/secrets/needs-strip.raw"
  printf 'multi\nline\nvalue\n' > "${TEST_NORM}/secrets/multi.raw"
  printf 'nested-one\n'         > "${TEST_NORM}/secrets/nested/deep.raw"

  ( cd "${TEST_NORM}" && printf '%s\n' "${SECRETS_PASSPHRASE}" \
      | "${TEST_BIN_ABS}/kaptain-encrypt-sha256.aes256" --dir secrets ) > /dev/null
  find "${TEST_NORM}/secrets" -name '*.raw' -delete

  git -C "${TEST_NORM}" init -q
  git -C "${TEST_NORM}" config user.email "test@example.com"
  git -C "${TEST_NORM}" config user.name "Kaptain Test"
  git -C "${TEST_NORM}" config commit.gpgsign false
  git -C "${TEST_NORM}" add -A -f secrets
  git -C "${TEST_NORM}" commit -q -m "encrypted"
}

# Decrypt everything and echo one token's value with a sentinel so trailing
# newlines survive command substitution
token_value() {
  ( cd "${TEST_NORM}" && printf '%s\n' "${SECRETS_PASSPHRASE}" \
      | "${TEST_BIN_ABS}/kaptain-decrypt-sha256.aes256" --dir secrets ) > /dev/null
  local raw
  raw="$(cat "${TEST_NORM}/secrets/$1.txt"; printf X)"
  find "${TEST_NORM}/secrets" -name '*.txt' -delete
  printf '%s' "${raw%X}"
}

@test "normalise secrets: --help shows usage" {
  run "${TEST_BIN}/kaptain-normalise-secrets" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "normalise secrets: unknown option fails" {
  run "${TEST_BIN}/kaptain-normalise-secrets" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

@test "normalise secrets: absolute --dir rejected" {
  run "${TEST_BIN}/kaptain-normalise-secrets" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path"* ]]
}

@test "normalise secrets: router lists it as a target" {
  run "${TEST_BIN}/kaptain-normalise"
  [ "$status" -eq 1 ]
  [[ "$output" == *"secrets"* ]]
}

@test "normalise secrets: dry run reports and changes nothing" {
  setup_secrets_repo

  run bash -c "cd '${TEST_NORM_ABS}' && printf '%s\n' '${SECRETS_PASSPHRASE}' | '${TEST_BIN_ABS}/kaptain-normalise-secrets' --dir secrets --dry-run"

  [ "$status" -eq 0 ]
  [[ "$output" == *"would normalise: needs-strip"* ]]
  [[ "$output" == *"would normalise: nested/deep"* ]]
  [[ "$output" == *"1 already canonical"* ]]
  [[ "$output" == *"1 multi-line"* ]]

  git -C "${TEST_NORM}" diff --quiet -- secrets
  [ "$(find "${TEST_NORM}/secrets" \( -name '*.txt' -o -name '*.raw' \) | wc -l | tr -d ' ')" -eq 0 ]
}

@test "normalise secrets: rewrites only the tokens that change" {
  setup_secrets_repo

  run bash -c "cd '${TEST_NORM_ABS}' && printf '%s\n' '${SECRETS_PASSPHRASE}' | '${TEST_BIN_ABS}/kaptain-normalise-secrets' --dir secrets"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2 normalised"* ]]

  # openssl salts randomly, so any re-encryption shows as a diff
  local changed
  changed=$(git -C "${TEST_NORM}" diff --name-only -- secrets | sort)
  [ "${changed}" = "$(printf 'secrets/needs-strip.sha256.aes256\nsecrets/nested/deep.sha256.aes256')" ]

  [ "$(find "${TEST_NORM}/secrets" \( -name '*.txt' -o -name '*.raw' \) | wc -l | tr -d ' ')" -eq 0 ]
}

@test "normalise secrets: strips single-line and preserves multi-line values" {
  setup_secrets_repo

  ( cd "${TEST_NORM}" && printf '%s\n' "${SECRETS_PASSPHRASE}" \
      | "${TEST_BIN_ABS}/kaptain-normalise-secrets" --dir secrets ) > /dev/null

  [ "$(token_value needs-strip)" = "one-newline-value" ]
  [ "$(token_value nested/deep)" = "nested-one" ]
  [ "$(token_value canonical)" = "no-newline-value" ]
  [ "$(token_value multi)" = "$(printf 'multi\nline\nvalue\n')" ]
}

@test "normalise secrets: second run finds nothing to do" {
  setup_secrets_repo

  ( cd "${TEST_NORM}" && printf '%s\n' "${SECRETS_PASSPHRASE}" \
      | "${TEST_BIN_ABS}/kaptain-normalise-secrets" --dir secrets ) > /dev/null
  git -C "${TEST_NORM}" add -A -f secrets
  git -C "${TEST_NORM}" commit -q -m "normalised"

  run bash -c "cd '${TEST_NORM_ABS}' && printf '%s\n' '${SECRETS_PASSPHRASE}' | '${TEST_BIN_ABS}/kaptain-normalise-secrets' --dir secrets"

  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to normalise"* ]]
  [[ "$output" == *"0 normalised"* ]]
  git -C "${TEST_NORM}" diff --quiet -- secrets
}

@test "normalise secrets: wrong key aborts without changes" {
  setup_secrets_repo

  run bash -c "cd '${TEST_NORM_ABS}' && printf '%s\n' 'wrong-key' | '${TEST_BIN_ABS}/kaptain-normalise-secrets' --dir secrets"

  [ "$status" -eq 1 ]
  [[ "$output" == *"aborted"* ]]
  git -C "${TEST_NORM}" diff --quiet -- secrets
  [ "$(find "${TEST_NORM}/secrets" \( -name '*.txt' -o -name '*.raw' \) | wc -l | tr -d ' ')" -eq 0 ]
}

@test "normalise secrets: refuses when encrypted files are uncommitted" {
  setup_secrets_repo
  printf 'tampered\n' >> "${TEST_NORM}/secrets/multi.sha256.aes256"

  run bash -c "cd '${TEST_NORM_ABS}' && printf '%s\n' '${SECRETS_PASSPHRASE}' | '${TEST_BIN_ABS}/kaptain-normalise-secrets' --dir secrets"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not accounted for in git"* ]]
}

@test "normalise secrets: refuses when the directory is not clean" {
  setup_secrets_repo
  echo "leftover" > "${TEST_NORM}/secrets/leftover.txt"

  run bash -c "cd '${TEST_NORM_ABS}' && printf '%s\n' '${SECRETS_PASSPHRASE}' | '${TEST_BIN_ABS}/kaptain-normalise-secrets' --dir secrets"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not clean"* ]]
  [[ "$output" == *"kaptain clean secrets"* ]]
}

@test "normalise secrets: dry run works without git" {
  mkdir -p "${TEST_NORM}/secrets"
  printf 'one-newline-value\n' > "${TEST_NORM}/secrets/needs-strip.raw"
  ( cd "${TEST_NORM}" && printf '%s\n' "${SECRETS_PASSPHRASE}" \
      | "${TEST_BIN_ABS}/kaptain-encrypt-sha256.aes256" --dir secrets ) > /dev/null
  find "${TEST_NORM}/secrets" -name '*.raw' -delete

  run bash -c "cd '${TEST_NORM_ABS}' && printf '%s\n' '${SECRETS_PASSPHRASE}' | '${TEST_BIN_ABS}/kaptain-normalise-secrets' --dir secrets --dry-run"

  [ "$status" -eq 0 ]
  [[ "$output" == *"would normalise: needs-strip"* ]]
}
