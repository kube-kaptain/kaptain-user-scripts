# Agents

Instructions for AI agents working on this codebase.


## Project Overview

Bash scripts for users of the Kaptain Kubernetes build and deploy system. The CLI routes
commands through a prefix-matching system: `kaptain list secrets` calls `kaptain` which calls
`kaptain-list` which calls `kaptain-list-secrets`. All scripts live under `src/scripts/`
organised by category.


## Project Structure

```
src/scripts/cli/           CLI entrypoint, help, routers (list, clean)
src/scripts/encryption/    Encrypt/decrypt leaf scripts, routers, keygen, rotate, check-ignores
src/scripts/util/          List config/secrets/manifests, clean secrets
src/test/                  BATS test files
src/docker/                Dockerfile, completion script
.github/bin/               Test runner, completion generator, release packager
```


## Running Tests

```bash
.github/bin/run-tests.bash
```

This runs 4 stages: check scripts (shellcheck etc), BATS tests, and a completions staleness
check. All stages must pass. Run this after every change.

BATS requires `bats-core` installed locally (`brew install bats-core` on macOS).


## Completions

Completion data in `src/docker/kaptain-completion.bash` is auto-generated from script case
blocks. After adding or changing flags on any script, regenerate:

```bash
.github/bin/generate-completions.bash
```

The test runner will fail if completions are stale. Never hand-edit the section between the
`BEGIN GENERATED COMPLETIONS` and `END GENERATED COMPLETIONS` markers.


## Script Conventions

- All scripts use `set -euo pipefail`
- All scripts have the license header: `# SPDX-License-Identifier: MIT`
- Copyright line: `# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)`
- Scripts are executable files with no extension, named `kaptain-<command>[-<subcommand>]`
- Argument parsing uses `while [[ $# -gt 0 ]]; do case "$1" in` pattern
- `--dir` must reject absolute paths: `if [[ "$2" == /* ]]`
- `--dir` must check directory exists: `if [[ ! -d "$2" ]]`
- Default directories come from environment variables with hardcoded fallbacks:
  `SECRETS_DIR="${KAPTAIN_USER_SCRIPTS_SECRETS_DIR:-src/secrets}"`
- All 10 encrypt/decrypt leaf scripts share identical arg parsing structure supporting
  `--dir DIR`, `--key-file FILE`, and `-h|--help`


## Adding a New Script

1. Create the script in the appropriate `src/scripts/` subdirectory
2. Make it executable
3. If it has flags, regenerate completions
4. Add it to `kaptain-help` describe_command if it's a top-level command
5. Add it to the help text detail section if it needs flag documentation
6. Add it to the README.md script table
7. Add it to KaptainCLIDesign.md script list
8. Add tests in `src/test/`
9. Run the full test suite


## Documentation

Keep these files in sync when adding scripts, flags, or env vars:

- `README.md` — script tables, env var table, feature descriptions
- `KaptainCLIDesign.md` — script lists, release packaging
- `EncryptionWalkthrough.md` — beginner walkthrough (encryption workflow only)
- `src/scripts/cli/kaptain-help` — describe_command entries, detail sections, env var list

When adding an environment variable, update all four: the script that reads it, the README
env var table, the kaptain-help env var section, and any relevant tests.


## Test Patterns

Tests use BATS. Common patterns:

- Test files create temp directories in `setup()` and clean up in `teardown()`
- Encryption round-trip tests pipe passphrases via stdin: `echo "key" | script --dir "$dir"`
- Use `run` to capture exit codes: `run script --bad-flag` then check `$status` and `$output`
- Test file naming matches the feature: `encryption.bats`, `rotate.bats`, `cli.bats`, etc.


## Things to Watch For

- Subshell variable loss: writing to variables inside pipes or subshells loses the value
  in the parent shell. This is a common bash pitfall.
- The encrypt/decrypt leaf scripts validate keys against existing encrypted files. During
  rotation, old encrypted files must be deleted before re-encrypting with a new key.
- Cross-platform `stat`: use GNU `stat -c '%a'` first, then BSD `stat -f '%Lp'` as fallback.
  Do not reverse the order — BSD `stat -f` means "filesystem" and succeeds with wrong output
  on Linux.
- OpenSSL can sometimes "successfully" decrypt small inputs with the wrong key. This causes
  occasional flaky test failures on key validation tests. Not a code bug.
