#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for kaptain-update / kaptain-update-versions

BUILD_SCRIPTS_DIR="src/scripts/build"

setup() {
  TEST_BUILD="${BATS_TEST_TMPDIR}/build"
  rm -rf "${TEST_BUILD}"
  mkdir -p "${TEST_BUILD}"
  cp "${BUILD_SCRIPTS_DIR}"/kaptain-* "${TEST_BUILD}/"
}

# Build a minimal fake build-scripts repo. Provides version-range.bash and a
# stub artifact-resolve whose behaviour can be controlled by the test via
# files dropped into ${FAKE_BUILD_ROOT}/responses/.
make_fake_build_root() {
  FAKE_BUILD_ROOT="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${FAKE_BUILD_ROOT}/src/scripts/lib"
  mkdir -p "${FAKE_BUILD_ROOT}/src/scripts/util"
  mkdir -p "${FAKE_BUILD_ROOT}/src/schemas"
  mkdir -p "${FAKE_BUILD_ROOT}/responses"

  # Real version-range.bash copy — tested upstream, no need to fake.
  cat > "${FAKE_BUILD_ROOT}/src/scripts/lib/version-range.bash" <<'LIB'
#!/usr/bin/env bash
version_compare() {
  local v1="${1}" v2="${2}"
  [[ "${v1}" == "${v2}" ]] && return 0
  local v1n="${v1%%-*}" v2n="${v2%%-*}"
  local -a a b
  IFS='.' read -ra a <<< "${v1n}"
  IFS='.' read -ra b <<< "${v2n}"
  local max=${#a[@]}
  (( ${#b[@]} > max )) && max=${#b[@]}
  local i
  for ((i=0; i<max; i++)); do
    local p=${a[i]:-0} q=${b[i]:-0}
    ((p > q)) && return 1
    ((p < q)) && return 2
  done
  return 0
}
version_gt() { local rc=0; version_compare "$1" "$2" || rc=$?; [[ ${rc} -eq 1 ]]; }
version_ge() { local rc=0; version_compare "$1" "$2" || rc=$?; [[ ${rc} -eq 1 || ${rc} -eq 0 ]]; }
version_lt() { local rc=0; version_compare "$1" "$2" || rc=$?; [[ ${rc} -eq 2 ]]; }
version_le() { local rc=0; version_compare "$1" "$2" || rc=$?; [[ ${rc} -eq 2 || ${rc} -eq 0 ]]; }
version_filter_release() {
  local v
  while IFS= read -r v; do
    [[ -z "${v}" ]] && continue
    [[ "${v}" != *-* ]] && echo "${v}"
  done <<< "${1}"
}
version_unwrap_exact() {
  local v="${1}"
  if [[ "${v}" == "["*"]" && "${v}" != *","* ]]; then
    v="${v#[}"; v="${v%]}"
  fi
  printf '%s' "${v}"
}
version_is_exact() {
  local v; v=$(version_unwrap_exact "${1}")
  [[ "${v}" != *"["* && "${v}" != *"("* && "${v}" != *"]"* && "${v}" != *")"* && "${v}" != *","* ]]
}
LIB

  # Stub artifact-resolve: looks up ${responses}/<sanitised-ref> for the
  # resolved URI to write. Records every call (ref|variant) to calls.log so
  # tests can assert what variant flowed through. If a fixture is missing,
  # fails (simulating registry failure).
  cat > "${FAKE_BUILD_ROOT}/src/scripts/util/artifact-resolve" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
ref="${1}"
out="${2}"
variant="${3:-}"
resp_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../../responses && pwd)"
echo "${ref}|${variant}" >> "${resp_dir}/calls.log"
safe="${ref//[^a-zA-Z0-9._-]/_}"
if [[ -f "${resp_dir}/${safe}" ]]; then
  cat "${resp_dir}/${safe}" > "${out}"
  exit 0
fi
echo "ERROR: no fixture for ${ref} (looked at ${resp_dir}/${safe})" >&2
exit 1
STUB
  chmod +x "${FAKE_BUILD_ROOT}/src/scripts/util/artifact-resolve"

  # Stub detect-build-context.bash. The real one in buildon does git/CI
  # auto-detection to set BUILD_PLATFORM, DOCKER_TARGET_REGISTRY etc. for
  # artifact-resolve; the stubbed artifact-resolve here doesn't need any of it,
  # so the file just needs to source cleanly.
  cat > "${FAKE_BUILD_ROOT}/src/scripts/lib/detect-build-context.bash" <<'LIB'
#!/usr/bin/env bash
# Test stub: no auto-detection needed when artifact-resolve is faked.
:
LIB

  # Schema version file — read directly by --api-version.
  echo "1.19" > "${FAKE_BUILD_ROOT}/src/schemas/version"
}

# Drop a stubbed registry response for ref → resolved URI.
fixture() {
  local ref="$1" resolved="$2"
  local safe="${ref//[^a-zA-Z0-9._-]/_}"
  echo "${resolved}" > "${FAKE_BUILD_ROOT}/responses/${safe}"
}

# =============================================================================
# Router
# =============================================================================

@test "kaptain-update: no args shows usage and exits 1" {
  run "${TEST_BUILD}/kaptain-update"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-update: --help lists targets" {
  run "${TEST_BUILD}/kaptain-update" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"versions"* ]]
}

@test "kaptain-update: unknown target fails" {
  run "${TEST_BUILD}/kaptain-update" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown update target"* ]]
}

@test "kaptain-update: routes to versions leaf" {
  run "${TEST_BUILD}/kaptain-update" versions --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--update-lower-bounds"* ]]
}

# =============================================================================
# Leaf — basic args / help / gates
# =============================================================================

@test "kaptain-update-versions: --help shows usage" {
  run "${TEST_BUILD}/kaptain-update-versions" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--update-lower-bounds"* ]]
  [[ "$output" == *"--update-fixed"* ]]
  [[ "$output" == *"--update-ranges"* ]]
  [[ "$output" == *"--api-version"* ]]
  [[ "$output" == *"--update-all"* ]]
  [[ "$output" == *"--all"* ]]
  [[ "$output" == *"--file"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "kaptain-update-versions: unknown flag fails" {
  run "${TEST_BUILD}/kaptain-update-versions" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "kaptain-update-versions: --all and --file are mutually exclusive" {
  run "${TEST_BUILD}/kaptain-update-versions" --all --file foo.yaml
  [ "$status" -eq 1 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "kaptain-update-versions: fails when BUILD_ROOT env not set" {
  cd "${BATS_TEST_TMPDIR}"
  unset KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT
  run "${TEST_BUILD}/kaptain-update-versions"
  [ "$status" -eq 1 ]
  [[ "$output" == *"KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT"* ]]
}

@test "kaptain-update-versions: fails when BUILD_ROOT dir missing" {
  cd "${BATS_TEST_TMPDIR}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="/tmp/nonexistent-kuv-$$" \
    run "${TEST_BUILD}/kaptain-update-versions"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "kaptain-update-versions: fails when --file does not exist" {
  make_fake_build_root
  cd "${BATS_TEST_TMPDIR}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --file no-such-file.yaml
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "kaptain-update-versions: fails when no KaptainPM.yaml auto-discovered" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/empty-project"
  mkdir -p "${project}"
  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No KaptainPM.yaml"* ]]
}

# =============================================================================
# --update-lower-bounds (default) round-trip
# =============================================================================

@test "kaptain-update-versions: tightens lower bound of a range (dry-run)" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-lb"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.2.0,2.0.0)
YAML
  fixture "layer-foo:[1.2.0,2.0.0)" "ghcr.io/x/layer-foo:1.7.3"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"CHANGE"*"layer-foo, [1.2.0,2.0.0) → [1.7.3,2.0.0)"* ]]
  [[ "$output" == *"would be applied"* ]]
  # Original file untouched
  grep -q 'layer-foo:\[1.2.0,2.0.0)' "${project}/KaptainPM.yaml"
}

@test "kaptain-update-versions: tightens lower bound and writes the file" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-lb-write"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.2.0,2.0.0)
YAML
  fixture "layer-foo:[1.2.0,2.0.0)" "ghcr.io/x/layer-foo:1.7.3"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 change(s) applied"* ]]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:[1.7.3,2.0.0)'* ]]
}

@test "kaptain-update-versions: no change when lower already at highest" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-noop"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.7.3,2.0.0)
YAML
  fixture "layer-foo:[1.7.3,2.0.0)" "ghcr.io/x/layer-foo:1.7.3"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No changes."* ]]
}

@test "kaptain-update-versions: skips PRERELEASE entries" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-pre"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:1.2.3-PRERELEASE
YAML

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-fixed
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"PRERELEASE"* ]]
}

