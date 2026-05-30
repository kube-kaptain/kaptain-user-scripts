#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for kaptain-clean-images

CLI_SCRIPTS_DIR="src/scripts/cli"
ENC_SCRIPTS_DIR="src/scripts/encryption"
UTIL_SCRIPTS_DIR="src/scripts/util"
BUILD_SCRIPTS_DIR="src/scripts/build"
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"

setup() {
  TEST_CLEAN_IMAGES="${OUTPUT_SUB_PATH}/test/clean-images"
  TEST_BIN="${TEST_CLEAN_IMAGES}/bin"
  FAKE_BIN="${TEST_CLEAN_IMAGES}/fake-bin"
  EMPTY_BIN="${TEST_CLEAN_IMAGES}/empty-bin"
  FAKE_LOG_DIR="${TEST_CLEAN_IMAGES}/fake-logs"
  FAKE_BUILD_ROOT="${TEST_CLEAN_IMAGES}/fake-build-root"

  TEST_BIN_ABS="$(pwd)/${TEST_BIN}"
  FAKE_BIN_ABS="$(pwd)/${FAKE_BIN}"
  EMPTY_BIN_ABS="$(pwd)/${EMPTY_BIN}"
  FAKE_LOG_DIR_ABS="$(pwd)/${FAKE_LOG_DIR}"
  FAKE_BUILD_ROOT_ABS="$(pwd)/${FAKE_BUILD_ROOT}"
  IMAGES_FIXTURE_ABS="${FAKE_LOG_DIR_ABS}/images"
  MANIFESTS_FIXTURE_ABS="${FAKE_LOG_DIR_ABS}/manifests"

  rm -rf "${TEST_CLEAN_IMAGES}"
  mkdir -p "${TEST_BIN}" "${FAKE_BIN}" "${EMPTY_BIN}" "${FAKE_LOG_DIR}" "${FAKE_BUILD_ROOT}"

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
manifests_file="${MANIFESTS_FIXTURE_ABS}"
echo "\$(basename "\$0") \$*" >> "\${log_dir}/calls"
case "\${1:-}" in
  images)
    if [[ -f "\${images_file}" ]]; then
      cat "\${images_file}"
    fi
    ;;
  rmi)
    shift
    printf '%s\n' "\$@" >> "\${log_dir}/rmi"
    ;;
  manifest)
    shift
    case "\${1:-}" in
      exists)
        ref="\${2:-}"
        if [[ -f "\${manifests_file}" ]] && grep -Fxq "\${ref}" "\${manifests_file}"; then
          exit 0
        fi
        exit 1
        ;;
      rm)
        shift
        printf '%s\n' "\$@" > "\${log_dir}/manifest_rm"
        ;;
    esac
    ;;
  image)
    shift
    case "\${1:-}" in
      prune)
        echo "called" > "\${log_dir}/prune"
        ;;
      inspect)
        # Args: --format '{{.MediaType}}' <ref>
        ref="\${4:-\${3:-}}"
        if [[ -f "\${manifests_file}" ]] && grep -Fxq "\${ref}" "\${manifests_file}"; then
          echo "application/vnd.docker.distribution.manifest.list.v2+json"
        else
          echo ""
        fi
        ;;
    esac
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

write_manifests() {
  printf '%s\n' "$@" > "${MANIFESTS_FIXTURE_ABS}"
}

# =============================================================================
# Help and arg parsing
# =============================================================================

