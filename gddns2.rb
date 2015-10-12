#!/usr/bin/env ruby

require "net/http"
require "yaml"
require "json"
require "singleton"
require "logger"
require "open-uri"

CONFIG_FILE = "config.yaml"
LOG_FILE = "gddns2.log"

def get_global_ip
  open("http://ipinfo.io/ip").read.strip
end

class Logger
  alias_method :add_old, :add
  remove_method :add, :log

  def method_missing(method_name, *args, &block)
    if /^log|add$/ === method_name
      puts "#{(args[1] && args[1] + ": ") || ""}#{args[2]}"
      self.send(:add_old, *args, &block)
    end
  end
end

class GehirnDNS
  include Singleton

  private
  def base_uri
    URI.parse(base)
  end

  def http
    http = Net::HTTP.new(base_uri.host, base_uri.port)
    http.use_ssl = true
    http
  end

  def request(req)
    req.basic_auth(token, secret)
    response = http.request(req)

    if (code = response.code.to_i) != 200
      begin
        error = "Failed to request. got #{code} description: #{JSON.parse(response.body)["message"]}"
      rescue
        error = "Failed to request, got #{code}. couldn't access to server."
      end

      raise error
    end

    response.body
  end

  public
  def get(endpoint)
    request = Net::HTTP::Get.new(base_uri.path + endpoint)
    response = request(request)
    JSON.parse(response)
  end

  def post(endpoint, data)
    request = Net::HTTP::Post.new(base_uri.path + endpoint)
    request.body = data
    response = request(request)
    JSON.parse(response)
  end

  def put(endpoint, data)
    request = Net::HTTP::Put.new(base_uri.path + endpoint)
    request.body = data
    response = request(request)
    JSON.parse(response)
  end

  attr_accessor :base, :token, :secret
  attr_accessor :logger
end

logger = Logger.new(LOG_FILE)

config = YAML.parse_file(CONFIG_FILE).to_ruby

gehirn_dns = GehirnDNS.instance
gehirn_dns.base = config["api"]["base"]
gehirn_dns.token = config["api"]["token"]
gehirn_dns.secret = config["api"]["secret"]
gehirn_dns.logger = logger

# get zones list
begin
  zones = gehirn_dns.get("zones")
rescue => e
  logger.error(e.to_s)
  exit
end

new_ip = \
if ARGV.length == 1
  ARGV[0]
else
  get_global_ip
end

config["zones"].each do |config_zone|
  dns_zone = zones.select{|z| z["name"] == config_zone["name"] }.first
  if dns_zone.nil?
    logger.info("Not found zone: #{config_zone["name"]}")
    next
  end

  zone_id = dns_zone["id"]
  zone_version = dns_zone["current_version_id"]

  begin
    dns_records = gehirn_dns.get("zones/#{zone_id}/versions/#{zone_version}/records")
  rescue => e
    logger.error(e.to_s)
    next
  end

  config_zone["domains"].each do |domain|
    dns_record = dns_records.select{|r| r["name"] == domain && r["type"] == "A" }.first
    if dns_record.nil?
      logger.info("Not found record: #{domain}, create a record first.")
      next
    end

    dns_record_id = dns_record["id"]

    if dns_record["address"] != new_ip
      new_record = dns_record.dup
      new_record["address"] = new_ip

      begin
        gehirn_dns.put("zones/#{zone_id}/versions/#{zone_version}/records/#{dns_record_id}", new_record.to_json)

        log_detail = "Updated: %s in %s from %s to %s"
        logger.info(log_detail % [domain, dns_zone["name"], dns_record["address"], new_ip])
      rescue => e
        logger.error(e.to_s)
      end
    end
  end
end
