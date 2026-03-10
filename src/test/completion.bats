#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for bash completion

COMPLETION_SCRIPT="src/docker/kaptain-completion.bash"

setup() {
  WORK_DIR="${BATS_TEST_TMPDIR}/completion"
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}/bin"

  create_stub() {
    local name="$1"
    printf '#!/usr/bin/env bash\necho stub\n' > "${WORK_DIR}/bin/${name}"
    chmod +x "${WORK_DIR}/bin/${name}"
  }

  # Top-level routers (scripts that exist AND have children)
  create_stub "kaptain-list"
  create_stub "kaptain-clean"
  create_stub "kaptain-encrypt"
  create_stub "kaptain-decrypt"

  # Top-level leaves (no children)
  create_stub "kaptain-keygen"
  create_stub "kaptain-help"

  # Leaves with no matching router (full remainder at top level)
  create_stub "kaptain-encryption-check-ignores"

  # Second-level leaves under list
  create_stub "kaptain-list-secrets"
  create_stub "kaptain-list-config"
  create_stub "kaptain-list-manifests"

  # Second-level leaves under clean
  create_stub "kaptain-clean-secrets"

  # Second-level leaves under encrypt
  create_stub "kaptain-encrypt-age"
  create_stub "kaptain-encrypt-sha256.aes256"
  create_stub "kaptain-encrypt-sha256.aes256.10k"
  create_stub "kaptain-encrypt-sha256.aes256.100k"
  create_stub "kaptain-encrypt-sha256.aes256.600k"

  # Second-level leaves under decrypt
  create_stub "kaptain-decrypt-age"
  create_stub "kaptain-decrypt-sha256.aes256"
  create_stub "kaptain-decrypt-sha256.aes256.10k"
  create_stub "kaptain-decrypt-sha256.aes256.100k"
  create_stub "kaptain-decrypt-sha256.aes256.600k"

  export KAPTAIN_SCRIPT_DIR="${WORK_DIR}/bin"

  # Source the completion script
  source "${COMPLETION_SCRIPT}"
}

# Helper: simulate completion and return sorted COMPREPLY
# Usage: complete_at "kaptain" "list" ""
#   Args represent COMP_WORDS; last arg is the current word being typed
complete_at() {
  COMP_WORDS=("$@")
  COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev=""
  if [[ ${COMP_CWORD} -gt 0 ]]; then
    prev="${COMP_WORDS[COMP_CWORD - 1]}"
  fi
  _kaptain_completions "kaptain" "${cur}" "${prev}"
  # Sort for deterministic comparison
  IFS=$'\n' COMPREPLY=($(printf '%s\n' "${COMPREPLY[@]}" | sort)); unset IFS
}

# --- Top level: kaptain <tab> ---

@test "top level: shows routers and leaves" {
  complete_at "kaptain" ""
  [[ " ${COMPREPLY[*]} " == *" list "* ]]
  [[ " ${COMPREPLY[*]} " == *" clean "* ]]
  [[ " ${COMPREPLY[*]} " == *" encrypt "* ]]
  [[ " ${COMPREPLY[*]} " == *" decrypt "* ]]
  [[ " ${COMPREPLY[*]} " == *" keygen "* ]]
  [[ " ${COMPREPLY[*]} " == *" help "* ]]
}

@test "top level: shows full remainder when no router for short segment" {
  complete_at "kaptain" ""
  # No kaptain-encryption script exists, so show full remainder
  [[ " ${COMPREPLY[*]} " == *" encryption-check-ignores "* ]]
  # Should NOT show bare "encryption" since there's no kaptain-encryption
  [[ " ${COMPREPLY[*]} " != *" encryption "* ]]
}

@test "top level: does not show expanded leaves" {
  complete_at "kaptain" ""
  # Should NOT include list-secrets, encrypt-age etc at top level
  [[ " ${COMPREPLY[*]} " != *" list-secrets "* ]]
  [[ " ${COMPREPLY[*]} " != *" list-config "* ]]
  [[ " ${COMPREPLY[*]} " != *" encrypt-age "* ]]
  [[ " ${COMPREPLY[*]} " != *" clean-secrets "* ]]
}

