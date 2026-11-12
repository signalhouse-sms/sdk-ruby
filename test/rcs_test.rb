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
require "signalhouse_sms/domains/messages"
require "signalhouse_sms/domains/rcs"
require "signalhouse_sms/domains/registrations"
require "signalhouse_sms/domains/webhooks"
require "signalhouse_sms/domains/billing"

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
agents.launch(agent_id: agent_id, acknowledge_fees: true)
agents.archive(agent_id: agent_id)
agents.resend_tester_invite(agent_id: agent_id, phone_number: "+15125550199")
agents.remove_tester(agent_id: agent_id, phone_number: "+15125550199")
sent = client.calls.drop(calls_before)
check(sent.map { |p, o| [o[:method], p] } == [
  [:get, "/rcs/agent/#{agent_id}"], [:put, "/rcs/agent/#{agent_id}"], [:post, "/rcs/agent/#{agent_id}/validate"],
  [:post, "/rcs/agent/#{agent_id}/submit"], [:post, "/registration/#{agent_id}/launch"], [:post, "/rcs/agent/#{agent_id}/archive"],
  [:post, "/rcs/agent/#{agent_id}/testers/%2B15125550199/resend"], [:delete, "/rcs/agent/#{agent_id}/testers/%2B15125550199"]
], "agent paths")
check(sent[1][1][:body] == { agent: { description: "Alerts" }, contact: { firstName: "Ada" }, campaignId: nil }, "update sends only given fields, null unlinks")
check(sent[0][1][:body].nil? && sent[5][1][:body].nil?, "get and archive send no body")
agents.get(agent_id: "A/1")
check(client.calls.last[0] == "/rcs/agent/A%2F1", "get escapes id")
error = raises?(SignalHouseSms::ValidationError) { agents.submit(agent_id: nil) }
check(error && error.message.include?("agentId"), "submit requires agentId")
check(sent[4][1][:body] == { acknowledgeFees: true }, "launch sends the acknowledgement")
check(raises?(SignalHouseSms::ValidationError) { agents.launch(agent_id: nil) }, "launch requires agentId")

SignalHouseSms::Billing.new(client, false).get_transaction_history(group_id: "G1", category: "RCS_INBOUND,RCS_CARRIER_PASSTHROUGH", limit: 1000)
check(query_of(client.calls.last[0]) == { "groupId" => "G1", "category" => "RCS_INBOUND,RCS_CARRIER_PASSTHROUGH", "limit" => "1000" }, "history forwards the category")
check(raises?(SignalHouseSms::ValidationError) { agents.remove_tester(agent_id: agent_id, phone_number: nil) }, "remove_tester requires phoneNumber")

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
registrations.launch_registration(registration_id: agent_id, acknowledge_fees: true, acknowledge_phi: true)
registrations.get_registrations(type: "RCS_AGENT", brand_id: "BXYZ123", campaign_id: "CABC123")
sent = client.calls.drop(calls_before)
check(sent.first(4).map { |p, o| [o[:method], p] } == [
  [:put, "/registration/#{agent_id}"], [:post, "/registration/#{agent_id}/validate"],
  [:post, "/registration/#{agent_id}/submit"], [:post, "/registration/#{agent_id}/launch"]
], "registration draft paths")
check(sent[0][1][:body] == { useCase: "OTP" }, "update_registration sends data as the body")
check(sent[3][1][:body] == { acknowledgeFees: true, acknowledgePhi: true }, "launch_registration sends both acknowledgements")
check(query_of(sent[4][0]) == { "type" => "RCS_AGENT", "brandId" => "BXYZ123", "campaignId" => "CABC123" },
      "registrations link filters")
error = raises?(SignalHouseSms::ValidationError) { registrations.update_registration(registration_id: agent_id, data: nil) }
check(error && error.message.include?("data"), "update_registration requires data")

messages = rcs.messages
check(messages.is_a?(SignalHouseSms::RcsMessages), "rcs exposes messages")
recipients = [{ phoneNumber: "+15125550199", variables: { name: "Ada" } }]
fallback = { mode: "auto", channel: "sms", from: "15125550100", content: { text: "Hi" }, validitySeconds: 600 }

messages.send(agent_id: agent_id, recipients: recipients, content: { blocks: [] }, content_format: "content.v1",
              traffic_type: "TRANSACTION", ttl_seconds: 900, fallback: fallback, status_callback_url: "https://example.com/cb",
              enable_shortlink: false, is_test: true, simulate: "delivered", idempotency_key: "k1")
