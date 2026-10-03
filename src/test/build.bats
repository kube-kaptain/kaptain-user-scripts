#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# BATS tests for build scripts

BUILD_SCRIPTS_DIR="src/scripts/build"

setup() {
  TEST_BUILD="${BATS_TEST_TMPDIR}/build"
  rm -rf "${TEST_BUILD}"
  mkdir -p "${TEST_BUILD}"
  cp "${BUILD_SCRIPTS_DIR}"/kaptain-* "${TEST_BUILD}/"

  # Stub container engine. kaptain-run takes the command from the build
  # output rather than detecting it, so pointing that at a stub covers every
  # path with no real engine present.
  STUB_ENGINE="${BATS_TEST_TMPDIR}/stub-engine"
  cat > "${STUB_ENGINE}" <<'STUB'
#!/usr/bin/env bash
# STUB_IMAGES: newline separated refs that exist locally
# STUB_PORTS:  what image inspect --format reports for ExposedPorts
# STUB_ENV:    what image inspect --format reports for Config.Env
# STUB_LOG:    file recording pulls
# STUB_STDIN_FILE: file receiving stdin of an interactive (-i) run
case "$1" in
  pull)
    echo "STUB_PULL: ${*: -1}" >> "${STUB_LOG:-/dev/null}"
    exit "${STUB_PULL_STATUS:-0}"
    ;;
  version)
    echo "${STUB_PODMAN_VERSION:-5.0.0}"
    exit 0
    ;;
  info)
    echo "${STUB_DOCKER_SECURITY:-[name=seccomp,profile=builtin]}"
    exit 0
    ;;
  image)
    case "$2" in
      inspect)
        if [[ "$3" == "--format" ]]; then
          if [[ "$4" == *Config.Env* ]]; then
            printf '%s\n' "${STUB_ENV:-}"
            exit 0
          fi
          printf '%s\n' "${STUB_PORTS:-null}"
          exit 0
        fi
        if printf '%s\n' "${STUB_IMAGES:-}" | grep -qxF "$3"; then
          exit 0
        fi
        exit 1
        ;;
      list)
        printf '%s\n' "${STUB_IMAGES:-}"
        exit 0
        ;;
    esac
    ;;
  run)
    shift
    if [[ "$*" == *"test -x /kd/bin/bootstrap"* ]]; then
      exit "${STUB_BOOTSTRAP_CHECK_STATUS:-0}"
    fi
    if [[ " $* " == *" -i "* ]]; then
      cat > "${STUB_STDIN_FILE:-/dev/null}"
    fi
    echo "STUB_RUN: $*"
    exit "${STUB_RUN_STATUS:-0}"
    ;;
esac
exit 1
STUB
  chmod +x "${STUB_ENGINE}"

  # The same stub under the names bootstrap tells engines apart by
  STUB_ENGINES="${BATS_TEST_TMPDIR}/engines"
  mkdir -p "${STUB_ENGINES}"
  for engine_name in docker podman nerdctl; do
    ln -s "${STUB_ENGINE}" "${STUB_ENGINES}/${engine_name}"
  done

  # uname that reports STUB_UNAME_S for -s when set, so the Linux and macOS
  # bootstrap paths can both be exercised on any host
  STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
  mkdir -p "${STUB_BIN}"
  cat > "${STUB_BIN}/uname" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "-s" && -n "${STUB_UNAME_S:-}" ]]; then
  echo "${STUB_UNAME_S}"
  exit 0
fi
exec /usr/bin/uname "$@"
STUB
  chmod +x "${STUB_BIN}/uname"

  # Host architecture, mapped the same way kaptain-run maps it
  case "$(uname -m)" in
    x86_64|amd64)  HOST_ARCH="amd64" ;;
    arm64|aarch64) HOST_ARCH="arm64" ;;
    *)             HOST_ARCH="" ;;
  esac
}

# Write the build output files kaptain-run reads. An empty image URI
# writes no docker-build-dockerfile file, as a non-image build kind leaves it.
make_build_output() {
  local project_dir="$1"
  local image_uri="$2"
  local out="${project_dir}/kaptain-out/reference-script-output"

  mkdir -p "${out}"
  echo "IMAGE_BUILD_COMMAND=${3:-${STUB_ENGINE}}" > "${out}/validate-tooling"

  if [[ -n "${image_uri}" ]]; then
    echo "DOCKER_TARGET_IMAGE_FULL_URI=${image_uri}" > "${out}/docker-build-dockerfile"
  fi
}

# =============================================================================
# kaptain-clean-project tests
# =============================================================================

