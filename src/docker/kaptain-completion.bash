#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kaptain-completion.bash - Bash completion for the kaptain router/impl pattern
#
# Scans KAPTAIN_SCRIPT_DIR for scripts matching the kaptain-* naming convention
# and provides tab completion that understands the routing hierarchy.
#
# At the top level, only short segments (router names) are offered to keep
# the list manageable.  At deeper levels, when a script exists for the short
# segment, both the short and the full remainder are offered so that longer
# leaf names are discoverable alongside the router.
# When no script exists for the first segment, only the full remainder is shown
# to avoid offering non-existent intermediate commands.
#
# Flag and value completion is supported for resolved commands using data
# generated at build time between the GENERATED COMPLETIONS markers below.
#
# Example:
#   kaptain <tab>                → list, clean, encrypt, decrypt, keygen, help
#   kaptain list <tab>           → secrets, config, manifests
#   kaptain list se<tab>         → secrets
#   kaptain list secrets --<tab> → --dir, --all, -v, --verbose, -h, --help
#   kaptain encrypt --type <tab> → age, sha256.aes256, ...
#
# Source this file or add to your bash profile:
#   source kaptain-completion.bash

KAPTAIN_SCRIPT_DIR="${KAPTAIN_SCRIPT_DIR:-$(dirname "$(command -v kaptain 2>/dev/null)")}"

# BEGIN GENERATED COMPLETIONS — do not edit by hand
_kaptain_flags() {
  case "$1" in
    kaptain-clean)                      echo "--help -h" ;;
    kaptain-list)                       echo "--help -h" ;;
    kaptain-decrypt)                    echo "--dir --help --type -h" ;;
    kaptain-decrypt-age)                echo "--dir --help --key-file -h" ;;
    kaptain-decrypt-sha256.aes256)      echo "--dir --help --key-file -h" ;;
    kaptain-decrypt-sha256.aes256.100k) echo "--dir --help --key-file -h" ;;
    kaptain-decrypt-sha256.aes256.10k)  echo "--dir --help --key-file -h" ;;
    kaptain-decrypt-sha256.aes256.600k) echo "--dir --help --key-file -h" ;;
    kaptain-encrypt)                    echo "--dir --help --type -h" ;;
    kaptain-encrypt-age)                echo "--dir --help --key-file -h" ;;
    kaptain-encrypt-sha256.aes256)      echo "--dir --help --key-file -h" ;;
    kaptain-encrypt-sha256.aes256.100k) echo "--dir --help --key-file -h" ;;
    kaptain-encrypt-sha256.aes256.10k)  echo "--dir --help --key-file -h" ;;
    kaptain-encrypt-sha256.aes256.600k) echo "--dir --help --key-file -h" ;;
    kaptain-encryption-check-ignores)   echo "--dir" ;;
    kaptain-keygen)                     echo "--help --output --type -h" ;;
    kaptain-rotate-key-for-secrets)     echo "--ask-for-key --dir --help --new-type --output -h" ;;
    kaptain-clean-secrets)              echo "--all --dir --dry-run --help -h" ;;
    kaptain-list-config)                echo "--all --dir --help -h" ;;
    kaptain-list-manifests)             echo "--all --dir --help -h" ;;
    kaptain-list-secrets)               echo "--all --dir --help --verbose -h -v" ;;
  esac
}
_kaptain_type_values="age sha256.aes256 sha256.aes256.100k sha256.aes256.10k sha256.aes256.600k"
# END GENERATED COMPLETIONS — do not edit by hand

_kaptain_completions() {
  local cmd="${1}"
  local cur="${2}"
  local prev="${3}"

  # Build prefix from command name + non-flag args joined with hyphens
  # Sub-commands always precede flags, so stop at first -* word
  # e.g., "kaptain" with args ["list", "secrets", "--dir", "foo"] → prefix "kaptain-list-secrets"
  local prefix="${cmd}"
  local i
  for ((i = 1; i < COMP_CWORD; i++)); do
    [[ "${COMP_WORDS[i]}" == -* ]] && break
    prefix="${prefix}-${COMP_WORDS[i]}"
  done

  # Value completion for flags that take arguments
  case "${prev}" in
    --dir)
      COMPREPLY=($(compgen -d -- "${cur}" 2>/dev/null)) || true
      return
      ;;
    --type)
      COMPREPLY=($(compgen -W "${_kaptain_type_values}" -- "${cur}" 2>/dev/null)) || true
      return
      ;;
    --key-file)
      COMPREPLY=($(compgen -f -- "${cur}" 2>/dev/null)) || true
      return
      ;;
    --output)
      COMPREPLY=($(compgen -f -- "${cur}" 2>/dev/null)) || true
      return
      ;;
  esac

  # Flag completion when current word starts with -
  if [[ "${cur}" == -* ]]; then
    local flags
    flags=$(_kaptain_flags "${prefix##*/}")
    if [[ -n "${flags}" ]]; then
      COMPREPLY=($(compgen -W "${flags}" -- "${cur}" 2>/dev/null)) || true
      return
    fi
  fi

  # Sub-command completion — find scripts matching prefix-* and extract segments
  local completions=()
  local seen=()
  local file segment
  for file in "${KAPTAIN_SCRIPT_DIR}/${prefix}-"*; do
    [[ -e "${file}" ]] || continue
    file="$(basename "${file}")"
    # Strip the prefix and leading hyphen to get the remainder
    local remainder="${file#"${prefix}-"}"
    # Extract first segment (up to next hyphen, or the whole thing)
    segment="${remainder%%-*}"

    # Build list of candidates to add
    local candidates=()

    if [[ "${segment}" == "${remainder}" ]]; then
      # Single segment, no ambiguity
      candidates+=("${remainder}")
    elif [[ -x "${KAPTAIN_SCRIPT_DIR}/${prefix}-${segment}" ]]; then
      # Script exists for short segment
      if [[ ${COMP_CWORD} -ge 2 ]]; then
        # Deeper levels — offer both short and full so longer leaves
        # are discoverable alongside the router
        candidates+=("${segment}" "${remainder}")
      else
        # Top level — just offer the short segment to keep it clean
        candidates+=("${segment}")
      fi
    else
      # No script for short segment — only offer the full remainder
      candidates+=("${remainder}")
    fi

    # Deduplicate and add
    local candidate
    for candidate in "${candidates[@]}"; do
      local already=false
      local s
      for s in "${seen[@]+"${seen[@]}"}"; do
        if [[ "${s}" == "${candidate}" ]]; then
          already=true
          break
        fi
      done
      if [[ "${already}" == "false" ]]; then
        seen+=("${candidate}")
        completions+=("${candidate}")
      fi
    done
  done

  COMPREPLY=($(compgen -W "${completions[*]}" -- "${cur}" 2>/dev/null)) || true
}

complete -F _kaptain_completions kaptain
