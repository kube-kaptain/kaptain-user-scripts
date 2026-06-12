#compdef kaptain
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kaptain-completion.zsh - Zsh completion for the kaptain router/impl pattern
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
# Source this file or add to your zsh fpath:
#   fpath=(/path/to/dir $fpath); autoload -Uz compinit && compinit

KAPTAIN_SCRIPT_DIR="${KAPTAIN_SCRIPT_DIR:-$(dirname "$(command -v kaptain 2>/dev/null)")}"

# BEGIN GENERATED COMPLETIONS — do not edit by hand
_kaptain_flags() {
  case "$1" in
    kaptain-build)                      echo "--help -h" ;;
    kaptain-clean-project)              echo "--dir --help -h" ;;
    kaptain-update)                     echo "--help -h" ;;
    kaptain-update-versions)            echo "--all --api-version --debug --dry-run --file --help --no-update-lower-bounds --update-all --update-fixed --update-lower-bounds --update-ranges -h" ;;
    kaptain-clean)                      echo "--help -h" ;;
    kaptain-list)                       echo "--help -h" ;;
    kaptain-setup)                      echo "--help -h" ;;
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
    kaptain-clean-images)               echo "--all --all-same-reg-ns --dry-run --exclude-prereleases --exclude-releases --extra-prefixes --help --include-prereleases --include-releases --prefix -h" ;;
    kaptain-clean-secrets)              echo "--all --dir --dry-run --help -h" ;;
    kaptain-list-config)                echo "--all --defaults-dir --dir --help -h" ;;
    kaptain-list-images)                echo "--all --all-same-reg-ns --exclude-prereleases --exclude-releases --extra-prefixes --help --include-prereleases --include-releases --prefix -h" ;;
    kaptain-list-manifests)             echo "--all --dir --help -h" ;;
    kaptain-list-secrets)               echo "--all --dir --help --verbose -h -v" ;;
    kaptain-setup-brew)                 echo "--apps-in-home --copy-fred --help -h" ;;
  esac
}
_kaptain_type_values="age sha256.aes256 sha256.aes256.100k sha256.aes256.10k sha256.aes256.600k"
# END GENERATED COMPLETIONS — do not edit by hand

_kaptain() {
  local cmd="${words[1]}"
  local cur="${words[CURRENT]}"
  local prev="${words[CURRENT-1]}"

  # Build prefix from command name + non-flag args joined with hyphens
  local prefix="${cmd}"
  local i
  for ((i = 2; i < CURRENT; i++)); do
    [[ "${words[i]}" == -* ]] && break
    prefix="${prefix}-${words[i]}"
  done

  # Value completion for flags that take arguments
  case "${prev}" in
    --dir)
      _path_files -/
      return
      ;;
    --type)
      local -a types
      types=(${=_kaptain_type_values})
      compadd -a types
      return
      ;;
    --key-file|--output)
      _path_files
      return
      ;;
  esac

  # Flag completion when current word starts with -
  if [[ "${cur}" == -* ]]; then
    local flags
    flags=$(_kaptain_flags "${prefix##*/}")
    if [[ -n "${flags}" ]]; then
      local -a flag_arr
      flag_arr=(${=flags})
      compadd -a flag_arr
      return
    fi
  fi

  # Leaf-script fallback: when the resolved prefix names an executable script,
  # also offer its flags so an empty tab tab at a leaf still lists options.
  local leaf_flags=""
  if [[ -x "${KAPTAIN_SCRIPT_DIR}/${prefix##*/}" ]]; then
    leaf_flags=$(_kaptain_flags "${prefix##*/}")
  fi

  # Sub-command completion — find scripts matching prefix-* and extract segments
  local -a completions seen
  local file remainder segment candidate s already
  local -a candidates
  for file in "${KAPTAIN_SCRIPT_DIR}/${prefix}-"*(N); do
    file="${file:t}"
    remainder="${file#${prefix}-}"
    segment="${remainder%%-*}"

    candidates=()
    if [[ "${segment}" == "${remainder}" ]]; then
      candidates+=("${remainder}")
    elif [[ -x "${KAPTAIN_SCRIPT_DIR}/${prefix}-${segment}" ]]; then
      if (( CURRENT >= 3 )); then
        candidates+=("${segment}" "${remainder}")
      else
        candidates+=("${segment}")
      fi
    else
      candidates+=("${remainder}")
    fi

    for candidate in "${candidates[@]}"; do
      already=false
      for s in "${seen[@]}"; do
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

  # Merge leaf flags in (deduplicated against any same-named subcommands)
  if [[ -n "${leaf_flags}" ]]; then
    local f
    for f in ${=leaf_flags}; do
      already=false
      for s in "${seen[@]}"; do
        if [[ "${s}" == "${f}" ]]; then
          already=true
          break
        fi
      done
      if [[ "${already}" == "false" ]]; then
        seen+=("${f}")
        completions+=("${f}")
      fi
    done
  fi

  compadd -a completions
}

compdef _kaptain kaptain
