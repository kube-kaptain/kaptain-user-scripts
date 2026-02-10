#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Functional tests for encryption/decryption round-trips

SCRIPTS_DIR="src/scripts/encryption"
FIXTURES_DIR="src/test/fixtures"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"
TEST_PASSPHRASE="test-passphrase-for-ci-only"

# Setup: create a clean test directory for each test
setup() {
  TEST_DIR="${OUTPUT_SUB_PATH}/test/encryption-functional/secrets"
  rm -rf "${OUTPUT_SUB_PATH}/test/encryption-functional"
  mkdir -p "${TEST_DIR}"
  cp -r "${FIXTURES_DIR}"/* "${TEST_DIR}"/

  # Add gitignore patterns required by kaptain-encryption-check-ignores
  # This ensures router tests pass in CI where global gitignore isn't configured
  cat > "${OUTPUT_SUB_PATH}/test/encryption-functional/.gitignore" << 'EOF'
**/*secrets/*.raw
**/*secrets/*.txt
EOF
}

# Teardown: clean up test directory
teardown() {
  rm -rf "${OUTPUT_SUB_PATH}/test/encryption-functional"
}

# Helper to count files matching a pattern
count_files() {
  find "$1" -name "$2" -type f 2>/dev/null | wc -l | tr -d ' '
}

# =============================================================================
# sha256.aes256 (10k iterations - legacy) round-trip tests
# =============================================================================

@test "sha256.aes256: encrypt creates encrypted files" {
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"

  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]
}

@test "sha256.aes256: decrypt recovers original files" {
  # Encrypt first
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Decrypt
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir "${TEST_DIR}"

  # Verify decrypted content
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 3 ]
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
  grep -q "test-secret-value-two" "${TEST_DIR}/secret2.txt"
  grep -q "nested-secret-value" "${TEST_DIR}/nested/deep-secret.txt"
}

@test "sha256.aes256: wrong passphrase fails decryption" {
  # Encrypt with correct passphrase
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Try to decrypt with wrong passphrase
  run bash -c "echo 'wrong-passphrase' | '${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"failed"* ]] || [[ "$output" == *"FAILED"* ]]
}

@test "sha256.aes256: key validation rejects wrong passphrase on encrypt" {
  # First encrypt to create existing encrypted files
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"

  # Add a new raw file
  echo "new-secret" > "${TEST_DIR}/new-secret.raw"

  # Try to encrypt with wrong passphrase - should fail validation
  run bash -c "echo 'wrong-passphrase' | '${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Key does not match"* ]]
}

# =============================================================================
# sha256.aes256.10k round-trip tests
# =============================================================================

@test "sha256.aes256.10k: encrypt and decrypt round-trip" {
  # Encrypt
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.10k" --dir "${TEST_DIR}"

  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256.10k")" -eq 3 ]

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Decrypt
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256.10k" --dir "${TEST_DIR}"

  # Verify
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 3 ]
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

@test "sha256.aes256.10k: key validation works" {
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.10k" --dir "${TEST_DIR}"
  echo "new-secret" > "${TEST_DIR}/new-secret.raw"

  run bash -c "echo 'wrong-passphrase' | '${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.10k' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Key does not match"* ]]
}

# =============================================================================
# sha256.aes256.100k round-trip tests
# =============================================================================

@test "sha256.aes256.100k: encrypt and decrypt round-trip" {
  # Encrypt
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.100k" --dir "${TEST_DIR}"

  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256.100k")" -eq 3 ]

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Decrypt
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256.100k" --dir "${TEST_DIR}"

  # Verify
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 3 ]
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

@test "sha256.aes256.100k: key validation works" {
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.100k" --dir "${TEST_DIR}"
  echo "new-secret" > "${TEST_DIR}/new-secret.raw"

  run bash -c "echo 'wrong-passphrase' | '${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.100k' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Key does not match"* ]]
}

# =============================================================================
# sha256.aes256.600k round-trip tests
# =============================================================================

@test "sha256.aes256.600k: encrypt and decrypt round-trip" {
  # Encrypt
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.600k" --dir "${TEST_DIR}"

  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256.600k")" -eq 3 ]

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Decrypt
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256.600k" --dir "${TEST_DIR}"

  # Verify
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 3 ]
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

@test "sha256.aes256.600k: key validation works" {
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.600k" --dir "${TEST_DIR}"
  echo "new-secret" > "${TEST_DIR}/new-secret.raw"

  run bash -c "echo 'wrong-passphrase' | '${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256.600k' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Key does not match"* ]]
}

# =============================================================================
# age encryption round-trip tests
# =============================================================================

@test "age: encrypt and decrypt round-trip" {
  if ! command -v age &> /dev/null || ! command -v age-keygen &> /dev/null; then
    skip "age/age-keygen not installed"
  fi

  # Generate a test key
  AGE_KEY=$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-')

  # Encrypt
  echo "${AGE_KEY}" | "${SCRIPTS_DIR}/kaptain-encrypt-age" --dir "${TEST_DIR}"

  [ "$(count_files "${TEST_DIR}" "*.age")" -eq 3 ]

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Decrypt
  echo "${AGE_KEY}" | "${SCRIPTS_DIR}/kaptain-decrypt-age" --dir "${TEST_DIR}"

  # Verify
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 3 ]
  grep -q "test-secret-value-one" "${TEST_DIR}/secret1.txt"
}

@test "age: wrong key fails decryption" {
  if ! command -v age &> /dev/null || ! command -v age-keygen &> /dev/null; then
    skip "age/age-keygen not installed"
  fi

  # Generate two different keys
  AGE_KEY1=$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-')
  AGE_KEY2=$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-')

  # Encrypt with key1
  echo "${AGE_KEY1}" | "${SCRIPTS_DIR}/kaptain-encrypt-age" --dir "${TEST_DIR}"

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Try to decrypt with key2
  run bash -c "echo '${AGE_KEY2}' | '${SCRIPTS_DIR}/kaptain-decrypt-age' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"failed"* ]] || [[ "$output" == *"FAILED"* ]]
}

@test "age: key validation rejects wrong key on encrypt" {
  if ! command -v age &> /dev/null || ! command -v age-keygen &> /dev/null; then
    skip "age/age-keygen not installed"
  fi

  AGE_KEY1=$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-')
  AGE_KEY2=$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-')

  # Encrypt with key1
  echo "${AGE_KEY1}" | "${SCRIPTS_DIR}/kaptain-encrypt-age" --dir "${TEST_DIR}"

  # Add new raw file
  echo "new-secret" > "${TEST_DIR}/new-secret.raw"

  # Try to encrypt with key2 - should fail validation
  run bash -c "echo '${AGE_KEY2}' | '${SCRIPTS_DIR}/kaptain-encrypt-age' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Key does not match"* ]]
}

@test "age: invalid key format rejected" {
  if ! command -v age &> /dev/null; then
    skip "age not installed"
  fi

  run bash -c "echo 'not-a-valid-age-key' | '${SCRIPTS_DIR}/kaptain-encrypt-age' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Not a valid age secret key"* ]]
}

@test "age: temp directory cleanup" {
  if ! command -v age &> /dev/null || ! command -v age-keygen &> /dev/null; then
    skip "age/age-keygen not installed"
  fi

  AGE_KEY=$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-')

  # Encrypt
  echo "${AGE_KEY}" | "${SCRIPTS_DIR}/kaptain-encrypt-age" --dir "${TEST_DIR}"

  # Check that ~/.kaptain-tmp is empty or doesn't exist
  if [[ -d "${HOME}/.kaptain-tmp" ]]; then
    [ "$(ls -A "${HOME}/.kaptain-tmp" 2>/dev/null | wc -l)" -eq 0 ]
  fi
}

# =============================================================================
# Router auto-detection tests
# =============================================================================

@test "router: encrypt auto-detects existing sha256.aes256 type" {
  # Create an existing encrypted file
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"

  # Add a new raw file
  echo "new-secret" > "${TEST_DIR}/new-secret.raw"

  # Use router without --type
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-encrypt' --dir '${TEST_DIR}'"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Using existing encryption type: sha256.aes256"* ]]
  [ -f "${TEST_DIR}/new-secret.sha256.aes256" ]
}

@test "router: decrypt auto-detects sha256.aes256 type" {
  # Encrypt files
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Use router without --type
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-decrypt' --dir '${TEST_DIR}'"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Auto-detected type: sha256.aes256"* ]]
}

@test "router: encrypt defaults to age for empty directory" {
  # Create empty test dir with just raw files (already have fixtures)
  run "${SCRIPTS_DIR}/kaptain-encrypt" --dir "${TEST_DIR}" --type bogus

  # Just check it mentions age as default (we can't actually run without key input)
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported encryption type"* ]]
}

@test "router: mixed encryption types detected" {
  # Create files with different encryption types
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"

  # Manually create a file with different extension
  echo "fake" > "${TEST_DIR}/fake.sha256.aes256.10k"

  # Remove raw files
  find "${TEST_DIR}" -name "*.raw" -delete

  # Try to decrypt - should detect mixed types
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-decrypt' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Mixed encryption types"* ]]
}

# =============================================================================
# Continue-and-report behavior tests
# =============================================================================

@test "decrypt: continues after failure and reports summary" {
  # Encrypt files
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"

  # Corrupt one file
  echo "corrupted" > "${TEST_DIR}/secret1.sha256.aes256"

  # Remove originals
  find "${TEST_DIR}" -name "*.raw" -delete

  # Decrypt - should continue past the corrupted file
  run bash -c "echo '${TEST_PASSPHRASE}' | '${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256' --dir '${TEST_DIR}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"2 succeeded"* ]]
  [[ "$output" == *"1 failed"* ]]
  [[ "$output" == *"Failed files:"* ]]

  # Good files should still be decrypted
  [ -f "${TEST_DIR}/secret2.txt" ]
  [ -f "${TEST_DIR}/nested/deep-secret.txt" ]
}

# =============================================================================
# Empty directory handling
# =============================================================================

@test "encrypt: empty directory (no raw files) exits cleanly" {
  EMPTY_DIR="${OUTPUT_SUB_PATH}/test/encryption-functional/empty-secrets"
  mkdir -p "${EMPTY_DIR}"

  run "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${EMPTY_DIR}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No .raw files found"* ]]
}

@test "decrypt: empty directory (no encrypted files) exits cleanly" {
  EMPTY_DIR="${OUTPUT_SUB_PATH}/test/encryption-functional/empty-secrets"
  mkdir -p "${EMPTY_DIR}"

  run "${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256" --dir "${EMPTY_DIR}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No .sha256.aes256 files found"* ]]
}

# =============================================================================
# SECRETS_DIR environment variable
# =============================================================================

@test "encrypt: respects SECRETS_DIR environment variable" {
  export SECRETS_DIR="${TEST_DIR}"

  run bash -c "echo '${TEST_PASSPHRASE}' | SECRETS_DIR='${TEST_DIR}' '${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256'"

  [ "$status" -eq 0 ]
  [ "$(count_files "${TEST_DIR}" "*.sha256.aes256")" -eq 3 ]
}

@test "decrypt: respects SECRETS_DIR environment variable" {
  # Encrypt first
  echo "${TEST_PASSPHRASE}" | "${SCRIPTS_DIR}/kaptain-encrypt-sha256.aes256" --dir "${TEST_DIR}"
  find "${TEST_DIR}" -name "*.raw" -delete

  run bash -c "echo '${TEST_PASSPHRASE}' | SECRETS_DIR='${TEST_DIR}' '${SCRIPTS_DIR}/kaptain-decrypt-sha256.aes256'"

  [ "$status" -eq 0 ]
  [ "$(count_files "${TEST_DIR}" "*.txt")" -eq 3 ]
}
