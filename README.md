# Kaptain User Scripts

A set of scripts for users of the Kaptain build and deploy system for Kubernetes.

The kaptain CLI system provides the functionality needed to operate kaptain
based projects on a daily basis. All the tasks you need to do can be done by
manual means, but these scripts make it easy to do the same things faster and
more repeatably with less hassle.

For a hands-on guide to the full secrets workflow, see the
[Encryption Walkthrough](EncryptionWalkthrough.md).


## Script Usage - Routing Behaviour

The kaptain CLI works by scanning the path it is run from to find siblings with
the kaptain- prefix. It treats the first thing after the first hyphen as a sub
command and calls that if the first argument to it matches one of them. For
example the following two lines do the same thing:

```
kaptain list secrets  # natural cli verb noun style - calls 3 scripts to work
kaptain-list-secrets  # direct style - calls the end script directly
```

What you use is up to you, however kaptain list secrets has tab completion
available if installed via brew or manually installed with the scripts on your
path.


## What's in the box

Currently CLI, routing, utility and encryption scripts useful to kaptain users.

### CLI

| Script         | Description                                   |
|----------------|-----------------------------------------------|
| `kaptain`      | Main CLI entrypoint, routes to sub-commands   |
| `kaptain-help` | Show help with available commands and scripts |

### Routers

| Script            | Description                                        |
|-------------------|----------------------------------------------------|
| `kaptain-list`    | Route to list sub-commands (config, secrets, etc.) |
| `kaptain-clean`   | Route to clean sub-commands (secrets, etc.)        |
| `kaptain-encrypt` | Auto-detect encryption type and encrypt            |
| `kaptain-decrypt` | Auto-detect encryption type and decrypt            |

### Utility

| Script                  | Description                                   |
|-------------------------|-----------------------------------------------|
| `kaptain-list-config`   | List config files and their values            |
| `kaptain-list-secrets`  | List secret files and their encryption status |
| `kaptain-clean-secrets` | Remove decrypted secret files (.raw, .txt)    |

### Encryption

For a step-by-step guide covering keygen, encrypt, decrypt, list and clean,
see the [Encryption Walkthrough](EncryptionWalkthrough.md).

| Script                               | Description                                                |
|--------------------------------------|------------------------------------------------------------|
| `kaptain-keygen`                     | Generate encryption keys                                   |
| `kaptain-decrypt-age`                | Decrypt secrets using age                                  |
| `kaptain-decrypt-sha256.aes256`      | Decrypt secrets using OpenSSL AES-256 (default iterations) |
| `kaptain-decrypt-sha256.aes256.100k` | Decrypt secrets using OpenSSL AES-256 (100k iterations)    |
| `kaptain-decrypt-sha256.aes256.10k`  | Decrypt secrets using OpenSSL AES-256 (10k iterations)     |
| `kaptain-decrypt-sha256.aes256.600k` | Decrypt secrets using OpenSSL AES-256 (600k iterations)    |
| `kaptain-encrypt-age`                | Encrypt secrets using age                                  |
| `kaptain-encrypt-sha256.aes256`      | Encrypt secrets using OpenSSL AES-256 (default iterations) |
| `kaptain-encrypt-sha256.aes256.100k` | Encrypt secrets using OpenSSL AES-256 (100k iterations)    |
| `kaptain-encrypt-sha256.aes256.10k`  | Encrypt secrets using OpenSSL AES-256 (10k iterations)     |
| `kaptain-encrypt-sha256.aes256.600k` | Encrypt secrets using OpenSSL AES-256 (600k iterations)    |
| `kaptain-encryption-check-ignores`   | Check gitignore covers secret files                        |

Note that the encrypt/decrypt scripts all ask for a passphrase, but the usage is slightly different:

1. `age` must use a private key style with prefix `AGE-SECRET-KEY-` - generate with `kaptain keygen`
2. all others use `openssl` and any key is fine - but 40+ random hex chars recommended

They all encrypt from `.raw` to their respective suffix and decrypt from their suffix to `.txt`.

Note, right now the encryption scripts target src/secrets by default with a --dir
override option. In future they'll use KaptainPM.yaml or its fully resolved
cousin to read the correct directory from and init the project if needed if no
`src/secrets` dir exists.


## Installation

Right now you have two choices:

1. Download the [latest release](https://github.com/kube-kaptain/kaptain-user-scripts/releases) `kaptain-user-scripts-<version>.zip`, extract and add to your path
2. Brew install via [homebrew-kaptain](https://github.com/kube-kaptain/homebrew-kaptain)

Brew instructions are repeated below from [the above repo docs](https://github.com/kube-kaptain/homebrew-kaptain?tab=readme-ov-file#installation):

```bash
brew tap kube-kaptain/kaptain
brew install kaptain
```

## Future Packaging

I'd like to provide other options for installation:

1. `.deb` for Debian, Ubuntu and other derivative distros
2. `.rpm` for Fedora and other Red Hat based distros
3. Maybe other ways?
