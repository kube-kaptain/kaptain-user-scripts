#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for kaptain-list-images

CLI_SCRIPTS_DIR="src/scripts/cli"
ENC_SCRIPTS_DIR="src/scripts/encryption"
UTIL_SCRIPTS_DIR="src/scripts/util"
BUILD_SCRIPTS_DIR="src/scripts/build"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"

setup() {
  TEST_LIST_IMAGES="${OUTPUT_SUB_PATH}/test/list-images"
  TEST_BIN="${TEST_LIST_IMAGES}/bin"
  FAKE_BIN="${TEST_LIST_IMAGES}/fake-bin"
  FAKE_LOG_DIR="${TEST_LIST_IMAGES}/fake-logs"
  FAKE_BUILD_ROOT="${TEST_LIST_IMAGES}/fake-build-root"

  TEST_BIN_ABS="$(pwd)/${TEST_BIN}"
  FAKE_BIN_ABS="$(pwd)/${FAKE_BIN}"
  FAKE_LOG_DIR_ABS="$(pwd)/${FAKE_LOG_DIR}"
  FAKE_BUILD_ROOT_ABS="$(pwd)/${FAKE_BUILD_ROOT}"
  IMAGES_FIXTURE_ABS="${FAKE_LOG_DIR_ABS}/images"

  rm -rf "${TEST_LIST_IMAGES}"
  mkdir -p "${TEST_BIN}" "${FAKE_BIN}" "${FAKE_LOG_DIR}" "${FAKE_BUILD_ROOT}"

  cp "${CLI_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
  cp "${ENC_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
  cp "${UTIL_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"
  cp "${BUILD_SCRIPTS_DIR}"/kaptain-* "${TEST_BIN}/"

  make_fake_build_root "${FAKE_BUILD_ROOT}"
}

make_fake_engine() {
  local name="$1"
  cat > "${FAKE_BIN}/${name}" <<EOF
#!/usr/bin/env bash
set -u
log_dir="${FAKE_LOG_DIR_ABS}"
images_file="${IMAGES_FIXTURE_ABS}"
echo "\$(basename "\$0") \$*" >> "\${log_dir}/calls"
case "\${1:-}" in
  images)
    if [[ -f "\${images_file}" ]]; then
      cat "\${images_file}"
    fi
    ;;
esac
EOF
  chmod +x "${FAKE_BIN}/${name}"
}

make_fake_build_root() {
  local root="$1"
  mkdir -p "${root}/src/scripts/lib"
  cat > "${root}/src/scripts/lib/detect-build-context.bash" <<'EOF'
export DOCKER_TARGET_REGISTRY="${TEST_DTR:-ghcr.io}"
export DOCKER_TARGET_NAMESPACE="${TEST_DTN:-kube-kaptain}"
export REPOSITORY_NAME="${TEST_REPO_NAME:-kaptain-user-scripts}"
export REPOSITORY_OWNER="${TEST_REPO_OWNER:-kube-kaptain}"
EOF
  cat > "${root}/src/scripts/lib/docker-ref-expand.bash" <<'EOF'
docker_ref_extract_prefix() {
  local name="${1##*/}"
  echo "${name%%-*}"
}
docker_ref_expand() {
  local ref="$1"
  local name="${ref%:*}"
  local prefix
  prefix=$(docker_ref_extract_prefix "${name}")
  DOCKER_REF_FULL_NAME="${DOCKER_TARGET_REGISTRY}/${DOCKER_TARGET_NAMESPACE}/${prefix}/${name}"
  DOCKER_REF_NAME_PART="${name}"
  DOCKER_REF_VERSION_PART="${ref##*:}"
  DOCKER_REF_FORM="short"
  return 0
}
EOF
}

write_images() {
  printf '%s\n' "$@" > "${IMAGES_FIXTURE_ABS}"
}

# =============================================================================
# Help and arg parsing
# =============================================================================

@test "list-images: --help shows usage and exits 0" {
  run "${TEST_BIN}/kaptain-list-images" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kaptain list images"* ]]
  [[ "$output" == *"--all"* ]]
  [[ "$output" == *"--include-releases"* ]]
  [[ "$output" == *"--exclude-prereleases"* ]]
}

@test "list-images: unknown option fails" {
  run "${TEST_BIN}/kaptain-list-images" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "list-images: --all and --extra-prefixes mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --extra-prefixes=ecr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "list-images: --all and --all-same-reg-ns mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --all-same-reg-ns
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

# =============================================================================
# Default tag classes (everything)
# =============================================================================

@test "list-images: --all default lists both releases and prereleases" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0" \
    "alpine:3.20"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Engine: podman"* ]]
  [[ "$output" == *"Match scope: all images on this machine"* ]]
  [[ "$output" == *"Tag classes: releases + prereleases"* ]]
  [[ "$output" == *"ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"* ]]
  [[ "$output" == *"ghcr.io/kube-kaptain/kaptain/foo:1.0.0"* ]]
  [[ "$output" == *"alpine:3.20"* ]]
  [[ "$output" == *"3 matching images across 2 repositories."* ]]
}