@test "kaptain-clean-project: --help shows usage" {
  run "${TEST_BUILD}/kaptain-clean-project" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-clean-project: -h shows usage" {
  run "${TEST_BUILD}/kaptain-clean-project" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-clean-project: unknown option fails" {
  run "${TEST_BUILD}/kaptain-clean-project" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "kaptain-clean-project: removes default output dir and kaptainpm" {
  local project_dir="${BATS_TEST_TMPDIR}/project"
  mkdir -p "${project_dir}/kaptain-out/some-output"
  mkdir -p "${project_dir}/kaptainpm/final"
  touch "${project_dir}/kaptain-out/some-output/file.txt"
  touch "${project_dir}/kaptainpm/final/KaptainPM.yaml"

  cd "${project_dir}"
  run "${TEST_BUILD}/kaptain-clean-project"
  [ "$status" -eq 0 ]
  [ ! -d "${project_dir}/kaptain-out" ]
  [ ! -d "${project_dir}/kaptainpm" ]
}

@test "kaptain-clean-project: removes output dir with .git inside" {
  local project_dir="${BATS_TEST_TMPDIR}/project"
  mkdir -p "${project_dir}/kaptain-out/.git/objects"
  touch "${project_dir}/kaptain-out/.git/HEAD"

  cd "${project_dir}"
  run "${TEST_BUILD}/kaptain-clean-project"
  [ "$status" -eq 0 ]
  [ ! -d "${project_dir}/kaptain-out" ]
}

@test "kaptain-clean-project: --dir overrides output path" {
  local project_dir="${BATS_TEST_TMPDIR}/project"
  mkdir -p "${project_dir}/custom-out/stuff"
  mkdir -p "${project_dir}/kaptainpm/final"

  cd "${project_dir}"
  run "${TEST_BUILD}/kaptain-clean-project" --dir custom-out
  [ "$status" -eq 0 ]
  [ ! -d "${project_dir}/custom-out" ]
  [ ! -d "${project_dir}/kaptainpm" ]
}

@test "kaptain-clean-project: env var overrides output path" {
  local project_dir="${BATS_TEST_TMPDIR}/project"
  mkdir -p "${project_dir}/env-out/stuff"
  mkdir -p "${project_dir}/kaptainpm/final"

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_OUTPUT_SUB_PATH="env-out" run "${TEST_BUILD}/kaptain-clean-project"
  [ "$status" -eq 0 ]
  [ ! -d "${project_dir}/env-out" ]
  [ ! -d "${project_dir}/kaptainpm" ]
}

@test "kaptain-clean-project: --dir rejects absolute paths" {
  run "${TEST_BUILD}/kaptain-clean-project" --dir /tmp/nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a relative path"* ]]
}

@test "kaptain-clean-project: succeeds when dirs don't exist" {
  local project_dir="${BATS_TEST_TMPDIR}/empty-project"
  mkdir -p "${project_dir}"

  cd "${project_dir}"
  run "${TEST_BUILD}/kaptain-clean-project"
  [ "$status" -eq 0 ]
}

@test "kaptain-clean-project: --dir with nonexistent dir succeeds" {
  local project_dir="${BATS_TEST_TMPDIR}/empty-project2"
  mkdir -p "${project_dir}"

  cd "${project_dir}"
  run "${TEST_BUILD}/kaptain-clean-project" --dir no-such-dir
  [ "$status" -eq 0 ]
}

# =============================================================================
# kaptain-build tests
# =============================================================================

@test "kaptain-build: --help shows usage" {
  run "${TEST_BUILD}/kaptain-build" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-build: -h shows usage" {
  run "${TEST_BUILD}/kaptain-build" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-build: unknown option fails" {
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="/tmp" \
    run "${TEST_BUILD}/kaptain-build" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "kaptain-build: fails when env var not set" {
  local project_dir="${BATS_TEST_TMPDIR}/project-no-env"
  mkdir -p "${project_dir}"
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
name: test-project
YAML

  cd "${project_dir}"
  unset KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT
  run "${TEST_BUILD}/kaptain-build"
  [ "$status" -eq 1 ]
  [[ "$output" == *"KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT"* ]]
  [[ "$output" == *"clone"* ]]
}

@test "kaptain-build: fails when no KaptainPM.yaml" {
  local project_dir="${BATS_TEST_TMPDIR}/project-no-yaml"
  mkdir -p "${project_dir}"

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="/tmp" \
    run "${TEST_BUILD}/kaptain-build"
  [ "$status" -eq 1 ]
  [[ "$output" == *"KaptainPM.yaml"* ]]
}

@test "kaptain-build: fails when repo root dir missing" {
  local project_dir="${BATS_TEST_TMPDIR}/project-bad-root"
  mkdir -p "${project_dir}"
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
name: test-project
YAML

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="/tmp/nonexistent-kaptain-build-$$" \
    run "${TEST_BUILD}/kaptain-build"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "kaptain-build: fails when repo root missing src dir" {
  local project_dir="${BATS_TEST_TMPDIR}/project-missing-src"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}"
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
name: test-project
YAML

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${fake_root}" \
    run "${TEST_BUILD}/kaptain-build"
  [ "$status" -eq 1 ]
  [[ "$output" == *"src/"* ]]
}

@test "kaptain-build: fails when repo root missing src/scripts" {
  local project_dir="${BATS_TEST_TMPDIR}/project-missing-scripts"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}/src/schemas"
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
name: test-project
YAML

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${fake_root}" \
    run "${TEST_BUILD}/kaptain-build"
  [ "$status" -eq 1 ]
  [[ "$output" == *"src/scripts"* ]]
}

@test "kaptain-build: fails when repo root missing src/schemas" {
  local project_dir="${BATS_TEST_TMPDIR}/project-missing-schemas"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}/src/scripts"
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
name: test-project
YAML

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${fake_root}" \
    run "${TEST_BUILD}/kaptain-build"
  [ "$status" -eq 1 ]
  [[ "$output" == *"src/schemas"* ]]
}

