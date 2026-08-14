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
case "$1" in
  image)
    case "$2" in
      inspect)
        if [[ "$3" == "--format" ]]; then
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
    echo "STUB_RUN: $*"
    exit 0
    ;;
esac
exit 1
STUB
  chmod +x "${STUB_ENGINE}"

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
  echo "IMAGE_BUILD_COMMAND=${STUB_ENGINE}" > "${out}/validate-tooling"

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