# =============================================================================
# --update-fixed
# =============================================================================

@test "kaptain-update-versions: --update-fixed bumps unbracketed exact ref" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-fixed"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:1.3
YAML
  # Wildcard query yields absolute highest.
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:5.6.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-fixed --no-update-lower-bounds
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 change(s) applied"* ]]
  run cat "${project}/KaptainPM.yaml"
  # Source had 2 segments — output truncates to 2 segments.
  [[ "$output" == *'layer-foo:5.6'* ]]
}

@test "kaptain-update-versions: --update-fixed preserves [N] bracket style" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-fixed-br"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.2]
YAML
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:1.7.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-fixed --no-update-lower-bounds
  [ "$status" -eq 0 ]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:[1.7]'* ]]
}

# Regression: when artifact-resolve fails for an entry, the row must be ERROR,
# not KEEP carrying the previous entry's resolved version (sticky globals bug).
@test "kaptain-update-versions: --update-fixed reports ERROR (not stale KEEP) when resolve fails" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-sticky-fixed"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-good:1.3
    - layer-bad:1.7
YAML
  fixture "layer-good:[0,)" "ghcr.io/x/layer-good:1.3"
  # No fixture for layer-bad:[0,) — artifact-resolve fails.

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-fixed --no-update-lower-bounds
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEEP"*"layer-good:1.3"*"already at highest (1.3)"* ]]
  [[ "$output" == *"ERROR"*"layer-bad:1.7"* ]]
  # layer-bad must NOT have leaked layer-good's resolved version into a KEEP.
  ! grep -E 'layer-bad.*already at highest' <<< "$output"
}