@test "kaptain-build: reads kind from KaptainPM.yaml and runs reference script" {
  local project_dir="${BATS_TEST_TMPDIR}/project-with-kind"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}/src/scripts/reference"
  mkdir -p "${fake_root}/src/schemas"

  # Create a KaptainPM.yaml with kind
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
kind: docker-image
name: test-project
YAML

  # Create a fake reference script that proves it ran
  cat > "${fake_root}/src/scripts/reference/docker-image" <<'SCRIPT'
#!/usr/bin/env bash
echo "REFERENCE_SCRIPT_RAN:docker-image"
SCRIPT
  chmod +x "${fake_root}/src/scripts/reference/docker-image"

  # Create a fake kaptain-clean-project that does nothing
  cat > "${project_dir}/kaptain-clean-project" <<'SCRIPT'
#!/usr/bin/env bash
echo "CLEAN_RAN"
SCRIPT
  chmod +x "${project_dir}/kaptain-clean-project"

  # Copy kaptain-build to project dir so SCRIPT_DIR resolves the fake clean
  cp "${TEST_BUILD}/kaptain-build" "${project_dir}/"

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${fake_root}" \
    run "${project_dir}/kaptain-build"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLEAN_RAN"* ]]
  [[ "$output" == *"REFERENCE_SCRIPT_RAN:docker-image"* ]]
}

@test "kaptain-build: fails with clear message when kind missing from KaptainPM.yaml" {
  local project_dir="${BATS_TEST_TMPDIR}/project-no-kind"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}/src/scripts/reference"
  mkdir -p "${fake_root}/src/schemas"

  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
name: test-project
YAML

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${fake_root}" \
    run "${TEST_BUILD}/kaptain-build"
  [ "$status" -eq 1 ]
  [[ "$output" == *"'kind' is required in KaptainPM.yaml"* ]]
}

@test "kaptain-build: fails when reference script not found" {
  local project_dir="${BATS_TEST_TMPDIR}/project-no-ref"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}/src/scripts/reference"
  mkdir -p "${fake_root}/src/schemas"

  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
kind: nonexistent-type
name: test-project
YAML

  # Fake clean
  cat > "${project_dir}/kaptain-clean-project" <<'SCRIPT'
#!/usr/bin/env bash
echo "CLEAN_RAN"
SCRIPT
  chmod +x "${project_dir}/kaptain-clean-project"

  cp "${TEST_BUILD}/kaptain-build" "${project_dir}/"

  cd "${project_dir}"
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${fake_root}" \
    run "${project_dir}/kaptain-build"
  [ "$status" -eq 1 ]
  [[ "$output" == *"nonexistent-type"* ]]
}

@test "kaptain-build: --run runs the image after the build" {
  local project_dir="${BATS_TEST_TMPDIR}/project-build-run"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}/src/scripts/reference"
  mkdir -p "${fake_root}/src/schemas"

  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
kind: docker-image
name: test-project
YAML

  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  # Reference script must not wipe the output the fake build already wrote
  cat > "${fake_root}/src/scripts/reference/docker-image" <<'SCRIPT'
#!/usr/bin/env bash
echo "REFERENCE_SCRIPT_RAN"
SCRIPT
  chmod +x "${fake_root}/src/scripts/reference/docker-image"

  cat > "${project_dir}/kaptain-clean-project" <<'SCRIPT'
#!/usr/bin/env bash
echo "CLEAN_RAN"
SCRIPT
  chmod +x "${project_dir}/kaptain-clean-project"

  cp "${TEST_BUILD}/kaptain-build" "${project_dir}/"
  cp "${TEST_BUILD}/kaptain-run" "${project_dir}/"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='{"80/tcp":{}}'
  KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT="${fake_root}" \
    run "${project_dir}/kaptain-build" --run
  [ "$status" -eq 0 ]
  [[ "$output" == *"REFERENCE_SCRIPT_RAN"* ]]
  [[ "$output" == *"STUB_RUN: --rm --init -p 4242:80 reg.example/ns/app:1.0.0"* ]]
}

@test "kaptain-build: --run appears in usage" {
  run "${TEST_BUILD}/kaptain-build" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--run"* ]]
}

# =============================================================================
# kaptain-run tests
# =============================================================================

