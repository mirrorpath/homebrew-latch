# GitHubPrivateRepositoryReleaseDownloadStrategy
#
# Vendored from the deprecated Homebrew built-in (PR Homebrew/brew#5112,
# October 2018). Brew's lead maintainer directed users to copy this into
# their own taps after deprecation. See:
# https://github.com/Homebrew/brew/issues/5573
#
# This class downloads release assets from a private GitHub repository
# using HOMEBREW_GITHUB_API_TOKEN as a bearer token, against the
# api.github.com/repos/.../releases/assets/<id> endpoint with
# Accept: application/octet-stream. Same auth shape as
# scripts/install-latch.sh.
#
# Usage in Formula:
#   require_relative "../custom_download_strategy"
#
#   url "https://github.com/owner/repo/releases/download/<tag>/<file>",
#       using: GitHubPrivateRepositoryReleaseDownloadStrategy
#
# WARNING: Brew's AbstractFileDownloadStrategy is a private API. The
# _fetch signature has changed across brew versions. If a brew upgrade
# breaks this strategy, diff this file against the corresponding
# CurlDownloadStrategy in Library/Homebrew/download_strategy.rb on
# brew master and align the keyword arguments.

require "download_strategy"

class GitHubPrivateRepositoryReleaseDownloadStrategy < CurlDownloadStrategy
  require "utils/formatter"
  require "utils/github"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    url_pattern = %r{https://github.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(\S+)}
    unless @url =~ url_pattern
      raise CurlDownloadStrategyError,
            "Invalid url pattern for GitHub Release; expected " \
            "https://github.com/<owner>/<repo>/releases/download/<tag>/<file>"
    end

    _, @owner, @repo, @tag, @filename = *@url.match(url_pattern)
  end

  def download_url
    "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}"
  end

  private

  def set_github_token
    @github_token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", nil)
    unless @github_token
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the latch tap. " \
            "See https://github.com/mirrorpath/homebrew-latch#required-pat-scopes"
    end

    validate_github_repository_access!
  end

  def validate_github_repository_access!
    GitHub.repository(@owner, @repo)
  rescue GitHub::API::HTTPNotFoundError
    message = <<~EOS
      HOMEBREW_GITHUB_API_TOKEN can not access the repository: #{@owner}/#{@repo}
      This token may not have permission to access the repository or the url of formula may be incorrect.
    EOS
    raise CurlDownloadStrategyError, message
  end

  def _fetch(url:, resolved_url:, timeout:)
    # GitHub's release-asset endpoint returns JSON metadata by default.
    # To get the binary blob we MUST set Accept: application/octet-stream;
    # without it brew downloads the JSON, computes its sha256, compares
    # to the formula's declared sha256 (which is the binary's), and fails
    # with a checksum mismatch. The API responds 302 → signed S3 URL,
    # which curl follows via --location. Token goes in an Authorization
    # header rather than URL user-info: cleaner, doesn't appear in curl's
    # default logs, and survives proxies that strip user-info.
    require "open3"
    args = [
      "--location",
      "--fail",
      "--silent",
      "--show-error",
      "--header", "Accept: application/octet-stream",
      "--header", "Authorization: Bearer #{@github_token}",
    ]
    # Brew may pass timeout as nil; curl rejects --max-time with empty value.
    args += ["--max-time", timeout.to_s] if timeout.is_a?(Numeric) && timeout.positive?
    args += ["--output", temporary_path.to_s, download_url]

    _stdout, stderr, status = Open3.capture3("/usr/bin/curl", *args)
    return if status.success?

    raise CurlDownloadStrategyError, "GitHub asset download failed for #{@filename}: #{stderr}"
  end

  def asset_id
    @asset_id ||= resolve_asset_id
  end

  def resolve_asset_id
    release_metadata = fetch_release_metadata
    assets = release_metadata["assets"].select { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError, "Asset file not found: #{@filename}" if assets.empty?

    assets.first["id"]
  end

  def fetch_release_metadata
    GitHub.get_release(@owner, @repo, @tag)
  end
end
