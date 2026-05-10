# frozen_string_literal: true

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name          = "useful-string-utils"
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
