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

@test "kaptain-build: uses cached kind from kaptainpm/final when newer" {
  local project_dir="${BATS_TEST_TMPDIR}/project-cached"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}/kaptainpm/final"
  mkdir -p "${fake_root}/src/scripts/reference"
  mkdir -p "${fake_root}/src/schemas"

  # Create KaptainPM.yaml WITHOUT kind, with old timestamp
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
name: test-project
YAML
  touch -t 202501010000 "${project_dir}/KaptainPM.yaml"

  # Create cached final with kind (newer than root)
  cat > "${project_dir}/kaptainpm/final/KaptainPM.yaml" <<'YAML'
kind: helm-chart
name: test-project
YAML

  # Create reference script
  cat > "${fake_root}/src/scripts/reference/helm-chart" <<'SCRIPT'
#!/usr/bin/env bash
echo "REFERENCE_SCRIPT_RAN:helm-chart"
SCRIPT
  chmod +x "${fake_root}/src/scripts/reference/helm-chart"

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
  [ "$status" -eq 0 ]
  [[ "$output" == *"cached"* ]]
  [[ "$output" == *"REFERENCE_SCRIPT_RAN:helm-chart"* ]]
}

@test "kaptain-build: runs kaptain-init when no kind found" {
  local project_dir="${BATS_TEST_TMPDIR}/project-no-kind"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}/src/scripts/reference"
  mkdir -p "${fake_root}/src/schemas"

  # Create KaptainPM.yaml WITHOUT kind
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
name: test-project
YAML

  # Create a fake kaptain-init that generates the final file
  mkdir -p "${fake_root}/src/scripts/main"
  cat > "${fake_root}/src/scripts/main/kaptain-init" <<'SCRIPT'
#!/usr/bin/env bash
echo "INIT_RAN"
mkdir -p kaptainpm/final
cat > kaptainpm/final/KaptainPM.yaml <<'INNER'
kind: docker-image
name: test-project
INNER
SCRIPT
  chmod +x "${fake_root}/src/scripts/main/kaptain-init"

  # Create reference script
  cat > "${fake_root}/src/scripts/reference/docker-image" <<'SCRIPT'
#!/usr/bin/env bash
echo "REFERENCE_SCRIPT_RAN:docker-image"
SCRIPT
  chmod +x "${fake_root}/src/scripts/reference/docker-image"

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
  [ "$status" -eq 0 ]
  [[ "$output" == *"INIT_RAN"* ]]
  [[ "$output" == *"CLEAN_RAN"* ]]
  [[ "$output" == *"REFERENCE_SCRIPT_RAN:docker-image"* ]]
}

@test "kaptain-build: fails when kaptain-init not found" {
  local project_dir="${BATS_TEST_TMPDIR}/project-no-init"
  local fake_root="${BATS_TEST_TMPDIR}/fake-build-repo"
  mkdir -p "${project_dir}"
  mkdir -p "${fake_root}/src/scripts/reference"
  mkdir -p "${fake_root}/src/schemas"

  # KaptainPM.yaml without kind, no cached file, no kaptain-init
  cat > "${project_dir}/KaptainPM.yaml" <<'YAML'
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
  [[ "$output" == *"kaptain-init"* ]]
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