@test "top level: partial match filters correctly" {
  complete_at "kaptain" "li"
  [[ ${#COMPREPLY[@]} -eq 1 ]]
  [[ "${COMPREPLY[0]}" == "list" ]]
}

@test "top level: partial match with multiple results" {
  complete_at "kaptain" "en"
  [[ " ${COMPREPLY[*]} " == *" encrypt "* ]]
  [[ " ${COMPREPLY[*]} " == *" encryption-check-ignores "* ]]
  [[ " ${COMPREPLY[*]} " != *" list "* ]]
  [[ " ${COMPREPLY[*]} " != *" decrypt "* ]]
}

# --- Second level: kaptain list <tab> ---

@test "second level: kaptain list shows sub-commands" {
  complete_at "kaptain" "list" ""
  [[ " ${COMPREPLY[*]} " == *" secrets "* ]]
  [[ " ${COMPREPLY[*]} " == *" config "* ]]
  [[ " ${COMPREPLY[*]} " == *" manifests "* ]]
}

@test "second level: kaptain list partial match" {
  complete_at "kaptain" "list" "se"
  [[ ${#COMPREPLY[@]} -eq 1 ]]
  [[ "${COMPREPLY[0]}" == "secrets" ]]
}

@test "second level: kaptain clean shows sub-commands" {
  complete_at "kaptain" "clean" ""
  [[ " ${COMPREPLY[*]} " == *" secrets "* ]]
}

@test "second level: kaptain encrypt shows types and full remainders" {
  complete_at "kaptain" "encrypt" ""
  # kaptain-encrypt-age is a single segment, always shown
  [[ " ${COMPREPLY[*]} " == *" age "* ]]
  # kaptain-encrypt-sha256.aes256 exists as a script, so short segment shown
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256 "* ]]
  # Longer leaves also discoverable at deeper level
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256.10k "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256.100k "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256.600k "* ]]
}

@test "second level: kaptain decrypt shows same types as encrypt" {
  complete_at "kaptain" "decrypt" ""
  [[ " ${COMPREPLY[*]} " == *" age "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256 "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256.10k "* ]]
}

# --- Edge cases ---

@test "no matches returns empty" {
  complete_at "kaptain" "zzz"
  [[ ${#COMPREPLY[@]} -eq 0 ]]
}

@test "second level no matches returns empty" {
  complete_at "kaptain" "list" "zzz"
  [[ ${#COMPREPLY[@]} -eq 0 ]]
}

@test "deduplication: sha256.aes256 not duplicated" {
  complete_at "kaptain" "encrypt" ""
  local count=0
  for item in "${COMPREPLY[@]}"; do
    [[ "${item}" == "sha256.aes256" ]] && count=$((count + 1))
  done
  [[ ${count} -eq 1 ]]
}

# --- Flag completion ---

@test "flags: kaptain list secrets --<tab> shows flags" {
  complete_at "kaptain" "list" "secrets" "--"
  [[ " ${COMPREPLY[*]} " == *" --dir "* ]]
  [[ " ${COMPREPLY[*]} " == *" --all "* ]]
  [[ " ${COMPREPLY[*]} " == *" --verbose "* ]]
  [[ " ${COMPREPLY[*]} " == *" --help "* ]]
}

@test "flags: kaptain list secrets -<tab> shows short flags too" {
  complete_at "kaptain" "list" "secrets" "-"
  [[ " ${COMPREPLY[*]} " == *" -h "* ]]
  [[ " ${COMPREPLY[*]} " == *" -v "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dir "* ]]
}

@test "flags: kaptain encrypt --<tab> shows encrypt flags" {
  complete_at "kaptain" "encrypt" "--"
  [[ " ${COMPREPLY[*]} " == *" --type "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dir "* ]]
  [[ " ${COMPREPLY[*]} " == *" --help "* ]]
}

@test "flags: kaptain encrypt partial --t<tab>" {
  complete_at "kaptain" "encrypt" "--t"
  [[ ${#COMPREPLY[@]} -eq 1 ]]
  [[ "${COMPREPLY[0]}" == "--type" ]]
}

@test "flags: kaptain clean secrets --<tab> shows clean flags" {
  complete_at "kaptain" "clean" "secrets" "--"
  [[ " ${COMPREPLY[*]} " == *" --dir "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dry-run "* ]]
  [[ " ${COMPREPLY[*]} " == *" --all "* ]]
}

@test "flags: kaptain keygen --<tab> shows keygen flags" {
  complete_at "kaptain" "keygen" "--"
  [[ " ${COMPREPLY[*]} " == *" --type "* ]]
  [[ " ${COMPREPLY[*]} " == *" --output "* ]]
  [[ " ${COMPREPLY[*]} " == *" --help "* ]]
}

@test "flags: still shown after an existing flag" {
  complete_at "kaptain" "list" "secrets" "--all" "--"
  [[ " ${COMPREPLY[*]} " == *" --dir "* ]]
  [[ " ${COMPREPLY[*]} " == *" --verbose "* ]]
}

@test "flags: unknown command returns empty" {
  complete_at "kaptain" "zzz" "--"
  [[ ${#COMPREPLY[@]} -eq 0 ]]
}

# --- Value completion: --type ---

@test "value: --type offers encryption types" {
  complete_at "kaptain" "encrypt" "--type" ""
  [[ " ${COMPREPLY[*]} " == *" age "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256 "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256.10k "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256.100k "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256.600k "* ]]
}

@test "value: --type partial filters correctly" {
  complete_at "kaptain" "encrypt" "--type" "sha"
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256 "* ]]
  [[ " ${COMPREPLY[*]} " == *" sha256.aes256.10k "* ]]
  [[ " ${COMPREPLY[*]} " != *" age "* ]]
}

@test "value: --type a<tab> completes to age" {
  complete_at "kaptain" "encrypt" "--type" "a"
  [[ ${#COMPREPLY[@]} -eq 1 ]]
  [[ "${COMPREPLY[0]}" == "age" ]]
}

# --- Value completion: --dir ---

@test "value: --dir offers directories" {
  mkdir -p "${WORK_DIR}/testdirs/alpha"
  mkdir -p "${WORK_DIR}/testdirs/beta"
  cd "${WORK_DIR}/testdirs"
  complete_at "kaptain" "list" "secrets" "--dir" ""
  [[ " ${COMPREPLY[*]} " == *" alpha "* ]]
  [[ " ${COMPREPLY[*]} " == *" beta "* ]]
}

# --- Sub-command completion still works alongside flags ---

@test "sub-commands: kaptain list <tab> still works with flag support" {
  complete_at "kaptain" "list" ""
  [[ " ${COMPREPLY[*]} " == *" secrets "* ]]
  [[ " ${COMPREPLY[*]} " == *" config "* ]]
  [[ " ${COMPREPLY[*]} " == *" manifests "* ]]
}
