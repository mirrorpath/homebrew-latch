# homebrew-latch

Homebrew tap for [`latch`](https://github.com/mirrorpath/latch). The formula points at public binary release artifacts hosted at [`mirrorpath/latch-public-release`](https://github.com/mirrorpath/latch-public-release); the trust anchor is a minisign signature over `checksums.txt`, verified at install time inside `def install`.

The latch source repo (`mirrorpath/latch`) remains private. This tap and the binary release host are public — anyone with the tap URL can install latch with no authentication.

## Install

```bash
brew tap mirrorpath/latch
brew install latch
```

That's it. No PAT, no env var, no SSH key. The tap clone and the binary download both go over plain HTTPS.

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

**Formula updates come from CI.** `mirrorpath/latch`'s release workflow opens an auto-PR against this repo on every release, bumping `version`, the four per-arch `sha256`s, the two resource `sha256`s, and the resource URL versions. Hand-edits should be rare; the typical PR-author-of-record is the GitHub Actions bot.

**Auto-merge is disabled.** Every formula bump goes through a manual maintainer-merge step. This is the load-bearing safety mechanism — a botched release should not silently propagate to users.