@test "kaptain-update-versions: standard mode reports ERROR (not stale KEEP) when resolve fails" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-sticky-lb"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-good:[1.0,2.0)
    - layer-bad:[1.0,2.0)
YAML
  fixture "layer-good:[1.0,2.0)" "ghcr.io/x/layer-good:1.5"
  # No fixture for layer-bad — artifact-resolve fails.

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ERROR"*"layer-bad:[1.0,2.0)"* ]]
  ! grep -E 'layer-bad.*lower already at highest' <<< "$output"
}

# =============================================================================
# --update-ranges — algorithm-bearing cases
# =============================================================================

@test "kaptain-update-versions: --update-ranges rolls upper when highest >= upper" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-roll"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.3,2.0)
YAML
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:2.7.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-ranges --no-update-lower-bounds
  [ "$status" -eq 0 ]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:[2.7,3.0)'* ]]
}

@test "kaptain-update-versions: --update-ranges tightens when highest still in range" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-rollin"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.5,3.0)
YAML
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:2.7.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-ranges --no-update-lower-bounds
  [ "$status" -eq 0 ]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:[2.7,3.0)'* ]]
}

@test "kaptain-update-versions: --update-ranges with depth-1 input keeps depth 1" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-depth1"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1,2)
YAML
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:2.3.4"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-ranges --no-update-lower-bounds
  [ "$status" -eq 0 ]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:[2,3)'* ]]
}