@test "clean-images: --help shows usage and exits 0" {
  run "${TEST_BIN}/kaptain-clean-images" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kaptain clean images"* ]]
  [[ "$output" == *"--all"* ]]
  [[ "$output" == *"--all-same-reg-ns"* ]]
  [[ "$output" == *"--extra-prefixes"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "clean-images: -h shows usage and exits 0" {
  run "${TEST_BIN}/kaptain-clean-images" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kaptain clean images"* ]]
}

@test "clean-images: unknown option fails" {
  run "${TEST_BIN}/kaptain-clean-images" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "clean-images: --all and --extra-prefixes mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --extra-prefixes=ecr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "clean-images: --all and --all-same-reg-ns mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --all-same-reg-ns
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

# =============================================================================
# Engine detection
# =============================================================================

@test "clean-images: neither podman nor docker on PATH fails" {
  # /bin has bash (for the shebang) but typically no docker/podman.
  if [[ -x /bin/podman || -x /bin/docker ]]; then
    skip "/bin contains podman or docker on this system"
  fi
  run env PATH=/bin "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"neither podman nor docker"* ]]
}

@test "clean-images: podman preferred when both present" {
  if command -v podman >/dev/null 2>&1 || command -v docker >/dev/null 2>&1; then
    # System binaries can leak in via /usr/bin; skip if PATH would expose them.
    if [[ -x /usr/bin/podman || -x /usr/bin/docker ]]; then
      skip "real /usr/bin/{podman,docker} present"
    fi
  fi
  make_fake_engine podman
  make_fake_engine docker
  write_images "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE"
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Engine: podman"* ]]
  [[ "$output" != *"Engine: docker"* ]]
}

@test "clean-images: docker used when only docker present" {
  if [[ -x /usr/bin/podman ]]; then
    skip "real /usr/bin/podman would shadow the absence test"
  fi
  make_fake_engine docker
  write_images "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE"
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Engine: docker"* ]]
}

# =============================================================================
# --all mode
# =============================================================================

@test "clean-images: --all matches every PRERELEASE tag and ignores BUILD_ROOT" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE" \
    "ghcr.io/other-org/foo/bar:2.0.0-PRERELEASE" \
    "ecr/team/baz:0.1.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0" \
    "alpine:3.20"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Engine: podman"* ]]
  [[ "$output" == *"Match scope: all images on this machine"* ]]
  [[ "$output" == *"Removed 3 images and 0 manifests"* ]]

  # rmi was called once with all three matches
  [ -f "${FAKE_LOG_DIR}/rmi" ]
  local rmi_lines
  rmi_lines=$(wc -l < "${FAKE_LOG_DIR}/rmi" | tr -d ' ')
  [ "${rmi_lines}" -eq 3 ]
  grep -q "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "ghcr.io/other-org/foo/bar:2.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "ecr/team/baz:0.1.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"

  # prune was called
  [ -f "${FAKE_LOG_DIR}/prune" ]

  # Only one rmi call recorded (bulk)
  local rmi_calls
  rmi_calls=$(grep -c '^podman rmi' "${FAKE_LOG_DIR}/calls")
  [ "${rmi_calls}" -eq 1 ]
}

@test "clean-images: --all with no matches still prunes" {
  make_fake_engine podman
  write_images \
    "alpine:3.20" \
    "ghcr.io/kube-kaptain/foo/bar:1.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"no PRERELEASE images for all images on this machine"* ]]
  [ ! -f "${FAKE_LOG_DIR}/rmi" ]
  [ -f "${FAKE_LOG_DIR}/prune" ]
}

@test "clean-images: --all does not require BUILD_ROOT" {
  make_fake_engine podman
  write_images "alpine:3.20-PRERELEASE"
  # Explicitly unset KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT
  run env -u KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT \
    PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" \
    "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
}

# =============================================================================
# Default mode
# =============================================================================

@test "clean-images: default mode happy path uses guess on Enter" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.1.0-PRERELEASE" \
    "ghcr.io/other-org/foo/bar:9.9.9-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:2.0.0"

  run bash -c "echo '' | env PATH='${FAKE_BIN_ABS}:/usr/bin:/bin' KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT='${FAKE_BUILD_ROOT_ABS}' '${TEST_BIN_ABS}/kaptain-clean-images'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Image prefix to clean [*ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts/]"* ]]
  [[ "$output" == *"Match scope: ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts/"* ]]
  [[ "$output" == *"Removed 2 images and 0 manifests"* ]]

  [ -f "${FAKE_LOG_DIR}/rmi" ]
  grep -q "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.1.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "other-org" "${FAKE_LOG_DIR}/rmi"
  [ -f "${FAKE_LOG_DIR}/prune" ]
}

@test "clean-images: default mode no matches prints message and still prunes" {
  make_fake_engine podman
  write_images "alpine:3.20" "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:2.0.0"

  run bash -c "echo '' | env PATH='${FAKE_BIN_ABS}:/usr/bin:/bin' KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT='${FAKE_BUILD_ROOT_ABS}' '${TEST_BIN_ABS}/kaptain-clean-images'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no PRERELEASE images for ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts/"* ]]
  [ ! -f "${FAKE_LOG_DIR}/rmi" ]
  [ -f "${FAKE_LOG_DIR}/prune" ]
}

