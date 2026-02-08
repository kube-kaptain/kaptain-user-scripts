#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Package scripts for release - creates zip bundles for Homebrew formulas
#
# Creates:
#   kaptain-user-scripts.zip           - all scripts (cli + encryption)
#   kaptain-user-scripts-cli.zip       - cli scripts only
#   kaptain-user-scripts-encryption.zip - encryption scripts only
#   kaptain-user-scripts-42.zip        - for meta package in brew (cannot install nothing)
#
# Each zip contains scripts/* at the root.

set -euo pipefail

PACKAGE_DIR="${OUTPUT_SUB_PATH}/user-scripts"
SCRIPTS="src/scripts"

if [[ -z "${VERSION:-}" ]]; then
  echo "ERROR: VERSION environment variable is required" >&2
  exit 1
fi

echo "Packaging scripts for release..."
echo "  Version: ${VERSION}"
echo "  Source:  ${SCRIPTS}"
echo "  Output:  ${DOCKER_CONTEXT_SUB_PATH}"

# Clean and create output directories
rm -rf "${PACKAGE_DIR}"
mkdir -p "${DOCKER_CONTEXT_SUB_PATH}"
mkdir -p "${PACKAGE_DIR}/cli/scripts"
mkdir -p "${PACKAGE_DIR}/encryption/scripts"
mkdir -p "${PACKAGE_DIR}/all/scripts"
mkdir -p "${PACKAGE_DIR}/42/scripts"

echo "Copying all scripts..."
cp "${SCRIPTS}/cli/"* "${PACKAGE_DIR}/all/scripts/"
cp "${SCRIPTS}/encryption/"* "${PACKAGE_DIR}/all/scripts/"
cd "${PACKAGE_DIR}/all"
zip -r kaptain-user-scripts.zip scripts/
cd -
cp "${PACKAGE_DIR}/all/kaptain-user-scripts.zip" "${DOCKER_CONTEXT_SUB_PATH}/kaptain-user-scripts-${VERSION}.zip"
echo "  Created: kaptain-user-scripts.zip"

echo "Copying cli scripts..."
cp "${SCRIPTS}/cli/kaptain" "${PACKAGE_DIR}/cli/scripts/"
cp "${SCRIPTS}/cli/kaptain-help" "${PACKAGE_DIR}/cli/scripts/"
cp "${SCRIPTS}/cli/kaptain-clean" "${PACKAGE_DIR}/cli/scripts/"
cd "${PACKAGE_DIR}/cli"
zip -r kaptain-user-scripts-cli.zip scripts/
cd -
cp "${PACKAGE_DIR}/cli/kaptain-user-scripts-cli.zip" "${DOCKER_CONTEXT_SUB_PATH}/kaptain-user-scripts-cli-${VERSION}.zip"
echo "  Created: kaptain-user-scripts-cli.zip"

echo "Copying encryption scripts..."
cp "${SCRIPTS}/encryption/"* "${PACKAGE_DIR}/encryption/scripts/"
cd "${PACKAGE_DIR}/encryption"
zip -r kaptain-user-scripts-encryption.zip scripts/
cd -
cp "${PACKAGE_DIR}/encryption/kaptain-user-scripts-encryption.zip" "${DOCKER_CONTEXT_SUB_PATH}/kaptain-user-scripts-encryption-${VERSION}.zip"
echo "  Created: kaptain-user-scripts-encryption.zip"

echo "Copying 42 script..."
cp "${SCRIPTS}/cli/kaptain-42" "${PACKAGE_DIR}/42/scripts/"
cd "${PACKAGE_DIR}/42"
zip -r kaptain-user-scripts-42.zip scripts/
cd -
cp "${PACKAGE_DIR}/42/kaptain-user-scripts-42.zip" "${DOCKER_CONTEXT_SUB_PATH}/kaptain-user-scripts-42-${VERSION}.zip"
echo "  Created: kaptain-user-scripts-42.zip"

echo ""
echo "Done. Archives created and copied to ${DOCKER_CONTEXT_SUB_PATH}:"
ls -la "${PACKAGE_DIR}"/*/*.zip
ls -la "${DOCKER_CONTEXT_SUB_PATH}"/*.zip
