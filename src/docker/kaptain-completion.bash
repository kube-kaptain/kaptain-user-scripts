#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kaptain-completion.bash - Bash completion for the kaptain router/impl pattern
#
# Scans KAPTAIN_SCRIPT_DIR for scripts matching the kaptain-* naming convention
# and provides tab completion that understands the routing hierarchy.
#
# Example:
#   kaptain <tab>        → list, clean, encrypt, decrypt, keygen, help
#   kaptain list <tab>   → secrets, config
#   kaptain list se<tab> → secrets
#
# Source this file or add to your bash profile:
#   source kaptain-completion.bash

KAPTAIN_SCRIPT_DIR="${KAPTAIN_SCRIPT_DIR:-$(dirname "$(command -v kaptain 2>/dev/null)")}"

_kaptain_completions() {
  local cmd="${1}"
  local cur="${2}"
  local prev="${3}"

  # Build prefix from command name + all completed args joined with hyphens
  # e.g., "kaptain" with args ["list"] → prefix "kaptain-list"
  local prefix="${cmd}"
  local i
  for ((i = 1; i < COMP_CWORD; i++)); do
    prefix="${prefix}-${COMP_WORDS[i]}"
  done

  # Find all files matching prefix-* and extract the next segment
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
    # Deduplicate
    local already=false
    local s
    for s in "${seen[@]+"${seen[@]}"}"; do
      if [[ "${s}" == "${segment}" ]]; then
        already=true
        break
      fi
    done
    if [[ "${already}" == "false" ]]; then
      seen+=("${segment}")
      completions+=("${segment}")
    fi
  done

  COMPREPLY=($(compgen -W "${completions[*]}" -- "${cur}"))
}

complete -F _kaptain_completions kaptain
