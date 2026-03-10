# kaptain-rotate-key-for-secrets Design

## Command
`kaptain-rotate-key-for-secrets [--dir DIR] [--ask-for-key] [--new-type TYPE] [--output FILE]`

## Flags
- `--dir DIR` — secrets directory override (default: KAPTAIN_USER_SCRIPTS_SECRETS_DIR or src/secrets)
- `--ask-for-key` — prompt for new key instead of generating (ask twice, compare)
- `--new-type TYPE` — migrate to different encryption type (default: same as current)
- `--output FILE` — where to write generated key (default: target/keygen/new.key)
- `-h|--help` — help

## Pre-flight checks (all must pass before any work)
1. No .txt or .raw files in directory — fail with "run kaptain clean secrets first"
2. At least one encrypted file exists
3. All encrypted files are a known type (discovered from available encrypt scripts)
4. All encrypted files are the same type — no mixed encryption

## Key handling — two modes

### Generate (default)
- Write new key to temp file via `kaptain-keygen --type <type> --output <tmpfile>`
- Read key from temp file for encrypt step
- Ask user for old key only

### --ask-for-key
- Ask for old key
- Ask for new key twice, compare, fail if mismatch

## Operation steps
1. Pre-flight checks (clean dir, files exist, single known type)
2. Collect old key
3. Generate or collect new key
4. Decrypt all with old key → produces .txt files
5. If any failed: clean up .txt files, report which failed, exit without re-encrypting, delete temp key file if generated
6. All succeeded: rename each .txt to .raw (encrypt scripts read .raw)
7. Re-encrypt all from .raw with new key (same extension overwrites old; if --new-type, different extension)
8. If --new-type and different extension: delete old-type encrypted files
9. Clean up .raw files
10. Collect all output, print it
11. Move temp key file to --output location (default target/keygen/new.key), tell user where it is
12. Report success

## File path handling for --output
- Same validation as keygen: relative paths, check parent exists, refuse to overwrite
- Default: target/keygen/new.key (target/ is typically gitignored)

## Env var
KAPTAIN_USER_SCRIPTS_SECRETS_DIR — same as all other scripts

## Script location
src/scripts/encryption/kaptain-rotate-key-for-secrets

## Notes
- Reuse kaptain-keygen for key generation
- Reuse existing decrypt/encrypt leaf scripts for the actual crypto
- The decrypt scripts produce .txt, encrypt scripts consume .raw — must rename between steps
- Key is captured/stored but NOT displayed until after all work succeeds
- On failure, temp key file is cleaned up and never shown
