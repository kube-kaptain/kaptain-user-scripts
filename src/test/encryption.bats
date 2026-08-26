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

# Run a command under a time limit without depending on coreutils' timeout,
# which is absent on a stock macOS. Using it there made this test pass whatever
# happened, because a missing command exits 127 and only 124 was checked for.
#
# Sets TIMED_STATUS to the command's exit code, or 124 if it had to be killed,
# and TIMED_OUTPUT to its combined stdout and stderr.
run_with_time_limit() {
  local limit_tenths=$(( $1 * 10 ))
  shift

  local out_file="${OUTPUT_SUB_PATH}/test/time-limited-output.$$"
  local pid waited=0 status=0

  "$@" > "${out_file}" 2>&1 &
  pid=$!

  while kill -0 "${pid}" 2>/dev/null; do
    if [[ ${waited} -ge ${limit_tenths} ]]; then
      kill -9 "${pid}" 2>/dev/null || true
      wait "${pid}" 2>/dev/null || true
      TIMED_STATUS=124
      TIMED_OUTPUT=$(cat "${out_file}" 2>/dev/null || true)
      rm -f "${out_file}"
      return 0
    fi
    sleep 0.1
    waited=$(( waited + 1 ))
  done

  wait "${pid}" || status=$?
  TIMED_STATUS=${status}
  TIMED_OUTPUT=$(cat "${out_file}" 2>/dev/null || true)
  rm -f "${out_file}"
  return 0
}

@test "kaptain-encryption-check-ignores: absolute path is rejected and does not hang" {
  # Guards the fix for an infinite loop walking up from an absolute path.
  # Set up fake git repo in TEST_DIR
  mkdir -p "${TEST_DIR}/.git"
  mkdir -p "${TEST_DIR}/secrets"

  # Add proper gitignore patterns
  cat > "${TEST_DIR}/.gitignore" << 'EOF'
**/*secrets/**/*.raw
**/*secrets/**/*.txt
EOF

  # Absolute, resolved before the cd. TEST_DIR is relative, so passing it
  # through unchanged tested a nonexistent directory rather than this.
  local abs_secrets="${PWD}/${TEST_DIR}/secrets"

  run_with_time_limit 5 bash -c "cd '${TEST_DIR}' && '${PWD}/${SCRIPTS_DIR}/kaptain-encryption-check-ignores' --dir '${abs_secrets}'"

  # 124 means it had to be killed, which is the loop this guards against
  if [ "${TIMED_STATUS}" -eq 124 ]; then
    echo "FAIL: Script timed out - infinite loop detected with absolute path" >&2
    return 1
  fi

  # It should refuse the absolute path outright rather than walking anywhere
  [ "${TIMED_STATUS}" -eq 1 ]
  [[ "${TIMED_OUTPUT}" == *"must be a relative path"* ]]
}

@test "run_with_time_limit: kills a hanging command and reports 124" {
  run_with_time_limit 1 sleep 30
  [ "${TIMED_STATUS}" -eq 124 ]
}

@test "run_with_time_limit: reports a fast command's real exit status" {
  run_with_time_limit 5 bash -c 'echo hello; exit 3'
  [ "${TIMED_STATUS}" -eq 3 ]
  [[ "${TIMED_OUTPUT}" == *"hello"* ]]
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
