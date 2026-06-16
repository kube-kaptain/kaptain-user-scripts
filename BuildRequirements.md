# kaptain build user tools

Scripts:

kaptain-clean-project
kaptain-build

1. Requires a variable in the env to tell it where to find the repo - `KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT` - could be a repo or could be an unzipped or installed set of scripts up to the user - if NOT set explain the options and then fail 

2. Optional `KAPTAIN_USER_SCRIPTS_OUTPUT_SUB_PATH` to match build configuration which can come in by layer and can't be read until the build is started

3. If above not provided the output dir to clean up is `kaptain-out/` - and in both cases no matter what the output sub path is `kaptainpm/` - clean both of them up and use -rf for `kaptain-out/` or whatever the main output dir is since it can have .git dirs in it due to tests needing those. 

4. Use the `KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT` value - ensure the dir exists, ensure it has `src` in it, ensure it has `src/scripts` and `src/schemas` in it (both dirs), then read the `kind` field from `KaptainPM.yaml` and use that to execute the `src/scripts/reference/<script name from kind>` script.

5. `kind` is required at the top level of `KaptainPM.yaml` (enforced by the latest schemas). If missing, fail fast with a clear message telling the user to add it. Do not attempt to resolve `kind` from cached output or by running `kaptain-init`.

6. Read `kind` from `KaptainPM.yaml` before running `kaptain-clean-project`, then run the clean script, then execute the reference build script.

7. Assume run from repo root - use relative paths

