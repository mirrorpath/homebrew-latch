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
      sha256 "cb34252d5d57c8424038fc657fe58c87f063c855e7fa0c3b17f6bc6c2bda40f3"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "6ecd50ee9d2c3af4b7c7ad3036b16e36c044a81217babbcfe540f880aa987ae6"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "8995621eb7aaacbf5975a0f92d9829b3e434acf4a9e72777feda9fdf831e97ee"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch-public-release/releases/download/#{version}/latch-#{version}-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "d8026c37fa11d12253d8162ae72a773ab7e8bbcb54159d62d3797c3f774422f6"
    end
  end

  # Resource URLs hardcode the version because `#{version}` inside a
  # resource block refers to the *resource's* own version (nil by default),
  # not the formula's. Auto-PR bumps these on each release.
  resource "checksums" do
    url "https://github.com/mirrorpath/latch-public-release/releases/download/v0.1.0-preview.1/checksums.txt"
    sha256 "43784b04d2e13ea0e4fea4a909631556604bb0798415e09bc9af7dc4d7a3dcff"
  end

  resource "checksums-sig" do
    url "https://github.com/mirrorpath/latch-public-release/releases/download/v0.1.0-preview.1/checksums.txt.minisig"
    sha256 "5a6b04d573b85b16237fdc20a535a4c8bf1b8d515ded277c0a83e8424dd3e68a"
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