@test "kaptain-update-versions: --update-ranges rolls patch-level upper bound" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-patch"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.2.3,1.3.0)
YAML
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:1.3.6"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-ranges --no-update-lower-bounds
  [ "$status" -eq 0 ]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:[1.3.6,1.4.0)'* ]]
}

@test "kaptain-update-versions: --update-ranges large jump across multiple majors" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-jump"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.5,3.0)
YAML
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:5.6.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-ranges --no-update-lower-bounds
  [ "$status" -eq 0 ]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:[5.6,6.0)'* ]]
}

@test "kaptain-update-versions: --update-ranges open lower bound" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-openlow"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:(,2.0)
YAML
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:3.1.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-ranges --no-update-lower-bounds
  [ "$status" -eq 0 ]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:(,4.0)'* ]]
}

@test "kaptain-update-versions: --update-ranges open upper bound" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-openup"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:(1.0,)
YAML
  fixture "layer-foo:[0,)" "ghcr.io/x/layer-foo:1.7.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-ranges --no-update-lower-bounds
  [ "$status" -eq 0 ]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'layer-foo:(1.7,)'* ]]
}

# =============================================================================
# --api-version
# =============================================================================

@test "kaptain-update-versions: --api-version bumps to highest schema" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-api"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
YAML

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --api-version --no-update-lower-bounds
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 change(s) applied"* ]]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'apiVersion: kaptain.org/1.19'* ]]
}

@test "kaptain-update-versions: --api-version is no-op when already at highest" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-api-noop"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.19
kind: docker-build-dockerfile
YAML

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --api-version --no-update-lower-bounds
  [ "$status" -eq 0 ]
  [[ "$output" == *"No changes."* ]]
}

# =============================================================================
# Multi-section + multi-file
# =============================================================================

@test "kaptain-update-versions: discovers and updates src/layer/ and src/layerset/ too" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-multi"
  mkdir -p "${project}/src/layer" "${project}/src/layerset"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-a:[1.0.0,2.0.0)
YAML
  cat > "${project}/src/layer/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: kaptain-layer
spec:
  templates:
    - tmpl-b:[1.0.0,2.0.0)
YAML
  cat > "${project}/src/layerset/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: kaptain-layerset
spec:
  contents:
    - cont-c:[1.0.0,2.0.0)
YAML
  fixture "layer-a:[1.0.0,2.0.0)" "ghcr.io/x/layer-a:1.5.0"
  fixture "tmpl-b:[1.0.0,2.0.0)" "ghcr.io/x/tmpl-b:1.6.0"
  fixture "cont-c:[1.0.0,2.0.0)" "ghcr.io/x/cont-c:1.7.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 change(s) applied"* ]]
  grep -q 'layer-a:\[1.5.0,2.0.0)' "${project}/KaptainPM.yaml"
  grep -q 'tmpl-b:\[1.6.0,2.0.0)' "${project}/src/layer/KaptainPM.yaml"
  grep -q 'cont-c:\[1.7.0,2.0.0)' "${project}/src/layerset/KaptainPM.yaml"
}

@test "kaptain-update-versions: passes manifests variant for templates and contents, empty for layers" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-variant"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: kaptain-layerset
spec:
  layers:
    - layer-a:[1.0.0,2.0.0)
  templates:
    - tmpl-b:[1.0.0,2.0.0)
  contents:
    - cont-c:[1.0.0,2.0.0)
