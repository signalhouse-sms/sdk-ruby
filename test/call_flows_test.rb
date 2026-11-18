# frozen_string_literal: true

# Request-contract coverage for the voice call flows namespace.
# Run from sdks/ruby: ruby -Ilib test/call_flows_test.rb
require "cgi"
require "json"
require "uri"
require "stringio"
require "securerandom"
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/voice/call_flows"

# Capture serialized requests without sending them; mirrors HttpClient's query and validation rules.
class CallFlowSpyClient
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

def raises?(error_class)
  yield
  false
rescue error_class
  true
end

id = "0088947b-7821-4853-bfe6-744fce926de2"
base = "/voice/api/v1/call-flows"

client = CallFlowSpyClient.new
flows = SignalHouseSms::VoiceCallFlows.new(client, false)

flows.list
flows.list(filters: { page: 2, subgroupId: "S0000001", includeDeleted: true, q: nil })
flows.catalog
flows.get(id: id)
flows.create(flow_data: { name: "Main line", subgroupId: "S0000001" })
flows.update(id: id, update_data: { status: "DISABLED" })
flows.save_draft(id: id, draft: { nodes: [], edges: [] })
flows.publish(id: id)
flows.restore(id: id)
flows.duplicate(id: id)
flows.duplicate(id: id, name: "Weekend")
flows.delete(id: id, token: "t", idempotency_key: "k1")

list, filtered, catalog, get, create, update, draft, publish, restore, dup_default, dup_named, delete = client.calls

check(list[0] == base && list[1][:method] == :get, "list path")
check(filtered[0] == "#{base}?page=2&subgroupId=S0000001&includeDeleted=true", "list sends set filters: #{filtered[0]}")
check(catalog[0] == "#{base}/catalog" && catalog[1][:method] == :get, "catalog path")
check(get[0] == "#{base}/#{id}" && get[1][:method] == :get, "get")
check(create[0] == base && create[1][:method] == :post && create[1][:body] == { name: "Main line", subgroupId: "S0000001" }, "create body")
check(update[0] == "#{base}/#{id}" && update[1][:method] == :patch && update[1][:body] == { status: "DISABLED" }, "update patches")
check(draft[0] == "#{base}/#{id}/draft" && draft[1][:method] == :put && draft[1][:body] == { nodes: [], edges: [] }, "save_draft puts")

# The client always declares JSON and the Voice service rejects a JSON request with no body.
check(publish[0] == "#{base}/#{id}/publish" && publish[1][:method] == :post && JSON.generate(publish[1][:body]) == "{}", "publish sends {}")
check(restore[0] == "#{base}/#{id}/restore" && restore[1][:method] == :post && JSON.generate(restore[1][:body]) == "{}", "restore sends {}")
check(dup_default[0] == "#{base}/#{id}/duplicate" && JSON.generate(dup_default[1][:body]) == "{}", "duplicate without a name sends {}")
check(dup_named[1][:body] == { "name" => "Weekend" }, "duplicate sends the name")
check(delete[0] == "#{base}/#{id}" && delete[1][:method] == :delete, "delete")
check(delete[1][:token] == "t" && delete[1][:headers] == { "Idempotency-Key" => "k1" }, "per-call token and idempotency key pass through")

check(raises?(SignalHouseSms::ValidationError) { flows.get(id: nil) }, "get requires an id")
check(raises?(SignalHouseSms::ValidationError) { flows.save_draft(id: id, draft: nil) }, "save_draft requires a draft")

encoded = CallFlowSpyClient.new
SignalHouseSms::VoiceCallFlows.new(encoded, false).get(id: "a/b")
check(encoded.calls[0][0] == "#{base}/a%2Fb", "ids are URL-encoded")

puts "call_flows: ok"
