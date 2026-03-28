#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Recreate src/flat/ copies from src/scripts/*/* and verify no git changes
#
# Each script in src/scripts/<type>/<script> gets copied to
# src/flat/<script>

set -euo pipefail

FLAT_DIR="src/flat"

# Remove and recreate the flat directory
rm -rf "${FLAT_DIR}"
mkdir -p "${FLAT_DIR}"

# Write warning file
cat > "${FLAT_DIR}/WarningDoNotEdit.md" <<'EOF'
# Do Not Edit Files In This Directory

These are auto-generated copies of scripts from `src/scripts/*/`.

Edit the originals there, not these files.

# Why They Are Here

This directory exists so that users can clone the repo and add `src/flat/` to
their `PATH` to get all commands available without needing to install anything.

Regenerated and verified by `.github/bin/verify-flat-symlinks.bash` which is in
turn called by `.github/bin/run-tests.bash` which is called by the build process
on every PR to force these to be kept up-to-date.
EOF

# Copy every script into flat
for script in src/scripts/*/*; do
  cp "${script}" "${FLAT_DIR}/"
done

# Verify no git changes in src/flat/ compared to HEAD
if ! git diff --quiet HEAD -- "${FLAT_DIR}"; then
  echo "ERROR: src/flat/ flat scripts are out of date. Commit the changes." >&2
  exit 1
fi

# Check for untracked files in src/flat/
untracked="$(git ls-files --others --exclude-standard -- "${FLAT_DIR}")"
if [[ -n "${untracked}" ]]; then
  echo "ERROR: src/flat/ has untracked files:" >&2
  echo "${untracked}" >&2
  exit 1
fi

echo "src/flat/ flat scripts are up to date."
