# kaptain build user tools

Scripts:

kaptain-clean-project
kaptain-build

1. Requires a variable in the env to tell it where to find the repo - `KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT` - could be a repo or could be an unzipped or installed set of scripts up to the user - if NOT set explain the options and then fail 

2. Optional `KAPTAIN_USER_SCRIPTS_OUTPUT_SUB_PATH` to match build configuration which can come in by layer and can't be read until the build is started

3. If above not provided the output dir to clean up is `kaptain-out/` - and in both cases no matter what the output sub path is `kaptainpm/` - clean both of them up and use -rf for `kaptain-out/` or whatever the main output dir is since it can have .git dirs in it due to tests needing those. 

4. Use the `KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT`  value - ensure the dir exists, ensure it has src in it ensure it has src/scripts and src/schemas in it (both dirs) then use the `kaptain-init` to get a final `KaptainPM.yaml` in `kaptainpm/final/` then read the kind out of it and use that to execute the `src/scripts/reference/<script name from kind>` script.

5. If `kaptainpm/final/KaptainPM.yaml`  exists and is newer than `KaptainPM.yaml` then just read kind from it and WARN: Using cached build kind to select reference script! Remove and force an update if wrong.

6. Need to read from that file before running kaptain-clean-project - then run the clean project scrip[t then do the build with the value - if not present you can run the clean and then do the `kaptain-init` run

7. Assume run from repo root - use relative paths 

