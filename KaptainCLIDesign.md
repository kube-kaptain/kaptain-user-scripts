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


## Build Subcommand (future)

- Reads `KaptainPM.yaml` from current directory
- Extracts `kind` field, validates supported type - clear error if not
- Dispatches to appropriate build script based on kind (docker, manifests, etc.)


## Script Structure

### Wrapper
- `kaptain` - main entrypoint, routes to subcommands

### Subcommand Dispatchers
- `kaptain-decrypt` - detects type, delegates
- `kaptain-encrypt` - detects/defaults type, delegates
- `kaptain-build` - future, see below

### kaptain-build

* reads KaptainPM.yaml, delegates to reference scripts in build scripts package
* need to think about how to install these - on path with brew or dynamically via docker use some user cache mechanism on a standard path 

### Utility Scripts
- `kaptain-list-config`
- `kaptain-list-secrets`
- `kaptain-list-manifests`
- `kaptain-clean-secrets`

### Encryption Scripts (callable for direct use if desired)
- `kaptain-keygen`
- `kaptain-rotate-key-for-secrets`
- `kaptain-encryption-check-ignores`
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

## Future

- [ ] Create `kaptain-build` dispatcher

## Release Packaging

Five bundles produced from kaptain-user-scripts repo:

| Bundle                              | Contents                                                  |
|-------------------------------------|-----------------------------------------------------------|
| `kaptain-user-scripts.zip`          | All scripts (cli + encryption + util)                     |
| `kaptain-user-scripts-cli.zip`      | CLI scripts only (kaptain, kaptain-help, kaptain-clean, kaptain-list) |
| `kaptain-user-scripts-encryption.zip` | Encryption scripts only                                 |
| `kaptain-user-scripts-util.zip`     | Utility scripts (list-secrets, clean-secrets, etc.)       |
| `kaptain-user-scripts-42.zip`       | Meta package placeholder for brew                         |

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