@test "kaptain-run: --help shows usage" {
  run "${TEST_BUILD}/kaptain-run" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-run: -h shows usage" {
  run "${TEST_BUILD}/kaptain-run" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "kaptain-run: unknown option fails" {
  run "${TEST_BUILD}/kaptain-run" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "kaptain-run: fails when there is no build output" {
  local project_dir="${BATS_TEST_TMPDIR}/run-no-output"
  mkdir -p "${project_dir}"

  cd "${project_dir}"
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No build output found"* ]]
  [[ "$output" == *"kaptain build"* ]]
}

@test "kaptain-run: fails when IMAGE_BUILD_COMMAND is missing" {
  local project_dir="${BATS_TEST_TMPDIR}/run-no-command"
  mkdir -p "${project_dir}/kaptain-out/reference-script-output"
  echo "DOCKER_TARGET_IMAGE_FULL_URI=reg.example/ns/app:1.0.0" \
    > "${project_dir}/kaptain-out/reference-script-output/docker-build-dockerfile"

  cd "${project_dir}"
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 1 ]
  [[ "$output" == *"IMAGE_BUILD_COMMAND"* ]]
}

@test "kaptain-run: fails with the project kind when no image was built" {
  local project_dir="${BATS_TEST_TMPDIR}/run-no-image"
  mkdir -p "${project_dir}"
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
kind: kubernetes-bundle-resources
name: test-project
YAML
  make_build_output "${project_dir}" ""

  cd "${project_dir}"
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not produce a runnable image"* ]]
}

@test "kaptain-run: single tcp port maps to 4242" {
  local project_dir="${BATS_TEST_TMPDIR}/run-one-port"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='{"80/tcp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_RUN: --rm --init -p 4242:80 reg.example/ns/app:1.0.0"* ]]
}

@test "kaptain-run: multiple ports map from 4242 in numeric order" {
  local project_dir="${BATS_TEST_TMPDIR}/run-many-ports"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  # Deliberately out of order, and 8080 must not sort before 80 as text
  export STUB_PORTS='{"8080/tcp":{},"80/tcp":{},"443/tcp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_RUN: --rm --init -p 4242:80 -p 4243:443 -p 4244:8080 reg.example/ns/app:1.0.0"* ]]
}

@test "kaptain-run: udp protocol is preserved" {
  local project_dir="${BATS_TEST_TMPDIR}/run-udp"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='{"53/udp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_RUN: --rm --init -p 4242:53/udp reg.example/ns/app:1.0.0"* ]]
}

@test "kaptain-run: no exposed ports means no port flags" {
  local project_dir="${BATS_TEST_TMPDIR}/run-no-ports"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='null'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_RUN: --rm --init reg.example/ns/app:1.0.0"* ]]
}

@test "kaptain-run: prefers the base tag when it exists locally" {
  local project_dir="${BATS_TEST_TMPDIR}/run-multi-arch"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  # Podman multi-arch: the base tag is a local manifest list alongside the
  # per-architecture tags, and the manifest list is what ships
  export STUB_IMAGES="reg.example/ns/app:1.0.0
reg.example/ns/app:1.0.0-linux-amd64
reg.example/ns/app:1.0.0-linux-arm64"
  export STUB_PORTS='{"80/tcp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_RUN: --rm --init -p 4242:80 reg.example/ns/app:1.0.0"* ]]
}

@test "kaptain-run: falls back to the arch-suffixed tag when the base is absent" {
  [ -n "${HOST_ARCH}" ] || skip "unmapped host architecture: $(uname -m)"

  local project_dir="${BATS_TEST_TMPDIR}/run-arch-fallback"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  # Docker multi-arch: no local manifest list, so only the arch tags exist.
  # Running the base tag here would reach for the registry.
  export STUB_IMAGES="reg.example/ns/app:1.0.0-linux-amd64
reg.example/ns/app:1.0.0-linux-arm64"
  export STUB_PORTS='{"80/tcp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_RUN: --rm --init -p 4242:80 reg.example/ns/app:1.0.0-linux-${HOST_ARCH}"* ]]
}

@test "kaptain-run: uses the base tag for a single-arch build" {
  local project_dir="${BATS_TEST_TMPDIR}/run-single-arch"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='{"80/tcp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUB_RUN: --rm --init -p 4242:80 reg.example/ns/app:1.0.0"* ]]
}

@test "kaptain-run: header names the project from versions-and-naming" {
  local project_dir="${BATS_TEST_TMPDIR}/run-project-name"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"
  echo "PROJECT_NAME=image-busybox-httpd" \
    > "${project_dir}/kaptain-out/reference-script-output/versions-and-naming"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='{"80/tcp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running latest main image for image-busybox-httpd:"* ]]
  [[ "$output" == *"To view your app or site, use the below URLs:"* ]]
}

@test "kaptain-run: header falls back to the directory name" {
  local project_dir="${BATS_TEST_TMPDIR}/run-fallback-name"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='{"80/tcp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running latest main image for run-fallback-name:"* ]]
}

@test "kaptain-run: prints a localhost link per tcp port" {
  local project_dir="${BATS_TEST_TMPDIR}/run-links"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='{"8080/tcp":{},"80/tcp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://localhost:4242  (container 80)"* ]]
  [[ "$output" == *"http://localhost:4243  (container 8080)"* ]]
  [[ "$output" == *"Press Ctrl-C to stop."* ]]
}

@test "kaptain-run: udp ports are published but not linked" {
  local project_dir="${BATS_TEST_TMPDIR}/run-links-udp"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='{"80/tcp":{},"53/udp":{}}'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  # 53 sorts below 80, so udp takes 4242 and tcp takes 4243
  [[ "$output" == *"-p 4242:53/udp -p 4243:80"* ]]
  [[ "$output" == *"http://localhost:4243  (container 80)"* ]]
  [[ "$output" != *"4242  (container 53)"* ]]
}

@test "kaptain-run: no exposed ports means no links" {
  local project_dir="${BATS_TEST_TMPDIR}/run-links-none"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES="reg.example/ns/app:1.0.0"
  export STUB_PORTS='null'
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 0 ]
  [[ "$output" != *"http://localhost"* ]]
  [[ "$output" != *"Local:"* ]]
  [[ "$output" == *"Press Ctrl-C to stop."* ]]
}