@test "clean-images: default mode accepts custom prefix on prompt" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE" \
    "myreg/myteam/foo:2.0.0-PRERELEASE"

  run bash -c "echo 'myreg/myteam' | env PATH='${FAKE_BIN_ABS}:/usr/bin:/bin' KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT='${FAKE_BUILD_ROOT_ABS}' '${TEST_BIN_ABS}/kaptain-clean-images'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Match scope: myreg/myteam/"* ]]
  [[ "$output" == *"Removed 1 image and 0 manifests"* ]]
  grep -q "myreg/myteam/foo:2.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "kaptain-user-scripts" "${FAKE_LOG_DIR}/rmi"
}

@test "clean-images: default mode rejects invalid prompt input then exits" {
  make_fake_engine podman
  write_images "x:y-PRERELEASE"

  run bash -c "printf 'bad:colon\n/leading\n' | env PATH='${FAKE_BIN_ABS}:/usr/bin:/bin' KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT='${FAKE_BUILD_ROOT_ABS}' '${TEST_BIN_ABS}/kaptain-clean-images'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid prefix"* ]]
  [[ "$output" == *"too many invalid attempts"* ]]
}

@test "clean-images: default mode requires BUILD_ROOT" {
  make_fake_engine podman
  run env -u KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT \
    PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" \
    "${TEST_BIN_ABS}/kaptain-clean-images"
  [ "$status" -eq 1 ]
  [[ "$output" == *"KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT is not set"* ]]
}

# =============================================================================
# --all-same-reg-ns mode
# =============================================================================

@test "clean-images: --all-same-reg-ns matches reg/ns and prompts nothing" {
  make_fake_engine podman
  local fake_home="${TEST_CLEAN_IMAGES}/fake-home"
  local branchout_root="${fake_home}/projects/kaptain"
  local cwd="${branchout_root}/kaptain/kaptain-user-scripts"
  mkdir -p "${cwd}"
  touch "${branchout_root}/Branchoutfile" "${branchout_root}/Branchoutprojects"

  write_images \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/kaptain-something-else:1.0.0-PRERELEASE" \
    "ghcr.io/other-org/x/y:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:2.0.0"

  run bash -c "cd '$(pwd)/${cwd}' && HOME='$(pwd)/${fake_home}' env PATH='${FAKE_BIN_ABS}:/usr/bin:/bin' KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT='${FAKE_BUILD_ROOT_ABS}' HOME='$(pwd)/${fake_home}' '${TEST_BIN_ABS}/kaptain-clean-images' --all-same-reg-ns"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branchout root:"* ]]
  [[ "$output" == *"Match scope: ghcr.io/kube-kaptain/"* ]]
  [[ "$output" != *"Image prefix to clean"* ]]
  [[ "$output" == *"Removed 2 images and 0 manifests"* ]]
  grep -q "kaptain-user-scripts:1.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "kaptain-something-else:1.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "other-org" "${FAKE_LOG_DIR}/rmi"
}

@test "clean-images: --all-same-reg-ns fails outside Branchout tree" {
  make_fake_engine podman
  local fake_home="${TEST_CLEAN_IMAGES}/fake-home-nobranch"
  mkdir -p "${fake_home}/projects/kaptain/kaptain/kaptain-user-scripts"
  # No Branchoutfile/Branchoutprojects anywhere

  run bash -c "cd '$(pwd)/${fake_home}/projects/kaptain/kaptain/kaptain-user-scripts' && HOME='$(pwd)/${fake_home}' env PATH='${FAKE_BIN_ABS}:/usr/bin:/bin' KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT='${FAKE_BUILD_ROOT_ABS}' HOME='$(pwd)/${fake_home}' '${TEST_BIN_ABS}/kaptain-clean-images' --all-same-reg-ns"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires a Branchout tree"* ]]
}

