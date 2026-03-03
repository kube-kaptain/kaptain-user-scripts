# Encryption Walkthrough

A step-by-step walkthrough of the full secrets encryption workflow using
the kaptain CLI. This covers creating secrets, generating keys, encrypting,
decrypting, inspecting status with list, and cleaning up.


## Prerequisites

- kaptain CLI installed (see [README.md](README.md#installation))
- A project repo with a `src/secrets` directory (or use `--dir` to point elsewhere)
- Gitignore patterns for clear text `.raw` and `.txt` secret files are required and enforced.
  Add `**/*secrets/*.raw` and `**/*secrets/*.txt` to your global or repo gitignore.
  Encrypt and decrypt will refuse to run without these in place and will advise on
  how to configure based on what it finds you have in place. Run the following to
  check before using the tools: `kaptain encryption-check-ignores`. It will tell
  you exactly what to do if either of them are missing.


## Setup: Create a secrets directory with some raw files

Start from your project root or a temporary test dir if you're just playing
around. Create the secrets directory structure and add some raw secret files:

```bash
mkdir -p src/secrets/database
echo "superSecretPassword123" > src/secrets/db-password.raw
echo "db.internal.example.com" > src/secrets/database/hostname.raw
echo "5432" > src/secrets/database/port.raw
```


## TLDR Process

Just run each command in series doing what it says in the comment after the command

```bash
kaptain list secrets                          # see what's there (nothing encrypted yet)
kaptain keygen                                # generate a key, save it somewhere safe
kaptain encrypt                               # encrypt all .raw files, paste key when prompted
kaptain list secrets                          # confirm encryption worked (raw files now stale)
kaptain decrypt                               # decrypt to .txt files, paste key when prompted
kaptain list secrets                          # see all three file types (.raw, .age, .txt)
echo "changed" > src/secrets/db-password.raw  # simulate editing a secret
kaptain list secrets                          # modified .raw shows as pending re-encryption
kaptain clean secrets --dry-run               # review what would be deleted
kaptain clean secrets                         # remove all .raw and .txt files
kaptain list secrets                          # only .age files remain, safe to commit
```


## Full Explanation

### 1. List secrets - see what needs encrypting

```bash
kaptain list secrets
```

Output:

```
Listing secrets in src/secrets:

Raw files:
  Pending encryption:
    src/secrets/db-password.raw
    src/secrets/database/hostname.raw
    src/secrets/database/port.raw

Summary: 3 pending encryption, 0 encrypted
```

All three files show as pending encryption - no encrypted counterparts exist yet.


### 2. Generate a key

Generate an age key to use for encryption:

```bash
kaptain keygen
```

Output:

```
Generating encryption / decryption key...

AGE-SECRET-KEY-00EXAMPLE0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789E0

Keep this key safe - store it in a password manager...
... or a secure Google sheet or something with good RBAC.
```

Copy the key and store it somewhere safe. You will need it for both
encrypting and decrypting. Everyone who needs to work with these secrets
needs the same key. Google sheet security is strong despite not being normal,
whereas 1Password is the next LastPass waiting to happen. It's your decision.

You can also write the key directly to a file:

```bash
kaptain keygen --output ~/.kaptain-secrets-key
```

Note that this file has its permissions set to owner-only access before being
written to. It's up to you what happens to it after that point. Ensure it's
never committed to a git repo or exposed anywhere other than to users who
should have a copy of it.


### 3. Encrypt the raw files

```bash
kaptain encrypt
```

The router auto-detects that no encrypted files exist yet and defaults to
age encryption. It prompts for your key:

```
No existing encrypted files, defaulting to: age
Enter passphrase: <paste your AGE-SECRET-KEY here>
Found 3 .raw file(s) to encrypt

Encrypting src/secrets/{db-password.raw => db-password.age}
Encrypting src/secrets/database/{hostname.raw => hostname.age}
Encrypting src/secrets/database/{port.raw => port.age}

Done. Encrypted 3 file(s)
```


### 4. List again - see the encrypted state

```bash
kaptain list secrets
```

Output:

```
Listing secrets in src/secrets:

Raw files:
  Stale, should remove:
    src/secrets/db-password.raw
    src/secrets/database/hostname.raw
    src/secrets/database/port.raw

Summary: 3 stale raw, 3 age
```

The `.age` files now exist and are newer than the `.raw` files, so the raw
files show as stale. The encrypted files are counted in the summary. At this
point the `.raw` files can be cleaned up (step 9) or kept for reference.


### 5. Decrypt the encrypted files

```bash
kaptain decrypt
```

The router auto-detects the `.age` files and prompts for your key:

```
Auto-detected type: age
Enter passphrase: <paste your AGE-SECRET-KEY here>
Found 3 .age file(s) to decrypt

Decrypting src/secrets/{db-password.age => db-password.txt}
Decrypting src/secrets/database/{hostname.age => hostname.txt}
Decrypting src/secrets/database/{port.age => port.txt}

Done. Decrypted 3 file(s)
```

The decrypted `.txt` files contain the same content as the original `.raw`
files. These are the files your application or deployment scripts read from.


### 6. List again - see the decrypted state

```bash
kaptain list secrets
```

Output:

```
Listing secrets in src/secrets:

Raw files:
  Stale, should remove:
    src/secrets/db-password.raw
    src/secrets/database/hostname.raw
    src/secrets/database/port.raw

Decrypted files:
  Exposed current:
    src/secrets/db-password.txt
    src/secrets/database/hostname.txt
    src/secrets/database/port.txt

Summary: 3 stale raw, 3 exposed, 3 age
```

Now all three file types are visible: stale `.raw` files, current `.txt`
files (exposed means decrypted and newer than the encrypted version), and
the `.age` encrypted files counted in the summary.


### 7. Modify a raw file and list again

Simulate changing a secret value:

```bash
echo "newPassword456" > src/secrets/db-password.raw
```

```bash
kaptain list secrets
```

Output:

```
Listing secrets in src/secrets:

Raw files:
  Pending encryption:
    src/secrets/db-password.raw
  Stale, should remove:
    src/secrets/database/hostname.raw
    src/secrets/database/port.raw

Decrypted files:
  Exposed current:
    src/secrets/db-password.txt
    src/secrets/database/hostname.txt
    src/secrets/database/port.txt

Summary: 1 pending encryption, 2 stale raw, 3 exposed, 3 age
```

The modified `.raw` file is now newer than its `.age` counterpart, so it shows
as pending encryption. The other two `.raw` files are still stale. Run 
`kaptain encrypt` again to re-encrypt with the new value if you want to keep it
or accept that it'll be lost on the next clean. It was added to demo the output.


### 8. Dry run clean - review what would be deleted

Before actually deleting anything, preview with `--dry-run`:

```bash
kaptain clean secrets --dry-run
```

Output:

```
Found 3 .raw file(s) and 3 .txt file(s)

Dry run - would delete:
  src/secrets/db-password.raw
  src/secrets/database/hostname.raw
  src/secrets/database/port.raw
  src/secrets/db-password.txt
  src/secrets/database/hostname.txt
  src/secrets/database/port.txt
```

Review the list. If something looks wrong, stop here.


### 9. Clean up decrypted files

Remove all `.raw` and `.txt` files, leaving only the encrypted `.age` files:

```bash
kaptain clean secrets
```

Output:

```
Found 3 .raw file(s) and 3 .txt file(s)

Deleting src/secrets/db-password.raw
Deleting src/secrets/database/hostname.raw
Deleting src/secrets/database/port.raw
Deleting src/secrets/db-password.txt
Deleting src/secrets/database/hostname.txt
Deleting src/secrets/database/port.txt

Deleted 6 file(s)
```


### 10. List one final time

```bash
kaptain list secrets
```

Output:

```
Listing secrets in src/secrets:
No raw or decrypted files found

Summary: 3 age
```

Only the encrypted `.age` files remain. These are safe to commit to git.


## Tips

- Use `--dir` on any command to target a different secrets directory
- Use `--dry-run` with `kaptain clean secrets` to preview before deleting
- Use `kaptain list secrets --all` to scan all projects in a branchout tree
- The encryption type is auto-detected from existing files, use `--type` to override
- Never commit `.raw` or `.txt` files - set up gitignore patterns and
  `kaptain encryption-check-ignores` will verify they are in place
