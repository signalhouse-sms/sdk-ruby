# frozen_string_literal: true

# Request-contract coverage for the rcs.agents namespace and the registration draft methods.
# Run from sdks/ruby: ruby -Ilib test/rcs_test.rb
require "cgi"
require "json"
require "uri"
require "stringio"
require "securerandom"
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/rcs"
require "signalhouse_sms/domains/registrations"

# Capture serialized requests without sending them; mirrors HttpClient's query and validation rules.
class RcsSpyClient
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

def query_of(path)
  URI.decode_www_form(URI.parse(path).query || "").to_h
end

def path_of(path)
  URI.parse(path).path
end

def raises?(error_class)
  yield
  false
rescue error_class => e
  e
end

agent_id = "RCSA7K2M1QZ8RP"
client = RcsSpyClient.new
multipart = RcsSpyClient.new
rcs = SignalHouseSms::Rcs.new(client, multipart)
agents = rcs.agents
check(agents.is_a?(SignalHouseSms::RcsAgents), "rcs exposes agents")

agents.create(brand_id: "BXYZ123", campaign_id: "CABC123", agent: { name: "Acme" }, use_case: "TRANSACTIONAL",
              idempotency_key: "k1")
path, options = client.calls.last
check(path == "/rcs/agent" && options[:method] == :post, "create path")
check(options[:headers] == { "Idempotency-Key" => "k1" }, "create idempotency")
check(options[:body] == { brandId: "BXYZ123", agent: { name: "Acme" }, campaignId: "CABC123", useCase: "TRANSACTIONAL" },
      "create body")
agents.create(brand_id: "BXYZ123")
check(client.calls.last[1][:body] == { brandId: "BXYZ123" }, "create omits unset optionals")
error = raises?(SignalHouseSms::ValidationError) { agents.create(brand_id: nil, agent: { name: "Acme" }) }
check(error && error.message.include?("brandId"), "create requires brandId")

agents.list(brand_id: "BXYZ123", campaign_id: "CABC123", status: "DRAFT", page: 2, limit: 50)
path, options = client.calls.last
check(path_of(path) == "/rcs/agent" && options[:method] == :get, "list path")
check(query_of(path) == { "brandId" => "BXYZ123", "campaignId" => "CABC123", "status" => "DRAFT", "page" => "2",
                          "limit" => "50" }, "list query")
agents.list(status: %w[DRAFT REJECTED])
check(query_of(client.calls.last[0]) == { "status" => "DRAFT,REJECTED" }, "list status array")

calls_before = client.calls.size
agents.get(agent_id: agent_id)
agents.update(agent_id: agent_id, campaign_id: nil, agent: { description: "Alerts" }, contact: { firstName: "Ada" })
agents.validate(agent_id: agent_id)
agents.submit(agent_id: agent_id)
agents.launch(agent_id: agent_id)
agents.archive(agent_id: agent_id)
agents.resend_tester_invite(agent_id: agent_id, phone_number: "+15125550199")
sent = client.calls.drop(calls_before)
check(sent.map { |p, o| [o[:method], p] } == [
  [:get, "/rcs/agent/#{agent_id}"], [:put, "/rcs/agent/#{agent_id}"], [:post, "/rcs/agent/#{agent_id}/validate"],
  [:post, "/rcs/agent/#{agent_id}/submit"], [:post, "/registration/#{agent_id}/launch"], [:post, "/rcs/agent/#{agent_id}/archive"],
  [:post, "/rcs/agent/#{agent_id}/testers/%2B15125550199/resend"]
], "agent paths")
check(sent[1][1][:body] == { agent: { description: "Alerts" }, contact: { firstName: "Ada" }, campaignId: nil }, "update sends only given fields, null unlinks")
check(sent[0][1][:body].nil? && sent[5][1][:body].nil?, "get and archive send no body")
agents.get(agent_id: "A/1")
check(client.calls.last[0] == "/rcs/agent/A%2F1", "get escapes id")
error = raises?(SignalHouseSms::ValidationError) { agents.submit(agent_id: nil) }
check(error && error.message.include?("agentId"), "submit requires agentId")
check(raises?(SignalHouseSms::ValidationError) { agents.launch(agent_id: nil) }, "launch requires agentId")

io = StringIO.new("\x89PNG".b)
calls_before = client.calls.size
agents.upload_asset(agent_id: agent_id, kind: "logo", file: io, file_name: "logo.png")
path, options = multipart.calls.last
check(client.calls.size == calls_before, "upload uses the multipart client")
check(path == "/rcs/agent/#{agent_id}/asset" && options[:method] == :post, "upload path")
check(options[:body] == { "kind" => "logo", "file" => { filename: "logo.png", io: io } }, "upload fields")
wire = SignalHouseSms::HttpClient.new(base_url: "https://example.invalid", api_key: "k", multipart: true)
encoded = wire.send(:build_multipart_body, options[:body], "B")
check(encoded.include?("name=\"kind\"\r\n\r\nlogo\r\n") && encoded.include?("name=\"file\"; filename=\"logo.png\""),
      "multipart body carries kind and file parts")
[
  -> { agents.upload_asset(agent_id: nil, kind: "logo", file: io) },
  -> { agents.upload_asset(agent_id: agent_id, kind: nil, file: io) },
  -> { agents.upload_asset(agent_id: agent_id, kind: "hero", file: nil) }
].each_with_index { |call, index| check(raises?(SignalHouseSms::ValidationError, &call), "upload required parameter #{index}") }

registrations = SignalHouseSms::Registrations.new(client, false)
calls_before = client.calls.size
registrations.update_registration(registration_id: agent_id, data: { useCase: "OTP" })
registrations.validate_registration(registration_id: agent_id)
registrations.submit_registration(registration_id: agent_id)
registrations.launch_registration(registration_id: agent_id)
registrations.get_registrations(type: "RCS_AGENT", brand_id: "BXYZ123", campaign_id: "CABC123")
sent = client.calls.drop(calls_before)
check(sent.first(4).map { |p, o| [o[:method], p] } == [
  [:put, "/registration/#{agent_id}"], [:post, "/registration/#{agent_id}/validate"],
  [:post, "/registration/#{agent_id}/submit"], [:post, "/registration/#{agent_id}/launch"]
], "registration draft paths")
check(sent[0][1][:body] == { useCase: "OTP" }, "update_registration sends data as the body")
check(query_of(sent[4][0]) == { "type" => "RCS_AGENT", "brandId" => "BXYZ123", "campaignId" => "CABC123" },
      "registrations link filters")
error = raises?(SignalHouseSms::ValidationError) { registrations.update_registration(registration_id: agent_id, data: nil) }
check(error && error.message.include?("data"), "update_registration requires data")

puts "RCS Ruby contracts passed (agents CRUD and lifecycle, multipart asset upload, registration drafts and filters)"