@test "clean-images: --all-same-reg-ns with --extra-prefixes unions" {
  make_fake_engine podman
  local fake_home="${TEST_CLEAN_IMAGES}/fake-home-union"
  local branchout_root="${fake_home}/projects/kaptain"
  local cwd="${branchout_root}/kaptain/kaptain-user-scripts"
  mkdir -p "${cwd}"
  touch "${branchout_root}/Branchoutfile" "${branchout_root}/Branchoutprojects"

  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ecr/team/bar:2.0.0-PRERELEASE" \
    "acr/team/baz:3.0.0-PRERELEASE" \
    "ghcr.io/other-org/x:1.0.0-PRERELEASE"

  run bash -c "cd '$(pwd)/${cwd}' && HOME='$(pwd)/${fake_home}' env PATH='${FAKE_BIN_ABS}:/usr/bin:/bin' KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT='${FAKE_BUILD_ROOT_ABS}' HOME='$(pwd)/${fake_home}' '${TEST_BIN_ABS}/kaptain-clean-images' --all-same-reg-ns --extra-prefixes=ecr/team,acr/team"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Match scope: ghcr.io/kube-kaptain/, ecr/team/, acr/team/"* ]]
  [[ "$output" == *"Removed 3 images and 0 manifests"* ]]
  grep -q "kaptain/foo:1.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "ecr/team/bar:2.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "acr/team/baz:3.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "other-org" "${FAKE_LOG_DIR}/rmi"
}

# =============================================================================
# --prefix (single, replaces base)
# =============================================================================

@test "clean-images: --prefix=X alone matches only X" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ecr/team/bar:2.0.0-PRERELEASE" \
    "acr/team/baz:3.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr/team
  [ "$status" -eq 0 ]
  [[ "$output" == *"Match scope: ecr/team/"* ]]
  [[ "$output" == *"Removed 1 image and 0 manifests"* ]]
  grep -q "ecr/team/bar:2.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "ghcr.io" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "acr/team" "${FAKE_LOG_DIR}/rmi"
}

@test "clean-images: --prefix=X combined with --extra-prefixes adds them" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ecr/team/bar:2.0.0-PRERELEASE" \
    "acr/team/baz:3.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr/team --extra-prefixes=acr/team
  [ "$status" -eq 0 ]
  [[ "$output" == *"Match scope: ecr/team/, acr/team/"* ]]
  [[ "$output" == *"Removed 2 images and 0 manifests"* ]]
  grep -q "ecr/team/bar:2.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "acr/team/baz:3.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "ghcr.io" "${FAKE_LOG_DIR}/rmi"
}

@test "clean-images: --prefix=X anchors with trailing slash (no substring leak)" {
  make_fake_engine podman
  write_images \
    "ecr/team/bar:1.0.0-PRERELEASE" \
    "ecrtypo/team/bar:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 1 image and 0 manifests"* ]]
  grep -q "ecr/team/bar:1.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "ecrtypo" "${FAKE_LOG_DIR}/rmi"
}

@test "clean-images: --prefix=X does not require BUILD_ROOT" {
  make_fake_engine podman
  write_images "ecr/team/bar:1.0.0-PRERELEASE"
  run env -u KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT \
    PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" \
    "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr/team
  [ "$status" -eq 0 ]
}

@test "clean-images: --prefix and --all mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --prefix=ecr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "clean-images: --prefix and --all-same-reg-ns mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all-same-reg-ns --prefix=ecr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "clean-images: --prefix rejects invalid value (colon)" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=has:colon
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid --prefix"* ]]
  [[ "$output" == *"must not contain ':'"* ]]
}

# =============================================================================
# --extra-prefixes (always additive, no longer standalone)
# =============================================================================

@test "clean-images: --extra-prefixes alone is rejected" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --extra-prefixes=ecr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"--extra-prefixes must combine with"* ]]
  [[ "$output" == *"--prefix=X for a single explicit scope"* ]]
}

@test "clean-images: --extra-prefixes rejects colon" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr --extra-prefixes=has:colon
  [ "$status" -eq 1 ]
  [[ "$output" == *"has:colon"* ]]
  [[ "$output" == *"must not contain ':'"* ]]
}

@test "clean-images: --extra-prefixes rejects whitespace" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr "--extra-prefixes=has space"
  [ "$status" -eq 1 ]
  [[ "$output" == *"whitespace"* ]]
}

@test "clean-images: --extra-prefixes rejects leading slash" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr --extra-prefixes=/leading
  [ "$status" -eq 1 ]
  [[ "$output" == *"must not start with '/'"* ]]
}

@test "clean-images: --extra-prefixes rejects trailing slash" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr --extra-prefixes=trailing/
  [ "$status" -eq 1 ]
  [[ "$output" == *"must not end with '/'"* ]]
}

@test "clean-images: --extra-prefixes rejects empty entry" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ecr --extra-prefixes=ghcr.io,,acr/team
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty"* ]]
}

# =============================================================================
# --dry-run
# =============================================================================