path, options = client.calls.last
check(path == "/message/rcs" && options[:method] == :post, "send path")
check(options[:headers] == { "Idempotency-Key" => "k1" }, "send idempotency")
check(options[:body] == { agentId: agent_id, recipients: recipients, content: { blocks: [] }, contentFormat: "content.v1",
                          trafficType: "TRANSACTION", ttlSeconds: 900, fallback: fallback,
                          statusCallbackUrl: "https://example.com/cb", enableShortlink: false, isTest: true, simulate: "delivered" },
      "send body keeps false and drops nil")
messages.send(agent_id: agent_id, recipients: recipients, template_id: "T1", template_version: 2, expire_time: "2026-11-05T00:00:00Z")
check(client.calls.last[1][:body] == { agentId: agent_id, recipients: recipients, templateId: "T1", templateVersion: 2,
                                       expireTime: "2026-11-05T00:00:00Z" }, "send template body")
error = raises?(SignalHouseSms::ValidationError) { messages.send(agent_id: nil, recipients: recipients) }
check(error && error.message.include?("agentId"), "send requires agentId")
error = raises?(SignalHouseSms::ValidationError) { messages.send(agent_id: agent_id, recipients: nil) }
check(error && error.message.include?("recipients"), "send requires recipients")

messages.validate(agent_id: agent_id, recipients: recipients, template_id: "T1", simulate: "read")
path, options = client.calls.last
check(path == "/message/rcs/validate" && options[:method] == :post, "validate path")
check(options[:body] == { agentId: agent_id, recipients: recipients, templateId: "T1", simulate: "read" }, "validate body")

messages.estimate(agent_id: agent_id, recipient_count: 500, template_id: "T1", template_version: 2, traffic_type: "PROMOTION",
                  fallback: { mode: "rcs_only" })
path, options = client.calls.last
check(path == "/message/estimate" && options[:method] == :post, "estimate path")
check(options[:body] == { channel: "rcs", agentId: agent_id, recipientCount: 500, templateId: "T1", templateVersion: 2,
                          trafficType: "PROMOTION", fallback: { mode: "rcs_only" } }, "estimate adds the channel")
error = raises?(SignalHouseSms::ValidationError) { messages.estimate(agent_id: nil, recipient_count: 500) }
check(error && error.message.include?("agentId"), "estimate requires agentId")

messages.capabilities(agent_id: agent_id, phone_numbers: ["+15125550199"])
path, options = client.calls.last
check(path == "/rcs/capabilities" && options[:method] == :post, "capabilities path")
check(options[:body] == { agentId: agent_id, phoneNumbers: ["+15125550199"] }, "capabilities body")
error = raises?(SignalHouseSms::ValidationError) { messages.capabilities(agent_id: agent_id, phone_numbers: nil) }
check(error && error.message.include?("phoneNumbers"), "capabilities requires phoneNumbers")
messages.simulate_inbound(agent_id: agent_id, from: "+15125550199", type: "SUGGESTION", postback_data: "track_pkg")
path, options = client.calls.last
check(path == "/message/rcs/simulate-inbound" && options[:method] == :post, "simulate_inbound path")
check(options[:body] == { agentId: agent_id, from: "+15125550199", type: "SUGGESTION", postbackData: "track_pkg" }, "simulate_inbound body")
check(raises?(SignalHouseSms::ValidationError) { messages.simulate_inbound(agent_id: agent_id, from: nil, type: "TEXT") }, "simulate_inbound requires from")

messages.get(message_id: "a/1")
path, options = client.calls.last
check(path == "/message/a%2F1" && options[:method] == :get && options[:body].nil?, "get path")
error = raises?(SignalHouseSms::ValidationError) { messages.get(message_id: nil) }
check(error && error.message.include?("messageId"), "get requires messageId")

all_messages = SignalHouseSms::Messages.new(client, multipart, false)
all_messages.get_message(id: "a/1")
path, options = client.calls.last
check(path == "/message/a%2F1" && options[:method] == :get, "get_message path")
error = raises?(SignalHouseSms::ValidationError) { all_messages.get_message(id: nil) }
check(error && error.message.include?("id"), "get_message requires id")
all_messages.get_message_interactions(id: "a/1")
check(client.calls.last[0] == "/message/a%2F1/interactions" && client.calls.last[1][:method] == :get, "get_message_interactions path")