@test "list-images: no engine calls rmi or prune" {
  make_fake_engine podman
  write_images "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all
  [ "$status" -eq 0 ]
  ! grep -q 'rmi' "${FAKE_LOG_DIR}/calls"
  ! grep -q 'prune' "${FAKE_LOG_DIR}/calls"
}

# =============================================================================
# Tag-class flags
# =============================================================================

@test "list-images: --exclude-releases lists only prereleases" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0" \
    "ghcr.io/kube-kaptain/kaptain/bar:2.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --exclude-releases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: PRERELEASE only"* ]]
  [[ "$output" == *"foo:1.0.0-PRERELEASE"* ]]
  [[ "$output" != *"foo:1.0.0"$'\n'* ]] || true
  [[ "$output" == *"1 PRERELEASE image across 1 repository."* ]]
}

@test "list-images: --exclude-prereleases lists only releases" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0" \
    "ghcr.io/kube-kaptain/kaptain/bar:2.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --exclude-prereleases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: releases only"* ]]
  [[ "$output" == *"foo:1.0.0"* ]]
  [[ "$output" == *"bar:2.0.0"* ]]
  [[ "$output" == *"2 release images across 2 repositories."* ]]
}

@test "list-images: --exclude-releases --exclude-prereleases yields empty match" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --exclude-releases --exclude-prereleases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: none (prune only)"* ]]
  [[ "$output" == *"no (none — prune only) images"* ]]
}

@test "list-images: --include-releases is no-op (already default)" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --include-releases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: releases + prereleases"* ]]
  [[ "$output" == *"2 matching images"* ]]
}

@test "list-images: --include-prereleases is no-op (already default)" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --include-prereleases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: releases + prereleases"* ]]
  [[ "$output" == *"2 matching images"* ]]
}

@test "list-images: --include-releases + --exclude-releases contradictory" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --include-releases --exclude-releases
  [ "$status" -eq 1 ]
  [[ "$output" == *"contradictory"* ]]
}

@test "list-images: --include-prereleases + --exclude-prereleases contradictory" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --include-prereleases --exclude-prereleases
  [ "$status" -eq 1 ]
  [[ "$output" == *"contradictory"* ]]
}

# =============================================================================
# Scope: default mode (no prompt) and extra-prefixes
# =============================================================================

@test "list-images: default mode uses build-libs prefix without prompting" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0" \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE" \
    "ghcr.io/other-org/foo/bar:1.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT_ABS}" "${TEST_BIN_ABS}/kaptain-list-images"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Match scope: ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts/"* ]]
  [[ "$output" != *"Image prefix"* ]]
  [[ "$output" == *"kaptain-user-scripts:1.0.0"* ]]
  [[ "$output" == *"kaptain-user-scripts:1.0.0-PRERELEASE"* ]]
  [[ "$output" != *"other-org"* ]]
  [[ "$output" == *"2 matching images across 1 repository."* ]]
}

@test "list-images: default mode requires BUILD_ROOT" {
  make_fake_engine podman
  run env -u KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT \
    PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" \
    "${TEST_BIN_ABS}/kaptain-list-images"
  [ "$status" -eq 1 ]
  [[ "$output" == *"KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT is not set"* ]]
}

@test "list-images: --prefix=X combined with --extra-prefixes adds them" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0" \
    "ecr/team/bar:2.0.0-PRERELEASE" \
    "acr/team/baz:3.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --prefix=ecr/team --extra-prefixes=acr/team
  [ "$status" -eq 0 ]
  [[ "$output" == *"Match scope: ecr/team/, acr/team/"* ]]
  [[ "$output" == *"ecr/team/bar:2.0.0-PRERELEASE"* ]]
  [[ "$output" == *"acr/team/baz:3.0.0"* ]]
  [[ "$output" != *"ghcr.io"* ]]
  [[ "$output" == *"2 matching images across 2 repositories."* ]]
}

@test "list-images: empty result reports no images" {
  make_fake_engine podman
  write_images "alpine:3.20"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --prefix=ghcr.io/kube-kaptain
  [ "$status" -eq 0 ]
  [[ "$output" == *"no matching images for ghcr.io/kube-kaptain/"* ]]
}

@test "list-images: --extra-prefixes alone is rejected" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --extra-prefixes=ecr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"--extra-prefixes must combine with"* ]]
}

@test "list-images: --prefix=X alone matches only X" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0" \
    "ecr/team/bar:2.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --prefix=ecr/team
  [ "$status" -eq 0 ]
  [[ "$output" == *"Match scope: ecr/team/"* ]]
  [[ "$output" == *"ecr/team/bar:2.0.0"* ]]
  [[ "$output" != *"ghcr.io"* ]]
}

@test "list-images: --prefix and --all mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all --prefix=ecr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"--all and --prefix are mutually exclusive"* ]]
}

@test "list-images: --prefix and --all-same-reg-ns mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --all-same-reg-ns --prefix=ecr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"--all-same-reg-ns and --prefix are mutually exclusive"* ]]
}

@test "list-images: --prefix rejects invalid value" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-list-images" --prefix=ecr/team:foo
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid --prefix"* ]]
}