@test "clean-images: --dry-run lists images and skips rmi+prune" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.1.0-PRERELEASE"

  run bash -c "echo '' | env PATH='${FAKE_BIN_ABS}:/usr/bin:/bin' KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT='${FAKE_BUILD_ROOT_ABS}' '${TEST_BIN_ABS}/kaptain-clean-images' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would remove 2 images:"* ]]
  [[ "$output" == *"ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.0.0-PRERELEASE"* ]]
  [[ "$output" == *"ghcr.io/kube-kaptain/kaptain/kaptain-user-scripts:1.1.0-PRERELEASE"* ]]
  [[ "$output" == *"Would run: podman rmi <2 images above>"* ]]
  [[ "$output" == *"Would run: podman image prune"* ]]
  [ ! -f "${FAKE_LOG_DIR}/rmi" ]
  [ ! -f "${FAKE_LOG_DIR}/prune" ]
}

@test "clean-images: --dry-run with no matches still skips prune" {
  make_fake_engine podman
  write_images "alpine:3.20"
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"no PRERELEASE images"* ]]
  [[ "$output" == *"Would run: podman image prune"* ]]
  [ ! -f "${FAKE_LOG_DIR}/rmi" ]
  [ ! -f "${FAKE_LOG_DIR}/prune" ]
}

# =============================================================================
# Filter correctness
# =============================================================================

@test "clean-images: PRERELEASE matched as literal substring (not regex)" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE-suffix" \
    "ghcr.io/kube-kaptain/kaptain/foo:PRE-RELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:prerelease"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 2 images and 0 manifests"* ]]
  grep -q ":PRERELEASE$" "${FAKE_LOG_DIR}/rmi"
  grep -q ":1.0.0-PRERELEASE-suffix$" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "PRE-RELEASE" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "prerelease" "${FAKE_LOG_DIR}/rmi"
}

@test "clean-images: <none> tags are skipped" {
  make_fake_engine podman
  write_images \
    "<none>:<none>" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 1 image and 0 manifests"* ]]
  ! grep -q "none" "${FAKE_LOG_DIR}/rmi"
}

# =============================================================================
# Tag-class flags
# =============================================================================

@test "clean-images: --include-releases adds release tags to default set" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0" \
    "other/x:2.0.0-PRERELEASE" \
    "other/x:2.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ghcr.io --include-releases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: releases + prereleases"* ]]
  [[ "$output" == *"Removed 2 images and 0 manifests"* ]]
  grep -q "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "ghcr.io/kube-kaptain/kaptain/foo:1.0.0$" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "other/x" "${FAKE_LOG_DIR}/rmi"
}

@test "clean-images: --all and --include-releases mutually exclusive" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --include-releases
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "clean-images: --include-releases --exclude-prereleases cleans only releases" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0" \
    "ghcr.io/kube-kaptain/kaptain/bar:2.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ghcr.io --include-releases --exclude-prereleases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: releases only"* ]]
  [[ "$output" == *"Removed 2 images and 0 manifests"* ]]
  ! grep -q "PRERELEASE" "${FAKE_LOG_DIR}/rmi"
  grep -q "foo:1.0.0$" "${FAKE_LOG_DIR}/rmi"
  grep -q "bar:2.0.0$" "${FAKE_LOG_DIR}/rmi"
}

@test "clean-images: --exclude-prereleases alone yields empty match, still prunes" {
  make_fake_engine podman
  write_images "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --exclude-prereleases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: none (prune only)"* ]]
  [[ "$output" == *"no (none — prune only) images"* ]]
  [ ! -f "${FAKE_LOG_DIR}/rmi" ]
  [ -f "${FAKE_LOG_DIR}/prune" ]
}

@test "clean-images: --include-releases + --exclude-releases contradictory" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --prefix=ghcr.io --include-releases --exclude-releases
  [ "$status" -eq 1 ]
  [[ "$output" == *"contradictory"* ]]
}

@test "clean-images: --include-prereleases + --exclude-prereleases contradictory" {
  make_fake_engine podman
  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --include-prereleases --exclude-prereleases
  [ "$status" -eq 1 ]
  [[ "$output" == *"contradictory"* ]]
}

@test "clean-images: --include-prereleases alone behaves like default" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --include-prereleases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: PRERELEASE only"* ]]
  [[ "$output" == *"Removed 1 image and 0 manifests"* ]]
}

