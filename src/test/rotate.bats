#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kaptain-rotate-key-for-secrets

SCRIPTS_DIR="src/scripts/encryption"
FIXTURES_DIR="src/test/fixtures"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"
TEST_PASSPHRASE="test-passphrase-for-ci-only"
NEW_PASSPHRASE="new-passphrase-for-rotation"

setup() {
  TEST_BASE="${OUTPUT_SUB_PATH}/test/rotate"
  TEST_DIR="${TEST_BASE}/secrets"
  rm -rf "${TEST_BASE}"
  mkdir -p "${TEST_DIR}"
  cp -r "${FIXTURES_DIR}"/* "${TEST_DIR}"/
}

teardown() {
  rm -rf "${OUTPUT_SUB_PATH}/test/rotate"
}

count_files() {
  find "$1" -name "$2" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Helper: encrypt fixtures and clean up .raw files to create a "normal" state
encrypt_fixtures() {
  local type="${1:-sha256.aes256}"
  local passphrase="${2:-${TEST_PASSPHRASE}}"
  echo "${passphrase}" | "${SCRIPTS_DIR}/kaptain-encrypt-${type}" --dir "${TEST_DIR}"
  find "${TEST_DIR}" -name "*.raw" -delete
}

# =============================================================================
# Argument parsing and validation
# =============================================================================

@test "rotate: --help shows usage" {
  run "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dir"* ]]
  [[ "$output" == *"--ask-for-key"* ]]
  [[ "$output" == *"--new-type"* ]]
  [[ "$output" == *"--output"* ]]
}

@test "rotate: -h shows usage" {
  run "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "rotate: unknown option fails" {
  run "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Unknown option"* ]]
}

@test "rotate: --dir absolute path rejected" {
  run "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --dir /absolute/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path"* ]]
}

@test "rotate: --dir nonexistent directory fails" {
  run "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --dir nonexistent/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"Secrets directory not found"* ]]
}

@test "rotate: --dir requires value" {
  run "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --dir requires a value"* ]]
}

@test "rotate: --new-type requires value" {
  run "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --new-type
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --new-type requires a value"* ]]
}

@test "rotate: --output requires value" {
  run "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --output
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --output requires a value"* ]]
}

@test "rotate: --output absolute path rejected" {
  encrypt_fixtures
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --output /absolute/path"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path"* ]]
}

@test "rotate: --output refuses to overwrite existing file" {
  encrypt_fixtures
  local out_file="${TEST_BASE}/existing.key"
  echo "old" > "${out_file}"
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --output '${out_file}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Output file already exists"* ]]
}

@test "rotate: --output with nonexistent parent directory fails" {
  encrypt_fixtures
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --output '${TEST_BASE}/no/such/dir/key.file'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Output directory does not exist"* ]]
}

# =============================================================================
# Pre-flight checks
# =============================================================================

@test "rotate: fails when .txt files present" {
  encrypt_fixtures
  echo "leftover" > "${TEST_DIR}/leftover.txt"
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not clean"* ]]
  [[ "$output" == *"kaptain clean secrets"* ]]
}

@test "rotate: fails when .raw files present" {
  encrypt_fixtures
  echo "leftover" > "${TEST_DIR}/leftover.raw"
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not clean"* ]]
  [[ "$output" == *"kaptain clean secrets"* ]]
}

@test "rotate: fails when no encrypted files exist" {
  # Empty dir with no encrypted files (just has .raw from fixtures)
  find "${TEST_DIR}" -name "*.raw" -delete
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No encrypted files found"* ]]
}

@test "rotate: fails with mixed encryption types" {
  encrypt_fixtures sha256.aes256
  echo "fake" > "${TEST_DIR}/fake.sha256.aes256.10k"
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Mixed encryption types"* ]]
}

@test "rotate: fails with unknown --new-type" {
  encrypt_fixtures
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --new-type bogus"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown encryption type: bogus"* ]]
}

# =============================================================================
# Key rotation — same type with generated key
# =============================================================================

@test "rotate: same type rotates successfully with generated key" {
  encrypt_fixtures sha256.aes256
  local key_output="${TEST_BASE}/rotated.key"

  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --output '${key_output}'"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]
  [[ "$output" == *"New key written to:"* ]]

  # New key file was written
  [ -f "${key_output}" ]
  local new_key
  new_key=$(<"${key_output}")
  [ -n "${new_key}" ]

  # Encrypted files still exist (re-encrypted)
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]

  # No .raw or .txt files left behind
  [ "$(count_files "${TEST_DIR}" "*.raw")" -eq 0 ]
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 0 ]

  # Decrypt with new key to verify contents
  echo "${new_key}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir "${TEST_DIR}"
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
  grep -q "test-secret-value-two" "${TEST_DIR}/secret2.txt"
  grep -q "nested-secret-value" "${TEST_DIR}/nested/deep-secret.txt"
}

@test "rotate: old key no longer decrypts after rotation" {
  encrypt_fixtures sha256.aes256
  local key_output="${TEST_BASE}/rotated.key"

  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --dir "${TEST_DIR}" --output "${key_output}"

  # Old key should fail
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256' --dir '${TEST_DIR}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAILED"* ]]
}

# =============================================================================
# Key rotation — same type with --ask-for-key
# =============================================================================

@test "rotate: --ask-for-key accepts user-provided key" {
  encrypt_fixtures sha256.aes256

  # Provide old key + new key + new key confirmation
  run bash -c "printf '%s\n' '${TEST_PASSPHRASE}' '${NEW_PASSPHRASE}' '${NEW_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --ask-for-key"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]

  # No key file output when --ask-for-key
  [[ "$output" != *"New key written to:"* ]]

  # Encrypted files still exist
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]

  # Decrypt with new key to verify
  echo "${NEW_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir "${TEST_DIR}"
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

@test "rotate: --ask-for-key rejects mismatched keys" {
  encrypt_fixtures sha256.aes256

  run bash -c "printf '%s\n' '${TEST_PASSPHRASE}' 'key-one' 'key-two' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --ask-for-key"

  [ "$status" -eq 1 ]
  [[ "$output" == *"New keys do not match"* ]]

  # Original files unchanged
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]
}

# =============================================================================
# Key rotation — type migration
# =============================================================================

@test "rotate: --new-type migrates encryption type" {
  encrypt_fixtures sha256.aes256
  local key_output="${TEST_BASE}/migrated.key"

  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --new-type sha256.aes256.10k --output '${key_output}'"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrating encryption type"* ]]
  [[ "$output" == *"Key rotation complete"* ]]

  # Old type files removed
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 0 ]

  # New type files created
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256.10k")" -eq 3 ]

  # Decrypt with new key and new type
  local new_key
  new_key=$(<"${key_output}")
  echo "${new_key}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256.10k" --dir "${TEST_DIR}"
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
  grep -q "nested-secret-value" "${TEST_DIR}/nested/deep-secret.txt"
}

# =============================================================================
# Wrong key handling
# =============================================================================

@test "rotate: wrong current key aborts without changes" {
  encrypt_fixtures sha256.aes256

  # Capture file checksums before
  local before
  before=$(find "${TEST_DIR}" -name "*.sha256.aes256" -type f -exec md5sum {} + | sort)

  run bash -c "echo 'wrong-key' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Key rotation aborted"* ]]

  # Files unchanged
  local after
  after=$(find "${TEST_DIR}" -name "*.sha256.aes256" -type f -exec md5sum {} + | sort)
  [ "${before}" = "${after}" ]

  # No .txt or .raw files left
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 0 ]
  [ "$(count_files "${TEST_DIR}" "*.raw")" -eq 0 ]
}

# =============================================================================
# Cleanup behavior
# =============================================================================

@test "rotate: no .raw or .txt files left after successful rotation" {
  encrypt_fixtures sha256.aes256
  local key_output="${TEST_BASE}/cleanup-test.key"

  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --dir "${TEST_DIR}" --output "${key_output}"

  [ "$(count_files "${TEST_DIR}" "*.raw")" -eq 0 ]
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 0 ]
}

@test "rotate: default output path creates target/keygen/new.key" {
  encrypt_fixtures sha256.aes256

  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --dir "${TEST_DIR}"

  [ -f "target/keygen/new.key" ]
  rm -f "target/keygen/new.key"
}

@test "rotate: output key file has restricted permissions" {
  encrypt_fixtures sha256.aes256
  local key_output="${TEST_BASE}/perms.key"

  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets" --dir "${TEST_DIR}" --output "${key_output}"

  local perms
  perms=$(stat -c '%a' "${key_output}" 2>/dev/null || stat -f '%Lp' "${key_output}" 2>/dev/null)
  [ "${perms}" = "600" ]
}

# =============================================================================
# Age rotation tests
# =============================================================================

@test "rotate: age same-type rotation" {
  if ! command -v age &> /dev/null || ! command -v age-keygen &> /dev/null; then
    skip "age/age-keygen not installed"
  fi

  AGE_KEY=$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-')
  encrypt_fixtures age "${AGE_KEY}"
  local key_output="${TEST_BASE}/age-rotated.key"

  run bash -c "echo '${AGE_KEY}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --output '${key_output}'"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]

  # New key file written
  [ -f "${key_output}" ]
  local new_key
  new_key=$(<"${key_output}")
  [[ "${new_key}" == AGE-SECRET-KEY-* ]]

  # Encrypted files exist
  [ "$(count_files "${TEST_DIR}" "*.age")" -eq 3 ]

  # Decrypt with new key
  echo "${new_key}" | "${SCRIPTS_DIR}/kaptain-decrypt-age" --dir "${TEST_DIR}"
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

@test "rotate: age to sha256.aes256 type migration" {
  if ! command -v age &> /dev/null || ! command -v age-keygen &> /dev/null; then
    skip "age/age-keygen not installed"
  fi

  AGE_KEY=$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-')
  encrypt_fixtures age "${AGE_KEY}"
  local key_output="${TEST_BASE}/migrated-from-age.key"

  run bash -c "echo '${AGE_KEY}' | '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --dir '${TEST_DIR}' --new-type sha256.aes256 --output '${key_output}'"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrating encryption type"* ]]

  # Old age files gone
  [ "$(count_files "${TEST_DIR}" "*.age")" -eq 0 ]

  # New openssl files present
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]

  # Decrypt with new key
  local new_key
  new_key=$(<"${key_output}")
  echo "${new_key}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir "${TEST_DIR}"
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

# =============================================================================
# KAPTAIN_USER_SCRIPTS_SECRETS_DIR support
# =============================================================================

@test "rotate: respects KAPTAIN_USER_SCRIPTS_SECRETS_DIR" {
  encrypt_fixtures sha256.aes256
  local key_output="${TEST_BASE}/env-test.key"

  run bash -c "echo '${TEST_PASSPHRASE}' | KAPTAIN_USER_SCRIPTS_SECRETS_DIR='${TEST_DIR}' '${SCRIPTS_DIR}/kaptain-rotate-key-for-secrets' --output '${key_output}'"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]
}
