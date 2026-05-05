# Maintainer note: source distribution is OUT OF SCOPE for this formula.
# Do not add a `url` to source, a `head` block, or a `resource` block that
# fetches source. Releases are binary-only; the `mirrorpath/latch` repo is
# private. See README.md in this tap for the full distribution policy.

require_relative "../custom_download_strategy"

class Latch < Formula
  desc "Track work, decisions, and dependencies across AI agents"
  homepage "https://github.com/mirrorpath/latch"
  license "LicenseRef-Proprietary"
  version "v0.1.0-preview.3"

  depends_on "minisign"

  on_macos do
    on_arm do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-aarch64-apple-darwin.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "d4d57017bf119da72d393125962e1817c848cd18fce0a13cacf749e6e14684d5"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-x86_64-apple-darwin.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "40e8f8fa04d10f9dff4de11c28699d7c26ea2242bf13c3806b42bed38bc1a04a"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-aarch64-unknown-linux-gnu.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "42edcf062be517b447c84654f0dfde55ff69c3802d654edc44a87a65ac8519af"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-x86_64-unknown-linux-gnu.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "2ad8e0ba7775c9580af92b67dab3226a1ca3fddc371917b5ecaa96a7c53b04c2"
    end
  end

  # checksums.txt and its minisig are fetched as resources rather than via
  # curl in `def install` because Homebrew's superenv strips HOMEBREW_*
  # env vars (including HOMEBREW_GITHUB_API_TOKEN) before def install runs,
  # so curl-with-Authorization-header would fail. Resources are downloaded
  # by brew's main process where the env var is still available, via the
  # same custom strategy as the binary.
  resource "checksums" do
    url "https://github.com/mirrorpath/latch/releases/download/#{version}/checksums.txt",
        using: GitHubPrivateRepositoryReleaseDownloadStrategy
    sha256 "315165a7357e9151ecc21bd141a3b2454c57ad6692f2f87bfd5169d15dbab452"
  end

  resource "checksums-sig" do
    url "https://github.com/mirrorpath/latch/releases/download/#{version}/checksums.txt.minisig",
        using: GitHubPrivateRepositoryReleaseDownloadStrategy
    sha256 "cc2df36ff61d861fd5a9bc5b67bd088627e1cde4b896f8d363d47a6a0baeb906"
  end

  def install
    # Stage the resources next to the binary so minisign can verify them.
    resource("checksums").stage(buildpath)
    resource("checksums-sig").stage(buildpath)

    # Verify checksums.txt against the bundled minisign public key.
    # This is the same trust check scripts/install-latch.sh runs.
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
    # The custom download strategy already extracted it via brew's standard
    # path before def install ran, so the binary is in the current directory.
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