@test "clean-images: --exclude-releases alone behaves like default" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --exclude-releases
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag classes: PRERELEASE only"* ]]
  [[ "$output" == *"Removed 1 image and 0 manifests"* ]]
}

# =============================================================================
# Prune count summary
# =============================================================================

make_fake_engine_with_prune_hashes() {
  local name="$1"
  cat > "${FAKE_BIN}/${name}" <<EOF
#!/usr/bin/env bash
set -u
log_dir="${FAKE_LOG_DIR_ABS}"
images_file="${IMAGES_FIXTURE_ABS}"
manifests_file="${MANIFESTS_FIXTURE_ABS}"
echo "\$(basename "\$0") \$*" >> "\${log_dir}/calls"
case "\${1:-}" in
  images)
    if [[ -f "\${images_file}" ]]; then
      cat "\${images_file}"
    fi
    ;;
  rmi)
    shift
    printf '%s\n' "\$@" >> "\${log_dir}/rmi"
    ;;
  manifest)
    shift
    case "\${1:-}" in
      exists)
        ref="\${2:-}"
        if [[ -f "\${manifests_file}" ]] && grep -Fxq "\${ref}" "\${manifests_file}"; then
          exit 0
        fi
        exit 1
        ;;
      rm)
        shift
        printf '%s\n' "\$@" > "\${log_dir}/manifest_rm"
        ;;
    esac
    ;;
  image)
    shift
    if [[ "\${1:-}" == "prune" ]]; then
      echo "called" > "\${log_dir}/prune"
      cat <<'PRUNE_OUTPUT'
WARNING! This will remove all dangling images.
Are you sure you want to continue? [y/N] y
Deleted Images:
deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe
0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
Total reclaimed space: 1.234GB
PRUNE_OUTPUT
    fi
    ;;
esac
EOF
  chmod +x "${FAKE_BIN}/${name}"
}

@test "clean-images: prune summary counts dangling image SHA lines" {
  make_fake_engine_with_prune_hashes podman
  write_images "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pruned 3 dangling images."* ]]
}

make_fake_engine_with_docker_prune() {
  local name="$1"
  cat > "${FAKE_BIN}/${name}" <<EOF
#!/usr/bin/env bash
set -u
log_dir="${FAKE_LOG_DIR_ABS}"
images_file="${IMAGES_FIXTURE_ABS}"
manifests_file="${MANIFESTS_FIXTURE_ABS}"
echo "\$(basename "\$0") \$*" >> "\${log_dir}/calls"
case "\${1:-}" in
  images)
    if [[ -f "\${images_file}" ]]; then
      cat "\${images_file}"
    fi
    ;;
  rmi)
    shift
    printf '%s\n' "\$@" >> "\${log_dir}/rmi"
    ;;
  image)
    shift
    case "\${1:-}" in
      inspect)
        ref="\${4:-}"
        if [[ -f "\${manifests_file}" ]] && grep -Fxq "\${ref}" "\${manifests_file}"; then
          echo "application/vnd.docker.distribution.manifest.list.v2+json"
        else
          echo ""
        fi
        ;;
      prune)
        echo "called" > "\${log_dir}/prune"
        cat <<'PRUNE_OUTPUT'
WARNING! This will remove all dangling images.
Are you sure you want to continue? [y/N] y
Deleted Images:
Deleted: sha256:deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
deleted: sha256:cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe
untagged: foo:bar
Total reclaimed space: 1.234GB
PRUNE_OUTPUT
        ;;
    esac
    ;;
esac
EOF
  chmod +x "${FAKE_BIN}/${name}"
}

@test "clean-images: prune summary counts docker 'deleted: sha256:' lines" {
  if [[ -x /usr/bin/podman ]]; then
    skip "real /usr/bin/podman would shadow docker selection"
  fi
  make_fake_engine_with_docker_prune docker
  write_images "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Engine: docker"* ]]
  [[ "$output" == *"Pruned 2 dangling images."* ]]
}

@test "clean-images: prune summary omitted when no dangling SHA lines" {
  make_fake_engine podman
  write_images "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" != *"Pruned"* ]]
}

# =============================================================================
# Manifest-list partition (podman `manifest exists` / `manifest rm`)
# =============================================================================