@test "kaptain-run: fails when no local image matches" {
  local project_dir="${BATS_TEST_TMPDIR}/run-missing-image"
  mkdir -p "${project_dir}"
  make_build_output "${project_dir}" "reg.example/ns/app:1.0.0"

  cd "${project_dir}"
  export STUB_IMAGES=""
  run "${TEST_BUILD}/kaptain-run"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No local image found"* ]]
}

# =============================================================================
# kaptain-run --bootstrap tests
# =============================================================================

GIT_IDENTITY=(-c user.name=Test -c user.email=test@example.com -c commit.gpgSign=false -c tag.gpgSign=false)

# A run-platform project cloned from a local origin carrying release tags:
# annotated 1.2.0 and 1.10.0 (latest by version, not by text), a lightweight
# 9.9.9 and an annotated 2.0.0-manifests, neither of which is a release.
# Leaves the test in the project dir with the stub engine on the build output.
make_bootstrap_project() {
  local name="$1"
  local engine="${2:-${STUB_ENGINE}}"
  local origin="${BATS_TEST_TMPDIR}/${name}-origin.git"
  local seed="${BATS_TEST_TMPDIR}/${name}-seed"

  git init --quiet --bare "${origin}"
  git init --quiet "${seed}"
  git -C "${seed}" "${GIT_IDENTITY[@]}" commit --quiet --allow-empty -m "Initial"
  git -C "${seed}" "${GIT_IDENTITY[@]}" tag -a 1.2.0 -m "Release 1.2.0"
  git -C "${seed}" "${GIT_IDENTITY[@]}" tag -a 1.10.0 -m "Release 1.10.0"
  git -C "${seed}" tag 9.9.9
  git -C "${seed}" "${GIT_IDENTITY[@]}" tag -a 2.0.0-manifests -m "Manifests 2.0.0"
  git -C "${seed}" push --quiet "${origin}" --all
  git -C "${seed}" push --quiet "${origin}" --tags

  BOOTSTRAP_PROJECT="${BATS_TEST_TMPDIR}/${name}"
  git clone --quiet --no-tags "${origin}" "${BOOTSTRAP_PROJECT}"
  # As a run-platform build leaves it: no docker-build-dockerfile output,
  # the deploy image URI in kubernetes-run-package instead
  printf 'kind: kubernetes-run-platform-meta-environment\n' > "${BOOTSTRAP_PROJECT}/KaptainPM.yaml"
  make_build_output "${BOOTSTRAP_PROJECT}" "" "${engine}"
  echo "RUN_DEPLOY_IMAGE_URI=reg.example/ns/rp:0.0.1-PRERELEASE" \
    > "${BOOTSTRAP_PROJECT}/kaptain-out/reference-script-output/kubernetes-run-package"

  export PATH="${STUB_BIN}:${PATH}"
  export STUB_UNAME_S="Darwin"
  export STUB_ENV=$'PATH=/kd/bin:/usr/bin\nENVIRONMENT=run-platform-test\nENVIRONMENT_TYPE=meta-env\nKAPTAIN_USER_ID=4242'
  export STUB_LOG="${BATS_TEST_TMPDIR}/stub.log"
  export STUB_STDIN_FILE="${BATS_TEST_TMPDIR}/stub-stdin"
  : > "${STUB_LOG}"

  cd "${BOOTSTRAP_PROJECT}"
}

file_mode() {
  stat -c '%a' "$1" 2> /dev/null || stat -f '%Lp' "$1"
}

@test "kaptain-run: --tag without --bootstrap fails" {
  run "${TEST_BUILD}/kaptain-run" --tag 1.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"--tag and --dir only apply with --bootstrap"* ]]
}

@test "kaptain-run: --dir without --bootstrap fails" {
  mkdir -p "${BATS_TEST_TMPDIR}/somewhere"
  cd "${BATS_TEST_TMPDIR}"
  run "${TEST_BUILD}/kaptain-run" --dir somewhere
  [ "$status" -eq 1 ]
  [[ "$output" == *"--tag and --dir only apply with --bootstrap"* ]]
}

@test "kaptain-run: --tag must be a plain release version" {
  run "${TEST_BUILD}/kaptain-run" --bootstrap --tag 1.2.3-manifests
  [ "$status" -eq 1 ]
  [[ "$output" == *"--tag must be a release version"* ]]
}

