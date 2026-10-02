# Kaptain CLI Design

Kaptain user facing scripts for secret management and local builds etc.

## Overview

Maybe. Rename `kaptain-user-scripts` to `kaptain-cli` as the unified user-facing CLI tool for the Kaptain ecosystem.
Or: keep current name, consistent with build and deploy scripts - three categories, same naming. 

## Subcommand Structure

```bash
kaptain decrypt    # auto-detect type from existing encrypted files, decrypt, use `src/secrets` by default
kaptain encrypt    # encrypt (auto-detect or default, see logic below)
kaptain build      # reads KaptainPM.yaml, dispatches by kind field
kaptain run        # runs the main image from the most recent build
```

## Encrypt Type Selection Logic

1. **Directory with only `.raw` files**: default to `age`
2. **Directory with some encrypted files**: detect type from extensions, use that style
3. **Mixed encrypted types**: error with clear message (same as decrypt and deploy scripts)
4. **Explicit override**: `--type age|sha256.aes256|sha256.aes256.10k|...`
5. **Explicit override**: `--dir secrets`


## Decrypt Type Detection Logic

0. Scan script dir for `kaptain-decrypt-<suffix>` and build list of supported types (future proof) 
1. Scan directory for encrypted file extensions from found supported list (`.age`, `.sha256.aes256`, `.sha256.aes256.10k`, etc.)
2. If mixed types → error with clear message
3. If uniform → delegate to specific `kaptain-decrypt-<type>` script by pattern
4. Direct long-name calls still work for automation that knows its type or users who prefer no magic
5. **Explicit override**: `--type age|sha256.aes256|sha256.aes256.10k|...`
6. **Explicit override**: `--dir secrets`


## Build Subcommand

- Checks `KAPTAIN_USER_SCRIPTS_BUILD_SCRIPTS_REPO_ROOT` is set and valid
- Reads `kind` from `KaptainPM.yaml` (project root) — required, fails fast if missing
- Cleans build output (always)
- Dispatches to `src/scripts/reference/<kind>` in the build scripts repo
- `--run` runs `kaptain-run` after the build, as a separate invocation


## Run Subcommand

- Reads `IMAGE_BUILD_COMMAND` and `DOCKER_TARGET_IMAGE_FULL_URI` from the build
  output under `kaptain-out/reference-script-output/`
- Prefers the base tag, which under podman is the local multi-arch manifest list;
  falls back to the architecture-suffixed tag, which is all docker leaves behind
- Publishes each exposed port from 4242 upward, preserving the protocol
- Runs with `--rm`; the image's own `CMD` or `ENTRYPOINT` decides what runs
- `--bootstrap` runs a released run-platform image's `/kd/bin/bootstrap` instead:
  - Image repository from the build output
  - Tag from `--tag` or the latest annotated tag after `git fetch --tags`
  - Output to `--dir` (must exist, owned by the user, mode 700) or to
    `bootstrap-<project>`, created mode 700 after approval
  - Pulls and checks the image (meta-env, numeric `KAPTAIN_USER_ID`,
    `/kd/bin/bootstrap` present) before asking for approval
  - Asks for the encryption key and securely mounts it in the container
  - Writes `<dir>.bash` beside the output: two `kubectl apply` lines, the
    namespace first then the whole directory, as the in-cluster deploys apply


## Script Structure

### Wrapper
- `kaptain` - main entrypoint, routes to subcommands

### Subcommand Dispatchers
- `kaptain-decrypt`   - detects type, delegates
- `kaptain-encrypt`   - detects/defaults type, delegates
- `kaptain-build`     - resolves kind, delegates to build scripts repo
- `kaptain-update`    - dispatches to `kaptain-update-<target>` (e.g. versions)
- `kaptain-setup`     - dispatches to `kaptain-setup-<target>` (e.g. brew)
- `kaptain-normalise` - dispatches to `kaptain-normalise-<target>` (config, secrets)

### Build Scripts
- `kaptain-build`
- `kaptain-run`
- `kaptain-clean-project`
- `kaptain-update`
- `kaptain-update-versions`

### Utility Scripts
- `kaptain-list-config`
- `kaptain-list-secrets`
- `kaptain-list-manifests`
- `kaptain-clean-secrets`
- `kaptain-clean-images`
- `kaptain-list-images`
- `kaptain-normalise-config`
- `kaptain-setup-brew`

### Encryption Scripts (callable for direct use if desired)
- `kaptain-keygen`
- `kaptain-rotate-key-for-secrets`
- `kaptain-encryption-check-ignores`
- `kaptain-encryption-detect-type`
- `kaptain-normalise-secrets`
- `kaptain-decrypt-age`
- `kaptain-encrypt-age`
- `kaptain-decrypt-sha256.aes256`
- `kaptain-encrypt-sha256.aes256`
- `kaptain-decrypt-sha256.aes256.10k`
- `kaptain-encrypt-sha256.aes256.10k`
- `kaptain-decrypt-sha256.aes256.100k`
- `kaptain-encrypt-sha256.aes256.100k`
- `kaptain-decrypt-sha256.aes256.600k`
- `kaptain-encrypt-sha256.aes256.600k`


## Homebrew

- Add homebrew-kaptain - make it depend on homebrew-kaptain-user-scripts - and maybe other things
- Add dependency from user scripts to age and openssl - should be enough?

## Release Packaging

Five bundles produced from kaptain-user-scripts repo:

| Bundle                                | Contents                                                                             |
|---------------------------------------|--------------------------------------------------------------------------------------|
| `kaptain-user-scripts.zip`            | All scripts (cli + encryption + util)                                                |
| `kaptain-user-scripts-cli.zip`        | CLI scripts only (kaptain, kaptain-help, kaptain-clean, kaptain-list, kaptain-setup) |
| `kaptain-user-scripts-encryption.zip` | Encryption scripts only                                                              |
| `kaptain-user-scripts-util.zip`       | Utility scripts (list-secrets, clean-secrets, etc.)                                  |
| `kaptain-user-scripts-build.zip`      | Build scripts only (build, clean-project, update, update-versions)                   |
| `kaptain-user-scripts-42.zip`         | Meta package placeholder for brew                                                    |

### Dependency Structure

```
brew install kaptain                        # meta package, installs everything
  ├── depends_on kaptain-cli                # downloads kaptain-user-scripts-cli.zip
  ├── depends_on kaptain-encryption         # downloads kaptain-user-scripts-encryption.zip
  └── depends_on kaptain-util               # downloads kaptain-user-scripts-util.zip
      └── downloads kaptain-user-scripts-42.zip (kaptain-42 placeholder)

brew install kaptain-user-scripts           # standalone, everything in one zip
  └── downloads kaptain-user-scripts.zip
```

This allows:
- `kaptain` meta package to compose from individual formula packages
- `kaptain-user-scripts` to install everything standalone in one formula
- Individual formulas (`kaptain-cli`, `kaptain-encryption`, `kaptain-util`) installable separately
- `kaptain-encryption` depends on `age` and `openssl`