@test "clean-images: manifest-list refs go through manifest rm, plain go through rmi" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE-linux-arm64" \
    "ghcr.io/kube-kaptain/kaptain/bar:2.0.0-PRERELEASE"
  # The parent multi-arch tag is the manifest list; the arch-suffixed child
  # and the bar tag are plain images.
  write_manifests "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 2 images and 1 manifest"* ]]

  [ -f "${FAKE_LOG_DIR}/rmi" ]
  grep -q "foo:1.0.0-PRERELEASE-linux-arm64$" "${FAKE_LOG_DIR}/rmi"
  grep -q "bar:2.0.0-PRERELEASE$" "${FAKE_LOG_DIR}/rmi"
  ! grep -q "foo:1.0.0-PRERELEASE$" "${FAKE_LOG_DIR}/rmi"

  [ -f "${FAKE_LOG_DIR}/manifest_rm" ]
  grep -q "foo:1.0.0-PRERELEASE$" "${FAKE_LOG_DIR}/manifest_rm"

  # Order: rmi before manifest rm so child layers are gone first.
  local rmi_line manifest_line
  rmi_line=$(grep -n '^podman rmi' "${FAKE_LOG_DIR}/calls" | head -1 | cut -d: -f1)
  manifest_line=$(grep -n '^podman manifest rm' "${FAKE_LOG_DIR}/calls" | head -1 | cut -d: -f1)
  [ "${rmi_line}" -lt "${manifest_line}" ]
}

@test "clean-images: --dry-run shows split image and manifest sections" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE-linux-arm64"
  write_manifests "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would remove 1 image:"* ]]
  [[ "$output" == *"Would run: podman rmi <1 image above>"* ]]
  [[ "$output" == *"Would remove 1 manifest:"* ]]
  [[ "$output" == *"Would run: podman manifest rm <1 manifest above>"* ]]
  [ ! -f "${FAKE_LOG_DIR}/rmi" ]
  [ ! -f "${FAKE_LOG_DIR}/manifest_rm" ]
}

@test "clean-images: all-manifest set skips rmi entirely" {
  make_fake_engine podman
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/bar:2.0.0-PRERELEASE"
  write_manifests \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/bar:2.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 0 images and 2 manifests"* ]]
  [ ! -f "${FAKE_LOG_DIR}/rmi" ]
  [ -f "${FAKE_LOG_DIR}/manifest_rm" ]
}

# =============================================================================
# Docker manifest-list classification (image inspect MediaType)
# =============================================================================

@test "clean-images: docker classifies manifest lists via image inspect, removes via rmi" {
  if [[ -x /usr/bin/podman ]]; then
    skip "real /usr/bin/podman would shadow docker selection"
  fi
  make_fake_engine docker
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE-linux-arm64" \
    "ghcr.io/kube-kaptain/kaptain/bar:2.0.0-PRERELEASE"
  write_manifests "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Engine: docker"* ]]
  [[ "$output" == *"Removed 2 images and 1 manifest"* ]]

  # Both buckets go through docker rmi (docker has no local `manifest rm`).
  [ -f "${FAKE_LOG_DIR}/rmi" ]
  [ ! -f "${FAKE_LOG_DIR}/manifest_rm" ]
  grep -q "foo:1.0.0-PRERELEASE-linux-arm64$" "${FAKE_LOG_DIR}/rmi"
  grep -q "bar:2.0.0-PRERELEASE$" "${FAKE_LOG_DIR}/rmi"
  grep -q "foo:1.0.0-PRERELEASE$" "${FAKE_LOG_DIR}/rmi"

  # Two rmi invocations: plain bucket first, then manifest bucket.
  local rmi_calls
  rmi_calls=$(grep -c '^docker rmi' "${FAKE_LOG_DIR}/calls")
  [ "${rmi_calls}" -eq 2 ]
}

@test "clean-images: docker dry-run shows split with rmi for both buckets" {
  if [[ -x /usr/bin/podman ]]; then
    skip "real /usr/bin/podman would shadow docker selection"
  fi
  make_fake_engine docker
  write_images \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE" \
    "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE-linux-arm64"
  write_manifests "ghcr.io/kube-kaptain/kaptain/foo:1.0.0-PRERELEASE"

  run env PATH="${FAKE_BIN_ABS}:/usr/bin:/bin" "${TEST_BIN_ABS}/kaptain-clean-images" --all --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would remove 1 image:"* ]]
  [[ "$output" == *"Would run: docker rmi <1 image above>"* ]]
  [[ "$output" == *"Would remove 1 manifest:"* ]]
  [[ "$output" == *"Would run: docker rmi <1 manifest above>"* ]]
}
