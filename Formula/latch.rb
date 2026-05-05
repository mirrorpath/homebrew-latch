# Maintainer note: source distribution is OUT OF SCOPE for this formula.
# Do not add a `url` to source, a `head` block, or a `resource` block that
# fetches source. Releases are binary-only; the `mirrorpath/latch` repo is
# private. See README.md in this tap for the full distribution policy.

require_relative "../custom_download_strategy"

class Latch < Formula
  desc "Track work, decisions, and dependencies across AI agents"
  homepage "https://github.com/mirrorpath/latch"
  license "LicenseRef-Proprietary"
  version "v0.1.0-preview.5"

  depends_on "minisign"

  on_macos do
    on_arm do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-aarch64-apple-darwin.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "a03374d91509fd69c6a2490666529d01492fc12ec9f8555badbbae9b64f29dcf"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-x86_64-apple-darwin.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "028d99a45fd5c6c7589268a845a871f9513ca04e673b5684541bb9571c3bc117"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-aarch64-unknown-linux-gnu.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "331c8871c05f2cad6383aed135cfe0ae6499dac06725e84cf8d47032851173e7"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-x86_64-unknown-linux-gnu.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "af17da5a38f3a3617c7fe02743015c39001f0bc5345732be200e00c4e894e616"
    end
  end

  # checksums.txt and its minisig are fetched as resources rather than via
  # curl in `def install` because Homebrew's superenv strips HOMEBREW_*
  # env vars (including HOMEBREW_GITHUB_API_TOKEN) before def install runs,
  # so curl-with-Authorization-header would fail. Resources are downloaded
  # by brew's main process where the env var is still available, via the
  # same custom strategy as the binary.
  # Resource URLs hardcode the version because `#{version}` inside a
  # resource block refers to the *resource's* own version (nil by default),
  # not the formula's. Auto-PR bumps these on each release.
  resource "checksums" do
    url "https://github.com/mirrorpath/latch/releases/download/v0.1.0-preview.5/checksums.txt",
        using: GitHubPrivateRepositoryReleaseDownloadStrategy
    sha256 "a7bdc89c8c0c9c20e8a0cf1cf75ea1ce0f4de9e87355d7038c8cda70af158f33"
  end

  resource "checksums-sig" do
    url "https://github.com/mirrorpath/latch/releases/download/v0.1.0-preview.5/checksums.txt.minisig",
        using: GitHubPrivateRepositoryReleaseDownloadStrategy
    sha256 "61efad16948d8d6097dcdcd58bc7385665c011b4368e2550c492a9379c8ccd33"
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