@test "kaptain-run: --tag accepts one to six numeric parts" {
  make_bootstrap_project tag-parts
  run "${TEST_BUILD}/kaptain-run" --bootstrap --tag 1.2.3.4.5.6 <<< "n"
  [[ "$output" != *"--tag must be a release version"* ]]
  run "${TEST_BUILD}/kaptain-run" --bootstrap --tag 1.2.3.4.5.6.7
  [ "$status" -eq 1 ]
  [[ "$output" == *"--tag must be a release version"* ]]
}

@test "kaptain-run: --dir must be relative" {
  run "${TEST_BUILD}/kaptain-run" --bootstrap --dir /tmp
  [ "$status" -eq 1 ]
  [[ "$output" == *"--dir must be a relative path"* ]]
}

@test "kaptain-run: --dir must exist" {
  cd "${BATS_TEST_TMPDIR}"
  run "${TEST_BUILD}/kaptain-run" --bootstrap --dir no-such-dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"--dir directory does not exist: no-such-dir"* ]]
}

@test "kaptain-run: --bootstrap fails outside a kaptain project" {
  mkdir -p "${BATS_TEST_TMPDIR}/not-a-project"
  cd "${BATS_TEST_TMPDIR}/not-a-project"
  run "${TEST_BUILD}/kaptain-run" --bootstrap
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not a kaptain project: no KaptainPM.yaml"* ]]
}

@test "kaptain-run: --bootstrap needs a build, as run does" {
  mkdir -p "${BATS_TEST_TMPDIR}/unbuilt"
  printf 'kind: kubernetes-run-platform-meta-environment\n' > "${BATS_TEST_TMPDIR}/unbuilt/KaptainPM.yaml"
  cd "${BATS_TEST_TMPDIR}/unbuilt"
  run "${TEST_BUILD}/kaptain-run" --bootstrap
  [ "$status" -eq 1 ]
  [[ "$output" == *"No build output found"* ]]
  [[ "$output" == *"kaptain build"* ]]
}

@test "kaptain-run: --bootstrap refuses a project that is not a run-platform" {
  make_bootstrap_project wrong-kind
  printf 'kind: docker-build-dockerfile\n' > KaptainPM.yaml
  run "${TEST_BUILD}/kaptain-run" --bootstrap
  [ "$status" -eq 1 ]
  [[ "$output" == *"--bootstrap needs a kubernetes-run-platform-meta-environment project, this is 'docker-build-dockerfile'"* ]]
}

@test "kaptain-run: --bootstrap fails when the build wrote no deploy image URI" {
  make_bootstrap_project no-deploy-uri
  rm kaptain-out/reference-script-output/kubernetes-run-package
  run "${TEST_BUILD}/kaptain-run" --bootstrap
  [ "$status" -eq 1 ]
  [[ "$output" == *"no RUN_DEPLOY_IMAGE_URI in"* ]]
}

@test "kaptain-run: --bootstrap uses the latest annotated numeric tag into a new private dir" {
  make_bootstrap_project latest
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  grep -qxF "STUB_PULL: reg.example/ns/rp:1.10.0" "${STUB_LOG}"
  [[ "$output" == *"Pulled reg.example/ns/rp:1.10.0"* ]]
  [[ "$output" == *"Running bootstrap process against latest 1.10.0 into bootstrap-latest/."* ]]
  [[ "$output" == *"Bootstrap Container Output"* ]]
  [[ "$output" == *"End Of Bootstrap Container Output"* ]]
  [[ "$output" == *"If you approve you'll be asked for the decryption key. Proceed?"* ]]
  [ -d bootstrap-latest ]
  [ "$(file_mode bootstrap-latest)" = "700" ]
  [[ "$output" == *"Bootstrap manifests for latest 1.10.0 are in bootstrap-latest/"* ]]
}

@test "kaptain-run: --bootstrap writes an apply script matching the in-cluster deploys, namespace first" {
  make_bootstrap_project apply-steps
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  [[ "$output" == *"delete them as soon as you've applied"* ]]
  [[ "$output" == *"Use the following script to apply them, and ensure you copy"* ]]
  [[ "$output" == *"it with the manifests if moving them to another machine:"* ]]
  [[ "$output" == *"  ./bootstrap-apply-steps.bash"* ]]
  [ -x bootstrap-apply-steps.bash ]
  [ "$(file_mode bootstrap-apply-steps.bash)" = "700" ]
  [ "$(<bootstrap-apply-steps.bash)" = "#!/usr/bin/env bash
kubectl apply --server-side --force-conflicts --field-manager=kaptain/meta-env/run-platform-test -f bootstrap-apply-steps/namespace.yaml
kubectl apply -n run-platform-test --server-side --force-conflicts --field-manager=kaptain/meta-env/run-platform-test -R -f bootstrap-apply-steps/" ]
}

@test "kaptain-run: --bootstrap apply script is named after a given --dir" {
  make_bootstrap_project apply-dir
  mkdir -m 700 out
  run "${TEST_BUILD}/kaptain-run" --bootstrap --dir out/ < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  [[ "$output" == *"  ./out.bash"* ]]
  grep -qF -- "-f out/namespace.yaml" out.bash
  grep -qF -- "-R -f out/" out.bash
}

@test "kaptain-run: --bootstrap refuses to overwrite an existing apply script, before approval" {
  make_bootstrap_project script-exists
  printf 'mine\n' > bootstrap-script-exists.bash
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"bootstrap-script-exists.bash already exists - remove it first"* ]]
  [[ "$output" != *"Proceed?"* ]]
  [ "$(<bootstrap-script-exists.bash)" = "mine" ]
}

