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
  SCRIPTS_ABS="$(pwd)/${SCRIPTS_DIR}"
  TEST_BASE="${OUTPUT_SUB_PATH}/test/rotate"
  TEST_DIR="${TEST_BASE}/secrets"
  rm -rf "${TEST_BASE}"
  mkdir -p "${TEST_DIR}"
  cp -r "${FIXTURES_DIR}"/* "${TEST_DIR}"/

  # Rotation refuses to run unless the encrypted files are committed, so the
  # test area is its own throwaway repo. The script resolves git from its
  # working directory, so rotations are run from inside TEST_BASE.
  git -C "${TEST_BASE}" init -q
  git -C "${TEST_BASE}" config user.email "test@example.com"
  git -C "${TEST_BASE}" config user.name "Kaptain Test"
  git -C "${TEST_BASE}" config commit.gpgsign false
  git -C "${TEST_BASE}" commit -q --allow-empty -m "initial"
}

teardown() {
  rm -rf "${OUTPUT_SUB_PATH}/test/rotate"
}

count_files() {
  find "$1" -name "$2" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Commit whatever is currently in the test repo's secrets directory
commit_secrets() {
  git -C "${TEST_BASE}" add -A -f secrets
  git -C "${TEST_BASE}" commit -q -m "encrypted secrets"
}

# Helper: encrypt fixtures, drop the .raw files, commit - the normal state
encrypt_fixtures() {
  encrypt_fixtures_uncommitted "$@"
  commit_secrets
}

# Helper: as above but leaves the encrypted files uncommitted
encrypt_fixtures_uncommitted() {
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
# Git accountability pre-flight
# =============================================================================

@test "rotate: fails when encrypted files are untracked" {
  encrypt_fixtures_uncommitted sha256.aes256

  run bash -c "cd '${TEST_BASE}' && echo '${TEST_PASSPHRASE}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not accounted for in git"* ]]
  [[ "$output" == *"Untracked:"* ]]

  # Nothing was touched
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]
  [ "$(count_files "${TEST_DIR}" "*.raw")" -eq 0 ]
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 0 ]
}

@test "rotate: fails when an encrypted file has uncommitted changes" {
  encrypt_fixtures sha256.aes256
  printf 'tampered\n' >> "${TEST_DIR}/secret1.sha256.aes256"

  run bash -c "cd '${TEST_BASE}' && echo '${TEST_PASSPHRASE}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not accounted for in git"* ]]
  [[ "$output" == *"Uncommitted changes:"* ]]
  [[ "$output" == *"secret1.sha256.aes256"* ]]
}

@test "rotate: fails when repository has no commits" {
  local fresh="${TEST_BASE}/fresh"
  mkdir -p "${fresh}/secrets"
  cp -r "${FIXTURES_DIR}"/* "${fresh}/secrets"/
  git -C "${fresh}" init -q
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${fresh}/secrets" > /dev/null
  find "${fresh}/secrets" -name "*.raw" -delete

  run bash -c "cd '${fresh}' && echo '${TEST_PASSPHRASE}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets"

  [ "$status" -eq 1 ]
  [[ "$output" == *"no commits"* ]]
}

@test "rotate: fails when not inside a git repository" {
  local nogit
  nogit=$(mktemp -d)
  mkdir -p "${nogit}/secrets"
  cp -r "${FIXTURES_DIR}"/* "${nogit}/secrets"/
  # --dir rejects absolute paths, so encrypt from inside the temp directory
  ( cd "${nogit}" && echo "${TEST_PASSPHRASE}" | "${SCRIPTS_ABS}/kaptain-encrypt-sha256.aes256" --dir secrets > /dev/null )
  find "${nogit}/secrets" -name "*.raw" -delete

  run bash -c "cd '${nogit}' && echo '${TEST_PASSPHRASE}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets"
  rm -rf "${nogit}"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Not inside a git repository"* ]]
}

# =============================================================================
# Key rotation — same type with generated key
# =============================================================================

@test "rotate: same type rotates successfully with generated key" {
  encrypt_fixtures sha256.aes256

  run bash -c "cd '${TEST_BASE}' && echo '${TEST_PASSPHRASE}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets --output rotated.key"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]
  [[ "$output" == *"New key written to:"* ]]

  # New key file was written
  [ -f "${TEST_BASE}/rotated.key" ]
  local new_key
  new_key=$(<"${TEST_BASE}/rotated.key")
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

  ( cd "${TEST_BASE}" && echo "${TEST_PASSPHRASE}" | "${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets" --dir secrets --output rotated.key )

  # Old key should fail
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256' --dir '${TEST_DIR}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAILED"* ]]
}

@test "rotate: displays new key and writes no file when --output omitted" {
  encrypt_fixtures sha256.aes256

  run bash -c "cd '${TEST_BASE}' && echo '${TEST_PASSPHRASE}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]
  [[ "$output" == *"New key:"* ]]
  [[ "$output" != *"New key written to:"* ]]

  # No key file anywhere, including the path this used to default to
  [ ! -e "${TEST_BASE}/target" ]
  [ ! -e "target/keygen/new.key" ]

  # The displayed key is the real one and decrypts the rotated secrets
  local new_key
  new_key=$(printf '%s\n' "$output" | awk '/^New key:$/{getline; print; exit}')
  [ -n "${new_key}" ]
  echo "${new_key}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir "${TEST_DIR}"
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

# =============================================================================
# Key rotation — same type with --ask-for-key
# =============================================================================

@test "rotate: --ask-for-key accepts user-provided key" {
  encrypt_fixtures sha256.aes256

  # Provide old key + new key + new key confirmation
  run bash -c "cd '${TEST_BASE}' && printf '%s\n' '${TEST_PASSPHRASE}' '${NEW_PASSPHRASE}' '${NEW_PASSPHRASE}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets --ask-for-key"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]

  # The user supplied the key, so it is neither written nor echoed back
  [[ "$output" != *"New key written to:"* ]]
  [[ "$output" != *"New key:"* ]]

  # Encrypted files still exist
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]

  # Decrypt with new key to verify
  echo "${NEW_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir "${TEST_DIR}"
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

@test "rotate: --ask-for-key rejects mismatched keys" {
  encrypt_fixtures sha256.aes256

  run bash -c "cd '${TEST_BASE}' && printf '%s\n' '${TEST_PASSPHRASE}' 'key-one' 'key-two' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets --ask-for-key"

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

  run bash -c "cd '${TEST_BASE}' && echo '${TEST_PASSPHRASE}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets --new-type sha256.aes256.10k --output migrated.key"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrating encryption type"* ]]
  [[ "$output" == *"Key rotation complete"* ]]

  # Old type files removed
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 0 ]

  # New type files created
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256.10k")" -eq 3 ]

  # Decrypt with new key and new type
  local new_key
  new_key=$(<"${TEST_BASE}/migrated.key")
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

  run bash -c "cd '${TEST_BASE}' && echo 'wrong-key' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets"

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

  ( cd "${TEST_BASE}" && echo "${TEST_PASSPHRASE}" | "${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets" --dir secrets --output cleanup-test.key )

  [ "$(count_files "${TEST_DIR}" "*.raw")" -eq 0 ]
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 0 ]
}

@test "rotate: output key file has restricted permissions" {
  encrypt_fixtures sha256.aes256

  ( cd "${TEST_BASE}" && echo "${TEST_PASSPHRASE}" | "${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets" --dir secrets --output perms.key )

  local perms
  perms=$(stat -c '%a' "${TEST_BASE}/perms.key" 2>/dev/null || stat -f '%Lp' "${TEST_BASE}/perms.key" 2>/dev/null)
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

  run bash -c "cd '${TEST_BASE}' && echo '${AGE_KEY}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets --output age-rotated.key"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]

  # New key file written
  [ -f "${TEST_BASE}/age-rotated.key" ]
  local new_key
  new_key=$(<"${TEST_BASE}/age-rotated.key")
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

  run bash -c "cd '${TEST_BASE}' && echo '${AGE_KEY}' | '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --dir secrets --new-type sha256.aes256 --output migrated-from-age.key"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrating encryption type"* ]]

  # Old age files gone
  [ "$(count_files "${TEST_DIR}" "*.age")" -eq 0 ]

  # New openssl files present
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]

  # Decrypt with new key
  local new_key
  new_key=$(<"${TEST_BASE}/migrated-from-age.key")
  echo "${new_key}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir "${TEST_DIR}"
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

# =============================================================================
# KAPTAIN_USER_SCRIPTS_SECRETS_DIR support
# =============================================================================

@test "rotate: respects KAPTAIN_USER_SCRIPTS_SECRETS_DIR" {
  encrypt_fixtures sha256.aes256

  run bash -c "cd '${TEST_BASE}' && echo '${TEST_PASSPHRASE}' | KAPTAIN_USER_SCRIPTS_SECRETS_DIR='secrets' '${SCRIPTS_ABS}/kaptain-rotate-key-for-secrets' --output env-test.key"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Key rotation complete"* ]]
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]
}