messages.list(agent_id: agent_id, from: "2026-11-01", to: "2026-11-02", group_id: "G1", status: "READ", page: 2, limit: 50,
              template_id: "T1", template_version: 3, bulk_id: "B1", fallback_reason: "NOT_CAPABLE", billing_class: "RICH_MEDIA",
              delivered_channel: "sms", is_test: false)
path, options = client.calls.last
check(path_of(path) == "/message" && options[:method] == :get, "list path")
check(query_of(path) == { "registrationId" => agent_id, "startDate" => "2026-11-01", "endDate" => "2026-11-02", "groupId" => "G1",
                          "status" => "READ", "page" => "2", "limit" => "50", "templateId" => "T1", "templateVersion" => "3",
                          "bulkId" => "B1", "fallbackReason" => "NOT_CAPABLE", "billingClass" => "RICH_MEDIA",
                          "deliveredChannel" => "sms", "isTest" => "false", "messageType" => "RCS", "dateBounds" => "exact" },
      "list maps filters and adds the type")
calls_before = client.calls.size
error = raises?(SignalHouseSms::ValidationError) { messages.list(group_id: nil, from: "2026-11-01", to: "2026-11-02", agent_id: agent_id) }
check(error && error.message.include?("groupId"), "list requires groupId")
error = raises?(SignalHouseSms::ValidationError) { messages.list(group_id: "G1", from: nil, to: "2026-11-02") }
check(error && error.message.include?("from"), "list requires from")
error = raises?(SignalHouseSms::ValidationError) { messages.list(group_id: "G1", from: "2026-11-01", to: nil) }
check(error && error.message.include?("to"), "list requires to")
check(client.calls.size == calls_before, "list makes no request without its required fields")

all_messages.get_messages(group_id: "G1", start_date: "2026-11-01", end_date: "2026-11-02", template_id: "T1", template_version: 3,
                          bulk_id: "B1", fallback_reason: "TTL_EXPIRED", billing_class: "RICH", delivered_channel: "sms",
                          is_test: false)
path, options = client.calls.last
check(path_of(path) == "/message" && options[:method] == :get, "get_messages path")
check(query_of(path) == { "groupId" => "G1", "startDate" => "2026-11-01", "endDate" => "2026-11-02", "templateId" => "T1",
                          "templateVersion" => "3", "bulkId" => "B1", "fallbackReason" => "TTL_EXPIRED", "billingClass" => "RICH",
                          "deliveredChannel" => "sms", "isTest" => "false" },
      "get_messages forwards the RCS filters")

webhooks = SignalHouseSms::Webhooks.new(client, false)
webhooks.get_webhooks(group_id: "G1", endpoint_type: "Agent", agent_id: agent_id)
check(query_of(client.calls.last[0]) == { "groupId" => "G1", "endpointType" => "Agent", "agentId" => agent_id }, "get_webhooks filters by agent")
webhook_data = { "groupId" => "G1", "endpointType" => "Agent", "agentId" => agent_id, "url" => "https://a.example/rcs", "secondaryUrl" => "https://b.example/rcs" }
webhooks.create_webhook(webhook_data: webhook_data)
check(client.calls.last[1][:body] == webhook_data, "create_webhook sends the agent fields")

fixtures = File.expand_path("../../fixtures/rcs/requests.json", __dir__)
if File.exist?(fixtures)
  ruby_name = ->(name) { name.gsub(/[A-Z]/) { |letter| "_#{letter.downcase}" }.to_sym }
  JSON.parse(File.read(fixtures))["cases"].each do |test_case|
    domain, method = test_case["operation"].split(".")
    target = domain == "agents" ? rcs.agents : rcs.messages
    target.public_send(ruby_name.call(method), **test_case["input"].to_h { |key, value| [ruby_name.call(key), value] })
    path, options = client.calls.last
    request = test_case["request"]
    check(options[:method] == request["method"].downcase.to_sym, "#{test_case["name"]}: method")
    check(path_of(path) == request["path"], "#{test_case["name"]}: path")
    check(query_of(path) == request.fetch("query", {}), "#{test_case["name"]}: query")
    check(JSON.parse(JSON.generate(options[:body] || {})) == request.fetch("body", {}), "#{test_case["name"]}: body")
  end
end

puts "RCS Ruby contracts passed (agents CRUD and lifecycle, multipart asset upload, registration drafts and filters, messages send/validate/estimate/capabilities/get/list, get_message, get_messages RCS filters)"
