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
  version "v0.1.0-preview.1"

  depends_on "minisign"

  on_macos do
    on_arm do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  # Resource URLs hardcode the version because `#{version}` inside a
  # resource block refers to the *resource's* own version (nil by default),
  # not the formula's. Auto-PR bumps these on each release.
  resource "checksums" do
    url "https://github.com/mirrorpath/latch-public-release/releases/download/v0.1.0-preview.1/checksums.txt"
    sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  end

  resource "checksums-sig" do
    url "https://github.com/mirrorpath/latch-public-release/releases/download/v0.1.0-preview.1/checksums.txt.minisig"
    sha256 "0000000000000000000000000000000000000000000000000000000000000000"
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
