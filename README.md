# homebrew-latch

Private Homebrew tap for `latch`. The formula points at public binary release artifacts hosted at [`mirrorpath/latch-public-release`](https://github.com/mirrorpath/latch-public-release); the trust anchor is a minisign signature over `checksums.txt`, verified at install time inside `def install`.

This tap stays private to gate discovery and `brew upgrade`. The source repo `mirrorpath/latch` is also private. Do not make this tap public without re-reviewing the distribution policy in `docs/release/preview-binary-distribution.md` (in the `mirrorpath/latch` repo).

## How users install latch via this tap

```bash
export HOMEBREW_GITHUB_API_TOKEN=<fine-grained PAT, see scopes below>
brew tap mirrorpath/latch git@github.com:mirrorpath/homebrew-latch.git
brew install latch
```

For users who prefer HTTPS to SSH:

```bash
export HOMEBREW_GITHUB_API_TOKEN=<PAT>
brew tap mirrorpath/latch https://github.com/mirrorpath/homebrew-latch.git
brew install latch
```

### Required PAT scopes

`HOMEBREW_GITHUB_API_TOKEN` must be a fine-grained PAT with:

- `mirrorpath/homebrew-latch` → **Contents: Read** (clones this tap)

That's it. The binary download pulls from the public `mirrorpath/latch-public-release` and needs no auth.

Use a dedicated, machine-specific PAT. Do not reuse a personal-development PAT.

## Trust posture

The formula bundles the project's minisign public key (`Formula/latch-minisign.pub`). At install time, `def install` runs:

```
minisign -Vm checksums.txt -p Formula/latch-minisign.pub -x checksums.txt.minisig
```

Install aborts on verification failure. The same minisign check is also documented for manual installs in the `mirrorpath/latch-public-release` README.

### Public key rotation

The minisign public key lives at `Formula/latch-minisign.pub`. To rotate:

1. Generate the new key in the release engineer's environment.
2. Commit the new `Formula/latch-minisign.pub` to this tap.
3. Update the `MINISIGN_PRIVATE_KEY` and `MINISIGN_KEY_PASSWORD` secrets in `mirrorpath/latch`.
4. Users get the new key on next `brew update`.

A rotation that lands between `brew update` and `brew install` will fail-closed (the install verifies against whatever the user's local checkout of the tap holds at install time). Communicate rotation in advance.

## Maintenance notes

**Source distribution is out of scope.** Do not add a `url` to source, a `head` block, or a `resource` block that fetches source. The formula intentionally has no source-build path; releases are binary-only.

**Binaries are hosted publicly at `mirrorpath/latch-public-release`.** This tap stays private to gate discovery and upgrades. The formula points at public release URLs, so the binary download itself needs no auth — only the tap clone does.

**Formula updates come from CI.** `mirrorpath/latch`'s release workflow opens an auto-PR against this repo on every release, bumping `version`, the four per-arch `sha256`s, the two resource `sha256`s, and the resource URL versions. Hand-edits should be rare; the typical PR-author-of-record is the GitHub Actions bot.

**Auto-merge is disabled.** Every formula bump goes through a manual maintainer-merge step. This is the load-bearing safety mechanism — a botched release should not silently propagate to users.
