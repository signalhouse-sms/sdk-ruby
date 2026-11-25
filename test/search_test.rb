# frozen_string_literal: true

# Request-contract coverage for the repeated search param on the subgroup, brand, campaign and phone number lists.
# Run from sdks/ruby: ruby -Ilib test/search_test.rb
require "cgi"
require "uri"
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/subgroups"
require "signalhouse_sms/domains/brands"
require "signalhouse_sms/domains/campaigns"
require "signalhouse_sms/domains/numbers"

# Capture serialized requests without sending them; serializes queries with HttpClient itself.
class SearchSpyClient
  attr_reader :calls

  def initialize
    @calls = []
  end

  def get_query_string(params)
    SignalHouseSms::HttpClient.new(base_url: "https://example.invalid", api_key: "k").get_query_string(params)
  end

  def require_params(fields)
    fields.each { |name, value| raise SignalHouseSms::ValidationError.new(name.to_s) if value.nil? }
  end

  def request(path, **options)
    @calls << [path, options]
    { success: true }
  end
end

def check(condition, message)
  raise message unless condition
end

def pairs_of(path)
  URI.decode_www_form(URI.parse(path).query || "")
end

client = SearchSpyClient.new
lists = {
  "/subgroup" => ->(**args) { SignalHouseSms::Subgroups.new(client, false).get_subgroups(**args) },
  "/brand" => ->(**args) { SignalHouseSms::Brands.new(client, client, false).get_brands(**args) },
  "/campaign" => ->(**args) { SignalHouseSms::Campaigns.new(client, client, false).get_campaigns(**args) },
  "/number" => ->(**args) { SignalHouseSms::Numbers.new(client, client, false).get_phone_numbers(**args) }
}
search = ["Acme, Inc", "displayName:dental"]

lists.each do |expected_path, list|
  list.call(group_id: "G1", search: search)
  path, = client.calls.last
  check(URI.parse(path).path == expected_path, "#{expected_path} path")
  check(pairs_of(path) == [["groupId", "G1"], ["search", "Acme, Inc"], ["search", "displayName:dental"]],
        "#{expected_path} sends one search key per value: #{path}")

  list.call(group_id: "G1", search: "apex")
  path, = client.calls.last
  check(pairs_of(path) == [["groupId", "G1"], ["search", "apex"]], "#{expected_path} sends a String as one key: #{path}")

  list.call(group_id: "G1", page: 2)
  path, = client.calls.last
  check(path == "#{expected_path}?groupId=G1&page=2", "#{expected_path} without search is unchanged: #{path}")
end

wire = SignalHouseSms::HttpClient.new(base_url: "https://example.invalid", api_key: "k")
qs = wire.get_query_string(region: %w[US GB], search: SignalHouseSms::HttpClient.repeated(%w[apex dental]))
check(qs == "?region=US,GB&search=apex&search=dental", "other arrays stay comma-joined: #{qs}")
check(wire.get_query_string(search: SignalHouseSms::HttpClient.repeated(nil), page: 1) == "?page=1", "nil search is left out")
check(wire.get_query_string(search: SignalHouseSms::HttpClient.repeated([]), page: 1) == "?page=1", "empty search is left out")

puts "Search Ruby contracts passed (get_subgroups, get_brands, get_campaigns, get_phone_numbers, repeated query values)"
