# Maintainer note: source distribution is OUT OF SCOPE for this formula.
# Do not add a `url` to source, a `head` block, or a `resource` block that
# fetches source. Releases are binary-only; the `mirrorpath/latch` source
# repo is private. The release artifacts this formula references are
# hosted at mirrorpath/latch-public-release (a public repo with no
# source).

class Latch < Formula
  desc "Track work, decisions, and dependencies across AI agents"
  homepage "https://github.com/mirrorpath/latch"
  license "LicenseRef-Proprietary"
  version "v0.1.0-preview.2"

  depends_on "minisign"

  on_macos do
    on_arm do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "4becc6c5f09875461accbdaa1ba28139b6ed4d7e9d76b5da96f7c6b52274dd1f"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "27c287de48749f2e24a33ad257a65f5dde35f0cfa38a6d27a5ba2af2c3195493"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "ddadb01a5b7e33eb98bb5ab320bf85af4d46d4d3685335088083eea8a9c83da8"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "ca729d6e3378f5d0d73bb9dc2a55cc1d458fe04ce6f09145d152b50c16307ccf"
    end
  end

  # Resource URLs hardcode the version because `#{version}` inside a
  # resource block refers to the *resource's* own version (nil by default),
  # not the formula's. Auto-PR bumps these on each release.
  resource "checksums" do
    url "https://github.com/mirrorpath/latch-public-release/releases/download/v0.1.0-preview.2/checksums.txt"
    sha256 "fd337ebff76f90024fa4edd589019585ac8d437a1aea2d4cca435cc74079c6d9"
  end

  resource "checksums-sig" do
    url "https://github.com/mirrorpath/latch-public-release/releases/download/v0.1.0-preview.2/checksums.txt.minisig"
    sha256 "7a0e21d2e6ccedf441e9d480cb301fe1b752c39c6a51d06641b725e12d6608bf"
  end

  def install
    # Stage the resources next to the binary so minisign can verify them.
    resource("checksums").stage(buildpath)
    resource("checksums-sig").stage(buildpath)

    # Verify checksums.txt against the bundled minisign public key.
    # This is the same trust check the manual-install path documents in
    # the mirrorpath/latch-public-release README.
    #
    # Trust chain:
    #   1. Tap maintainer review = trust anchor for this formula's sha256.
    #   2. Brew's standard sha256 check on the downloaded archive enforces
    #      that the binary matches what the formula declares.
    #   3. Minisign-on-checksums verifies the signed manifest came from
    #      the trusted release-signing key. Brew already enforces (2),
    #      so (3) is defence-in-depth — but it's the documented user-side
    #      verification step from the binary-release-channel design.
    pubkey = (path.dirname/"latch-minisign.pub").to_s
    system "minisign", "-Vm", "checksums.txt",
           "-p", pubkey,
           "-x", "checksums.txt.minisig"

    # The unpacked archive layout is latch-<version>-<target>/latch.
    # Brew's default extraction puts us inside that directory before
    # def install runs.
    bin.install "latch"
  end

  def caveats
    <<~EOS
      latch is binary-only and verified at install time against the bundled
      minisign public key (#{path.dirname}/latch-minisign.pub).

      To re-verify the installed binary against the release manifest:
        cd $(brew --cache --formula latch)
        minisign -Vm checksums.txt \\
          -p #{path.dirname}/latch-minisign.pub \\
          -x checksums.txt.minisig

      Source code is not distributed via this tap.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/latch --version")
  end
end
