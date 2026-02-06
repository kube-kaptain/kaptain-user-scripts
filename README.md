# Kaptain User Scripts

A set of scripts for user of the Kaptain build and deploy system for Kubernetes.


## What's in the box

Currently just encrypt/decrypt scripts for various types of encryption:

| Script                               | Description                                                |
|--------------------------------------|------------------------------------------------------------|
| `decrypt-secrets-age`                | Decrypt secrets using age                                  |
| `decrypt-secrets-sha256.aes256`      | Decrypt secrets using OpenSSL AES-256 (default iterations) |
| `decrypt-secrets-sha256.aes256.100k` | Decrypt secrets using OpenSSL AES-256 (100k iterations)    |
| `decrypt-secrets-sha256.aes256.10k`  | Decrypt secrets using OpenSSL AES-256 (10k iterations)     |
| `decrypt-secrets-sha256.aes256.600k` | Decrypt secrets using OpenSSL AES-256 (600k iterations)    |
| `encrypt-secrets-age`                | Encrypt secrets using age                                  |
| `encrypt-secrets-sha256.aes256`      | Encrypt secrets using OpenSSL AES-256 (default iterations) |
| `encrypt-secrets-sha256.aes256.100k` | Encrypt secrets using OpenSSL AES-256 (100k iterations)    |
| `encrypt-secrets-sha256.aes256.10k`  | Encrypt secrets using OpenSSL AES-256 (10k iterations)     |
| `encrypt-secrets-sha256.aes256.600k` | Encrypt secrets using OpenSSL AES-256 (600k iterations)    |

Note they all ask for a passphrase, but the usage is slightly different:

1. `age` must use a key style with prefix `AGE-SECRET-KEY-`
2. all others use `openssl` and any key is fine - but 40+ random hex chars recommended

Note, they all encrypt from `.raw` to their respective suffix and decrypt from their suffix to `.txt`.

Note, right now these target src/secrets hard coded - in future
they'll use KaptainPM.yaml to read the correct directory from.


## Usage

Right now you have two choices:

1. Clone and add `src/scripts` to your path
2. Brew install via [homebrew-kaptain-user-scripts](https://github.com/kube-kaptain/homebrew-kaptain-user-scripts)


## Future Packaging

I'd like to provide other options for installation:

1. `.deb` for Debian, Ubuntu and other derivative distros
2. `.rpm` for Fedora and other Red Hat based distros
3. Maybe other ways?