@test "kaptain-run: --bootstrap refuses an image without ENVIRONMENT" {
  make_bootstrap_project no-env-name
  export STUB_ENV=$'ENVIRONMENT_TYPE=meta-env\nKAPTAIN_USER_ID=4242'
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no ENVIRONMENT"* ]]
  [[ "$output" != *"Proceed?"* ]]
}

@test "kaptain-run: --bootstrap runs offline, read-only and unprivileged with tmpfs work" {
  make_bootstrap_project hardened
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  local mount_dir
  mount_dir="$(cd bootstrap-hardened && pwd)"
  [[ "$output" == *"STUB_RUN: --rm --init -i --network none --read-only --cap-drop ALL --security-opt no-new-privileges --tmpfs /secret:rw,mode=1777 --tmpfs /kd/work:rw,mode=1777 --tmpfs /tmp:rw,mode=1777 -v ${mount_dir}:/kd/bootstrap --entrypoint sh reg.example/ns/rp:1.10.0 -c cat > /secret/environmentPassphrase && exec /kd/bin/bootstrap"* ]]
}

@test "kaptain-run: --bootstrap sends the key on stdin, never as an argument" {
  make_bootstrap_project key-stdin
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  [ "$(<"${STUB_STDIN_FILE}")" = "secret-key" ]
  [[ "$output" != *"secret-key"* ]]
}

@test "kaptain-run: --bootstrap --tag skips the tag lookup" {
  make_bootstrap_project given-tag
  git remote remove origin
  run "${TEST_BUILD}/kaptain-run" --bootstrap --tag 1.2.0 < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  grep -qxF "STUB_PULL: reg.example/ns/rp:1.2.0" "${STUB_LOG}"
}

@test "kaptain-run: --bootstrap fails with no git remote to fetch tags from" {
  make_bootstrap_project no-remote
  git remote remove origin
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"No git remote to fetch tags from. Pass --tag to choose a release."* ]]
}

@test "kaptain-run: --bootstrap fails when tags cannot be fetched" {
  make_bootstrap_project fetch-fails
  git remote set-url origin "${BATS_TEST_TMPDIR}/no-such-origin.git"
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not fetch tags. Pass --tag to choose a release."* ]]
}

@test "kaptain-run: --bootstrap fails with no release tag" {
  make_bootstrap_project no-release
  # Only lightweight 9.9.9 and suffixed 2.0.0-manifests remain
  git push --quiet origin :refs/tags/1.2.0 :refs/tags/1.10.0
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"No release tag found"* ]]
  [ ! -e bootstrap-no-release ]
}

@test "kaptain-run: --bootstrap fails when the pull fails" {
  make_bootstrap_project pull-fails
  export STUB_PULL_STATUS=1
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not pull reg.example/ns/rp:1.10.0"* ]]
  [ ! -e bootstrap-pull-fails ]
}

@test "kaptain-run: --bootstrap refuses an image that is not a run-platform, before approval" {
  make_bootstrap_project not-rp
  export STUB_ENV=$'ENVIRONMENT=run-test\nENVIRONMENT_TYPE=env\nKAPTAIN_USER_ID=4242'
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a run-platform image"* ]]
  [[ "$output" != *"Proceed?"* ]]
  [ ! -e bootstrap-not-rp ]
}

@test "kaptain-run: --bootstrap refuses an image without a numeric KAPTAIN_USER_ID" {
  make_bootstrap_project no-uid
  export STUB_ENV=$'ENVIRONMENT=run-platform-test\nENVIRONMENT_TYPE=meta-env'
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no numeric KAPTAIN_USER_ID"* ]]
}

@test "kaptain-run: --bootstrap refuses an image without the bootstrap script" {
  make_bootstrap_project no-script
  export STUB_BOOTSTRAP_CHECK_STATUS=1
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no /kd/bin/bootstrap"* ]]
  [[ "$output" != *"Proceed?"* ]]
}

@test "kaptain-run: --bootstrap stops on n, q, Esc or end of input, creating nothing" {
  make_bootstrap_project cancel
  local answer
  for answer in n N q Q $'\e' ''; do
    run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf '%s' "${answer}")
    [ "$status" -eq 1 ]
    [[ "$output" == *"Bootstrap cancelled."* ]]
    [[ "$output" != *"STUB_RUN:"* ]]
    [ ! -e bootstrap-cancel ]
  done
}

@test "kaptain-run: --bootstrap proceeds on Enter or Y" {
  make_bootstrap_project proceed
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf '\nsecret-key\n')
  [ "$status" -eq 0 ]
  rmdir bootstrap-proceed
  rm bootstrap-proceed.bash
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'Ysecret-key\n')
  [ "$status" -eq 0 ]
}

