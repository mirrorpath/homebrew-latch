# Maintainer note: source distribution is OUT OF SCOPE for this formula.
# Do not add a `url` to source, a `head` block, or a `resource` block that
# fetches source. Releases are binary-only; the `mirrorpath/latch` repo is
# private. See README.md in this tap for the full distribution policy.

require_relative "../custom_download_strategy"

class Latch < Formula
  desc "Track work, decisions, and dependencies across AI agents"
  homepage "https://github.com/mirrorpath/latch"
  license "LicenseRef-Proprietary"
  version "v0.1.0-preview.1"

  depends_on "minisign"

  on_macos do
    on_arm do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-aarch64-apple-darwin.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-x86_64-apple-darwin.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-aarch64-unknown-linux-gnu.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/mirrorpath/latch/releases/download/#{version}/latch-#{version}-x86_64-unknown-linux-gnu.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  def install
    # Fetch checksums.txt and its minisign signature from the same private
    # release using the same auth as the binary. We shell out to curl rather
    # than declaring these as `resource` blocks because brew's resource model
    # would require us to commit a sha256 for the signature file (which would
    # itself need bumping every release for no trust gain — minisig over
    # checksums is the load-bearing trust check, not sha256-of-minisig).
    token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", nil)
    odie "HOMEBREW_GITHUB_API_TOKEN is required" if token.nil?

    %w[checksums.txt checksums.txt.minisig].each do |asset|
      asset_url = release_asset_url(asset, token: token)
      system "curl",
             "--fail", "--silent", "--show-error", "--location",
             "--header", "Accept: application/octet-stream",
             "--header", "Authorization: Bearer #{token}",
             "--output", asset,
             asset_url
    end

    # Verify checksums.txt against the bundled minisign public key.
    # This is the same trust check scripts/install-latch.sh runs.
    # `path` is the formula file's location; the pubkey lives next to it.
    #
    # Trust chain:
    #   1. Tap maintainer review = trust anchor for this formula's sha256.
    #   2. Brew's standard sha256 check on the downloaded archive enforces
    #      that the binary matches what the formula declares.
    #   3. Minisign-on-checksums verifies the signed manifest came from
    #      the trusted release-signing key. This is defence-in-depth: it
    #      doesn't gate `bin.install` (brew already did that), but it
    #      ensures any later manual verify against `checksums.txt`
    #      (e.g., from `caveats`) is also rooted in the signing key.
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

  private

  def release_asset_url(filename, token:)
    require "json"
    api_url = "https://api.github.com/repos/mirrorpath/latch/releases/tags/#{version}"
    metadata_json = `curl --fail --silent --show-error \
      --header 'Accept: application/vnd.github+json' \
      --header 'Authorization: Bearer #{token}' \
      #{api_url}`
    odie "Failed to fetch release metadata for #{version}" unless $CHILD_STATUS.success?

    metadata = JSON.parse(metadata_json)
    asset = metadata["assets"].find { |a| a["name"] == filename }
    odie "Asset not found in release #{version}: #{filename}" if asset.nil?

    asset["url"]
  end
end