YAML
  fixture "layer-a:[1.0.0,2.0.0)" "ghcr.io/x/layer-a:1.5.0"
  fixture "tmpl-b:[1.0.0,2.0.0)" "ghcr.io/x/tmpl-b:1.6.0-manifests"
  fixture "cont-c:[1.0.0,2.0.0)" "ghcr.io/x/cont-c:1.7.0-manifests"
  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions"
  [ "$status" -eq 0 ]
  local calls="${FAKE_BUILD_ROOT}/responses/calls.log"
  [ -f "${calls}" ]
  grep -qx 'layer-a:\[1.0.0,2.0.0)|' "${calls}"
  grep -qx 'tmpl-b:\[1.0.0,2.0.0)|manifests' "${calls}"
  grep -qx 'cont-c:\[1.0.0,2.0.0)|manifests' "${calls}"
  # The provider re-appends the variant; the user-script must strip it so the
  # numeric version it writes into the lower bound is canonical.
  grep -q 'tmpl-b:\[1.6.0,2.0.0)' "${project}/KaptainPM.yaml"
  grep -q 'cont-c:\[1.7.0,2.0.0)' "${project}/KaptainPM.yaml"
  grep -q 'layer-a:\[1.5.0,2.0.0)' "${project}/KaptainPM.yaml"
}

# =============================================================================
# --file override
# =============================================================================

@test "kaptain-update-versions: --file operates on the named file only" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-file"
  mkdir -p "${project}/src/layer"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-a:[1.0.0,2.0.0)
YAML
  cat > "${project}/src/layer/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: kaptain-layer
spec:
  layers:
    - layer-b:[1.0.0,2.0.0)
YAML
  fixture "layer-a:[1.0.0,2.0.0)" "ghcr.io/x/layer-a:1.5.0"
  fixture "layer-b:[1.0.0,2.0.0)" "ghcr.io/x/layer-b:1.5.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --file src/layer/KaptainPM.yaml
  [ "$status" -eq 0 ]
  # Root file unchanged
  grep -q 'layer-a:\[1.0.0,2.0.0)' "${project}/KaptainPM.yaml"
  # Targeted file updated
  grep -q 'layer-b:\[1.5.0,2.0.0)' "${project}/src/layer/KaptainPM.yaml"
}

# =============================================================================
# --update-all / --no-update-lower-bounds arg paths
# =============================================================================

@test "kaptain-update-versions: --update-all hits ranges, fixed and apiVersion together" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-updateall"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-r:[1.0.0,2.0.0)
    - layer-f:1.3
YAML
  # Range: H inside upper → ranges path tightens lower.
  fixture "layer-r:[0,)" "ghcr.io/x/layer-r:1.7.0"
  # Fixed: absolute highest.
  fixture "layer-f:[0,)" "ghcr.io/x/layer-f:5.6.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --update-all
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 change(s) applied"* ]]
  run cat "${project}/KaptainPM.yaml"
  [[ "$output" == *'apiVersion: kaptain.org/1.19'* ]]
  [[ "$output" == *'layer-r:[1.7.0,2.0.0)'* ]]
  [[ "$output" == *'layer-f:5.6'* ]]
}

@test "kaptain-update-versions: --no-update-lower-bounds alone leaves ranges untouched" {
  make_fake_build_root
  local project="${BATS_TEST_TMPDIR}/proj-nolb"
  mkdir -p "${project}"
  cat > "${project}/KaptainPM.yaml" <<'YAML'
apiVersion: kaptain.org/1.18
kind: docker-build-dockerfile
spec:
  layers:
    - layer-foo:[1.0.0,2.0.0)
YAML
  # Fixture present; if --no-update-lower-bounds did not actually opt out, a
  # tightened lower would be written.
  fixture "layer-foo:[1.0.0,2.0.0)" "ghcr.io/x/layer-foo:1.7.0"

  cd "${project}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${FAKE_BUILD_ROOT}" \
    run "${TEST_BUILD}/kaptain-update-versions" --no-update-lower-bounds
  [ "$status" -eq 0 ]
  [[ "$output" == *"No changes."* ]]
  grep -q 'layer-foo:\[1.0.0,2.0.0)' "${project}/KaptainPM.yaml"
}