@test "kaptain-run: --bootstrap asks again on any other key" {
  make_bootstrap_project reprompt
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'xysecret-key\n')
  [ "$status" -eq 0 ]
  [[ "$output" == *"Press Enter or y to proceed, or n, q or Esc to stop."* ]]
  [ "$(<"${STUB_STDIN_FILE}")" = "secret-key" ]
}

@test "kaptain-run: --bootstrap with no key entered removes the dir it created" {
  make_bootstrap_project no-key
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'y\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"No decryption key entered"* ]]
  [[ "$output" != *"STUB_RUN:"* ]]
  [ ! -e bootstrap-no-key ]
}

@test "kaptain-run: --bootstrap failure passes the exit on and removes the empty dir it created" {
  make_bootstrap_project run-fails
  export STUB_RUN_STATUS=49
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 49 ]
  [[ "$output" == *"Bootstrap failed (exit 49)"* ]]
  [ ! -e bootstrap-run-fails ]
  [ ! -e bootstrap-run-fails.bash ]
}

@test "kaptain-run: --bootstrap fails when the default dir already exists" {
  make_bootstrap_project exists
  mkdir -m 700 bootstrap-exists
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"bootstrap-exists/ already exists"* ]]
  [[ "$output" == *"pass --dir bootstrap-exists"* ]]
}

@test "kaptain-run: --bootstrap --dir uses a private dir and leaves it on failure" {
  make_bootstrap_project given-dir
  mkdir -m 700 out
  export STUB_RUN_STATUS=1
  run "${TEST_BUILD}/kaptain-run" --bootstrap --dir out < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"into out/."* ]]
  [[ "$output" == *":/kd/bootstrap "* ]]
  [ -d out ]
}

@test "kaptain-run: --bootstrap --dir refuses a dir others can access" {
  make_bootstrap_project open-dir
  local mode
  for mode in 755 750 701 770; do
    rm -rf out
    mkdir -m "${mode}" out
    run "${TEST_BUILD}/kaptain-run" --bootstrap --dir out < <(printf 'ysecret-key\n')
    [ "$status" -eq 1 ]
    [[ "$output" == *"out/ must be private (mode 700), it is ${mode}"* ]]
    [[ "$output" == *"chmod 700 out"* ]]
  done
}

@test "kaptain-run: --bootstrap --dir refuses a dir the owner cannot fully use" {
  make_bootstrap_project owner-dir
  mkdir -m 500 out
  run "${TEST_BUILD}/kaptain-run" --bootstrap --dir out < <(printf 'ysecret-key\n')
  chmod 700 out
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be private (mode 700), it is 500"* ]]
}

@test "kaptain-run: --bootstrap on macOS adds no user mapping or relabel" {
  make_bootstrap_project macos "${STUB_ENGINES}/docker"
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  [[ "$output" != *"--user"* ]]
  [[ "$output" != *"--userns"* ]]
  [[ "$output" != *":/kd/bootstrap:Z"* ]]
}

@test "kaptain-run: --bootstrap with rootful docker on Linux runs as the invoking user" {
  make_bootstrap_project linux-docker "${STUB_ENGINES}/docker"
  export STUB_UNAME_S="Linux"
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  [[ "$output" == *"--user $(id -u):$(id -g) --tmpfs"* ]]
  [[ "$output" == *":/kd/bootstrap:Z "* ]]
}

@test "kaptain-run: --bootstrap with rootless docker on Linux runs as container root" {
  make_bootstrap_project linux-rootless "${STUB_ENGINES}/docker"
  export STUB_UNAME_S="Linux"
  export STUB_DOCKER_SECURITY="[name=seccomp,profile=builtin name=rootless]"
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  [[ "$output" == *"--user 0:0 --tmpfs"* ]]
}

@test "kaptain-run: --bootstrap with podman on Linux keeps the invoking user as the image user" {
  if [[ "$(id -u)" -eq 0 ]]; then
    skip "keep-id applies to non-root users only"
  fi
  make_bootstrap_project linux-podman "${STUB_ENGINES}/podman"
  export STUB_UNAME_S="Linux"
  export STUB_PODMAN_VERSION="4.3.0"
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 0 ]
  [[ "$output" == *"--userns=keep-id:uid=4242,gid=4242 --tmpfs"* ]]
  [[ "$output" == *":/kd/bootstrap:Z "* ]]
}

@test "kaptain-run: --bootstrap with podman older than 4.3 on Linux fails before approval" {
  if [[ "$(id -u)" -eq 0 ]]; then
    skip "keep-id applies to non-root users only"
  fi
  make_bootstrap_project old-podman "${STUB_ENGINES}/podman"
  export STUB_UNAME_S="Linux"
  export STUB_PODMAN_VERSION="4.2.9"
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bootstrap needs podman 4.3 or later, found 4.2.9"* ]]
  [[ "$output" != *"Proceed?"* ]]
}

@test "kaptain-run: --bootstrap on Linux refuses an engine it cannot map" {
  make_bootstrap_project linux-other "${STUB_ENGINES}/nerdctl"
  export STUB_UNAME_S="Linux"
  run "${TEST_BUILD}/kaptain-run" --bootstrap < <(printf 'ysecret-key\n')
  [ "$status" -eq 1 ]
  [[ "$output" == *"supports podman and docker"* ]]
}
