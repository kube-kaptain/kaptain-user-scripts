#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Generate completion data from script case blocks into kaptain-completion.bash
#
# Scans src/scripts/ for kaptain-* scripts, extracts flags from case patterns,
# discovers encryption type values, and writes the data between markers in the
# completion script.
#
# Usage:
#   generate-completions.bash           # Update completion script in-place
#   generate-completions.bash --check   # Exit non-zero if completion data is stale

set -euo pipefail

SCRIPTS_DIR="src/scripts"
COMPLETION_SCRIPT="src/docker/kaptain-completion.bash"

BEGIN_MARKER="# BEGIN GENERATED COMPLETIONS — do not edit by hand"
END_MARKER="# END GENERATED COMPLETIONS — do not edit by hand"

CHECK_MODE=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=true
fi

if [[ ! -d "${SCRIPTS_DIR}" ]]; then
  echo "ERROR: Scripts directory not found: ${SCRIPTS_DIR}" >&2
  exit 1
fi

if [[ ! -f "${COMPLETION_SCRIPT}" ]]; then
  echo "ERROR: Completion script not found: ${COMPLETION_SCRIPT}" >&2
  exit 1
fi

# Extract flags from a script's case patterns
# Matches lines like: "    --dir)"  or  "    -h|--help)"
# These are case patterns ending with ) — not heredoc text or echo strings
extract_flags() {
  local script="$1"
  grep -E '^\s+--?[a-z][a-z|-]*\)' "${script}" \
    | grep -oE '\-\-?[a-z][-a-z]*' \
    | sort -u \
    | tr '\n' ' ' \
    | sed 's/ $//'
}

# Discover encryption type values from encrypt script names
discover_types() {
  local types=()
  for script in "${SCRIPTS_DIR}"/encryption/kaptain-encrypt-*; do
    [[ -f "${script}" ]] || continue
    local name
    name="$(basename "${script}")"
    local type="${name#kaptain-encrypt-}"
    types+=("${type}")
  done
  # Sort for deterministic output
  printf '%s\n' "${types[@]}" | sort | tr '\n' ' ' | sed 's/ $//'
}

# Build the generated section
generate_section() {
  echo "${BEGIN_MARKER}"
  echo '_kaptain_flags() {'
  echo '  case "$1" in'

  # Find all scripts with case-block flags, sorted by name
  local entries=()
  while IFS= read -r -d '' script; do
    local name
    name="$(basename "${script}")"
    local flags
    flags=$(extract_flags "${script}")
    if [[ -n "${flags}" ]]; then
      entries+=("${name}|${flags}")
    fi
  done < <(find "${SCRIPTS_DIR}" -name 'kaptain-*' -type f -print0 | sort -z)

  # Find longest name for padding
  local max_len=0
  for entry in "${entries[@]}"; do
    local name="${entry%%|*}"
    if [[ ${#name} -gt ${max_len} ]]; then
      max_len=${#name}
    fi
  done
  local pad=$((max_len + 1))

  for entry in "${entries[@]}"; do
    local name="${entry%%|*}"
    local flags="${entry#*|}"
    printf '    %-'"${pad}"'s echo "%s" ;;\n' "${name})" "${flags}"
  done

  echo '  esac'
  echo '}'
  echo "_kaptain_type_values=\"$(discover_types)\""
  echo "${END_MARKER}"
}

# Read current generated section from the completion script
current_section() {
  sed -n "/${BEGIN_MARKER}/,/${END_MARKER}/p" "${COMPLETION_SCRIPT}"
}

# Generate new section
new_section=$(generate_section)
old_section=$(current_section)

if [[ "${CHECK_MODE}" == "true" ]]; then
  if [[ "${new_section}" == "${old_section}" ]]; then
    echo "Completion data is up to date"
    exit 0
  else
    echo "ERROR: Completion data is stale" >&2
    echo "Run: .github/bin/generate-completions.bash" >&2
    exit 1
  fi
fi

# Replace the section between markers in the completion script
# Strategy: print lines before BEGIN, print new section, print lines after END
{
  sed -n "1,/${BEGIN_MARKER}/{ /${BEGIN_MARKER}/!p; }" "${COMPLETION_SCRIPT}"
  echo "${new_section}"
  sed -n "/${END_MARKER}/,\${ /${END_MARKER}/!p; }" "${COMPLETION_SCRIPT}"
} > "${COMPLETION_SCRIPT}.tmp"

mv "${COMPLETION_SCRIPT}.tmp" "${COMPLETION_SCRIPT}"
echo "Updated ${COMPLETION_SCRIPT}"
