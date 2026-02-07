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
3. If uniform → delegate to specific `kaptain-decrypt-secrets-<type>` script by pattern
4. Direct long-name calls still work for automation that knows its type or users who prefer no magic
5. **Explicit override**: `--type age|sha256.aes256|sha256.aes256.10k|...`
5. **Explicit override**: `--dir secrets`


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

### Encryption Scripts (callable for direct use if desired)
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

## TODO

- [ ] Create homebrew-kaptain meta package - pros/cons?
- [ ] Rename scripts as above
- [ ] Create `kaptain` wrapper script
- [ ] Create `kaptain-decrypt` dispatcher
- [ ] Create `kaptain-encrypt` dispatcher with type detection logic

## Future

- [ ] Create `kaptain-build` dispatcher


## Release Packaging

Three bundles produced from kaptain-user-scripts repo:

| Bundle                    | Contents                              | Used By                     |
|---------------------------|---------------------------------------|-----------------------------|
| `kaptain-user-scripts`    | Full zip (kaptain + encryption)       | Standalone install          |
| `kaptain-wrapper`         | Kaptain wrapper only                  | `kaptain` formula           |
| `kaptain-encryption`      | Encryption scripts only (no wrapper)  | `kaptain-user-scripts` formula |

### Dependency Structure

```
brew install kaptain
  └── depends_on kaptain-user-scripts (encryption scripts)
      └── downloads kaptain-encryption bundle

brew install kaptain-user-scripts
  └── downloads kaptain-encryption bundle

brew install kaptain-standalone  # hypothetical, gets everything in one
  └── downloads full kaptain-user-scripts bundle
```

This allows:
- `kaptain` to install wrapper + depend on encryption scripts
- `kaptain-user-scripts` to install just encryption (no wrapper)
- Clean separation, no duplication
