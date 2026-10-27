# frozen_string_literal: true

# Request-contract coverage for registrations and regional reporting filters.
# Run from sdks/ruby: ruby -Ilib test/registrations_test.rb
require "cgi"
require "json"
require "uri"
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/registrations"
require "signalhouse_sms/domains/messages"
require "signalhouse_sms/domains/numbers"
require "signalhouse_sms/domains/shortlinks"
require "signalhouse_sms/domains/brands"

# Capture serialized requests without sending them; mirrors HttpClient's query and validation rules.
class RegistrationSpyClient
  attr_reader :calls

  def initialize
    @calls = []
  end

  def get_query_string(params)
    parts = params.reject { |_, value| value.nil? }.map do |key, value|
      encoded = value.is_a?(Array) ? value.map { |v| CGI.escape(v.to_s) }.join(",") : CGI.escape(value.to_s)
      "#{CGI.escape(key.to_s)}=#{encoded}"
    end
    parts.empty? ? "" : "?#{parts.join('&')}"
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

client = RegistrationSpyClient.new
messages = SignalHouseSms::Messages.new(client, client, false)
scopes = [{ region: "GB", channels: ["virtualLongCode"], phoneNumber: ["447400123456"] }]
{
  get_messages: "/message", get_analytics: "/message/analytics", get_analytics_detail: "/message/analytics/detail",
  get_analytics_by_subgroup: "/message/analytics/by-subgroup", get_analytics_by_error_code: "/message/analytics/by-error-code",
  get_dnc_analytics: "/message/dnc/analytics", get_dnc_records: "/message/dnc"
}.each do |method, expected_path|
  messages.public_send(method, group_id: "G1", region: %w[US GB], region_scopes: scopes, token: "test-token")
  path, options = client.calls.last
  check(URI.parse(path).path == expected_path, "#{method} path")
  query = query_of(path)
  check(query["region"] == "US,GB", "#{method} region CSV")
  check(JSON.parse(query["regionScopes"]) == JSON.parse(scopes.to_json), "#{method} JSON scopes")
  check(options[:token] == "test-token", "#{method} token")
  messages.public_send(method, group_id: "G1", region: "GB", region_scopes: [])
  check(query_of(client.calls.last[0])["regionScopes"] == "[]", "#{method} empty scopes")
  messages.public_send(method, group_id: "G1", region_scopes: '[{"region":"US","channels":["tenDLC"]}]')
  check(query_of(client.calls.last[0])["regionScopes"] == '[{"region":"US","channels":["tenDLC"]}]', "#{method} string scopes pass through")
  messages.public_send(method, group_id: "G1")
  check(!client.calls.last[0].include?("region"), "#{method} omits region by default")
end

messages.get_analytics_filter_options(group_id: "G1", region: "GB")
check(client.calls.last[0] == "/message/analytics/filter-options?groupId=G1&region=GB", "filter options region")

{
  get_analytics: "/message/analytics", get_analytics_detail: "/message/analytics/detail",
  get_analytics_throughput: "/message/analytics/throughput", get_dnc_analytics: "/message/dnc/analytics",
  get_analytics_by_subgroup: "/message/analytics/by-subgroup", get_analytics_by_error_code: "/message/analytics/by-error-code",
  get_dnc_records: "/message/dnc", get_messages: "/message"
}.each do |method, expected_path|
  messages.public_send(method, group_id: "G1", campaign_id: "C1", registration_id: %w[REG1 REG2], start_date: "2026-09-01", end_date: "2026-09-02")
  path = client.calls.last[0]
  check(URI.parse(path).path == expected_path, "#{method} registration path")
  check(query_of(path)["registrationId"] == "REG1,REG2" && query_of(path)["campaignId"] == "C1", "#{method} registrationId CSV")
  messages.public_send(method, group_id: "G1", start_date: "2026-09-01", end_date: "2026-09-02")
  check(!client.calls.last[0].include?("registrationId"), "#{method} omits registrationId by default")
end
SignalHouseSms::Numbers.new(client, client, false).get_phone_numbers(campaign_id: "C1", registration_id: "REG1")
check(client.calls.last[0] == "/number?campaignId=C1&registrationId=REG1", "phone numbers registrationId")

domain = SignalHouseSms::Registrations.new(client, true)
domain.get_catalog(region: "GB", token: "test-token")
check(client.calls.last[0] == "/registration/catalog?region=GB" && client.calls.last[1][:method] == :get, "catalog")
check(client.calls.last[1][:token] == "test-token", "catalog token")
domain.get_quotes(region: "GB", type: "VIRTUAL_LONG_CODE", quantity: 2)
check(client.calls.last[0] == "/registration/quotes?region=GB&type=VIRTUAL_LONG_CODE&quantity=2" && client.calls.last[1][:method] == :get, "quotes")
domain.get_quotes(region: "UK", type: "VIRTUAL_LONG_CODE", group_id: "G1")
check(client.calls.last[0] == "/registration/quotes?region=UK&type=VIRTUAL_LONG_CODE&quantity=1&groupId=G1", "staff quotes default quantity")
domain.get_registrations(group_id: "G1", subgroup_id: "S1", region: %w[GB CA], type: "VIRTUAL_LONG_CODE", kind: "sender",
                         status: %w[PENDING_PROVIDER APPROVED], parent_registration_id: "REG0", phone_number: "15551234567",
                         sort_by: "status", sort_order: "asc", page: 2, limit: 10)
check(client.calls.last[0] == "/registration?groupId=G1&subgroupId=S1&region=GB,CA&type=VIRTUAL_LONG_CODE&kind=sender&status=PENDING_PROVIDER,APPROVED&parentRegistrationId=REG0&phoneNumber=15551234567&sortBy=status&sortOrder=asc&page=2&limit=10", "list")
domain.get_registrations
check(client.calls.last[0] == "/registration", "list without filters")
domain.get_registration(registration_id: "REG 1")
check(client.calls.last[0] == "/registration/REG+1", "read escapes id")
domain.cancel_registration(registration_id: "GB8T9GTD5AZY")
check(client.calls.last[0] == "/registration/GB8T9GTD5AZY" && client.calls.last[1][:method] == :delete, "cancel")
data = {
  region: "GB", type: "VIRTUAL_LONG_CODE", subgroupId: "S1",
  capabilities: ["SMS"], data: { quantity: 1, useCases: ["Support"] }
}
domain.create_registration(registration_data: data)
check(client.calls.last[0] == "/registration" && client.calls.last[1][:method] == :post && client.calls.last[1][:body] == data, "create")
%i[quoteVersion version country quantity].each { |key| check(!client.calls.last[1][:body].key?(key), "no #{key}") }

domain.admin.review_registration(registration_id: "REG1", action: "APPROVE")
check(client.calls.last[0] == "/registration/REG1/review" && client.calls.last[1][:body] == { action: "APPROVE" }, "approve")
domain.admin.review_registration(registration_id: "REG1", action: "REJECT", reason: "Not a business use case")
check(client.calls.last[1][:body] == { action: "REJECT", reason: "Not a business use case" }, "reject reason")
domain.admin.correct_registration(registration_id: "REG1", reason: "Provider asked", data: { useCases: ["Support"] })
check(client.calls.last[0] == "/registration/REG1/corrections", "corrections path")
check(client.calls.last[1][:body] == { reason: "Provider asked", data: { useCases: ["Support"] } }, "corrections body")
domain.admin.add_number(registration_id: "REG1", phone_number: "447400123456")
check(client.calls.last[0] == "/registration/REG1/numbers" && client.calls.last[1][:body] == { phoneNumber: "447400123456" }, "add number")
domain.admin.reconcile(registration_id: "REG1", external_id: "ORDER-123")
check(client.calls.last[0] == "/registration/REG1/reconcile" && client.calls.last[1][:body] == { externalId: "ORDER-123" }, "reconcile")
domain.admin.get_application(registration_id: "REG1")
check(client.calls.last[0] == "/registration/REG1/application?format=json" && client.calls.last[1][:method] == :get, "application json envelope")

check(SignalHouseSms::Registrations.new(client, false).admin.nil?, "staff gate")
begin
  domain.get_registration(registration_id: nil)
  raise "missing ID accepted"
rescue SignalHouseSms::ValidationError
end
begin
  domain.cancel_registration(registration_id: nil)
  raise "missing cancel ID accepted"
rescue SignalHouseSms::ValidationError
end
begin
  domain.get_catalog(region: nil)
  raise "missing region accepted"
rescue SignalHouseSms::ValidationError
end
begin
  domain.get_quotes(region: "GB", type: nil)
  raise "missing type accepted"
rescue SignalHouseSms::ValidationError
end

messages.estimate_message(sender_phone_number: "447400123456", recipient_phone_numbers: ["447911123456"], message_body: "Hello")
check(client.calls.last[0] == "/message/estimate" && client.calls.last[1][:body][:messageType] == "SMS", "UK estimate shares the payload")

alphanumeric = {
  region: "GB", type: "ALPHANUMERIC_SENDER_ID", subgroupId: "S1",
  capabilities: ["SMS"],
  data: {
    requestedSenderId: "ACME", trafficOrigin: "LOCAL", trafficType: "TRANSACTIONAL",
    companyName: "Acme Ltd", companyCountry: "United Kingdom", companyWebsite: "https://acme.example",
    industry: "Retail", senderRelationship: "Trading name of Acme Ltd", messageExample: "Your Acme order has shipped."
  }
}
domain.create_registration(registration_data: alphanumeric)
path, options = client.calls.last
check(path == "/registration" && options[:method] == :post && options[:body] == alphanumeric, "alphanumeric submission posts data unchanged")

shortlinks = SignalHouseSms::Shortlinks.new(client, false)
shortlinks.get_opt_out(code: "ABC/1", token: "session")
path, options = client.calls.last
check(path == "/shortlink/optout/ABC%2F1" && options[:method] == :get && !options.key?(:body) && options[:token] == "session", "get opt-out contract")
shortlinks.confirm_opt_out(code: "ABC/1")
path, options = client.calls.last
check(path == "/shortlink/optout/ABC%2F1" && options[:method] == :post && !options.key?(:body), "confirm opt-out contract")
%i[get_opt_out confirm_opt_out].each do |method|
  begin
    shortlinks.public_send(method, code: nil)
    raise "#{method} accepted a missing code"
  rescue SignalHouseSms::ValidationError
  end
end

# A given subgroup goes into the business verification's subgroupId query parameter, never the body.
brands = SignalHouseSms::Brands.new(client, client, true)
brands.get_business_verification(group_id: "G/1", subgroup_id: "S0000001", token: "test-token")
path, options = client.calls.last
check(path == "/brand/business-verification/G%2F1?subgroupId=S0000001" && options[:method] == :get && !options.key?(:body) && options[:token] == "test-token", "subgroup business verification read")
details = { businessName: "Acme Inc", registrationType: "EIN", registrationNumber: "12-3456789" }
brands.submit_business_verification(group_id: "G/1", details: details, subgroup_id: "S0000001", idempotency_key: "key-1")
path, options = client.calls.last
check(path == "/brand/business-verification/G%2F1?subgroupId=S0000001" && options[:method] == :put && options[:body] == details, "subgroup business verification submit")
check(options[:headers] == { "Idempotency-Key" => "key-1" }, "subgroup business verification submit idempotency key")
brands.get_business_verification(group_id: "G1", subgroup_id: "S&1 2")
check(client.calls.last[0] == "/brand/business-verification/G1?subgroupId=S%261+2", "subgroup escaped as a query value")
# Without a subgroup both URLs stay exactly as they were.
brands.get_business_verification(group_id: "G1")
check(client.calls.last[0] == "/brand/business-verification/G1", "business verification read without a subgroup")
brands.submit_business_verification(group_id: "G1", details: details)
path, options = client.calls.last
check(path == "/brand/business-verification/G1" && options[:body] == details, "business verification submit without a subgroup")

# The staff toll-free ISV account is read and set on the group's path; the body holds only the account and its key.
brands.get_toll_free_isv_account(group_id: "G/1", token: "test-token")
path, options = client.calls.last
check(path == "/brand/toll-free-isv-account/G%2F1" && options[:method] == :get && !options.key?(:body) && options[:token] == "test-token", "toll-free ISV account read")
account = { group_id: "G/1", account_sid: "AC#{'0' * 32}", api_key_sid: "SK#{'1' * 32}", api_key_secret: "key-secret" }
brands.set_toll_free_isv_account(**account, idempotency_key: "key-1")
path, options = client.calls.last
check(path == "/brand/toll-free-isv-account/G%2F1" && options[:method] == :put && options[:headers] == { "Idempotency-Key" => "key-1" }, "toll-free ISV account set")
check(options[:body] == { accountSid: account[:account_sid], apiKeySid: account[:api_key_sid], apiKeySecret: "key-secret" }, "toll-free ISV account body")
sent = client.calls.length
begin
  brands.get_toll_free_isv_account(group_id: nil)
  raise "get_toll_free_isv_account accepted a missing groupId"
rescue SignalHouseSms::ValidationError
end
{ "groupId" => :group_id, "accountSid" => :account_sid, "apiKeySid" => :api_key_sid, "apiKeySecret" => :api_key_secret }.each do |field, key|
  begin
    brands.set_toll_free_isv_account(**account.merge(key => nil))
    raise "set_toll_free_isv_account accepted a missing #{field}"
  rescue SignalHouseSms::ValidationError => e
    check(e.message == "Missing required parameter: #{field}", "set_toll_free_isv_account names the missing #{field}")
  end
end
check(client.calls.length == sent, "refused toll-free ISV account calls send nothing")

puts "Registration Ruby contracts passed (7 regional reads, filter options, catalog, quotes, registrations, alphanumeric submission, opt-out links, staff namespace, validation, subgroup business verification, toll-free ISV account)"

# The current toll-free carrier filter on the number list.
numbers = SignalHouseSms::Numbers.new(client, client, false)
numbers.get_phone_numbers(group_id: "G1", current_toll_free_carrier: true, token: "test-token")
path, options = client.calls.last
check(path == "/number?groupId=G1&currentTollFreeCarrier=true" && options[:method] == :get && options[:token] == "test-token", "phone numbers by group send currentTollFreeCarrier")
numbers.get_phone_numbers(subgroup_id: "S1", current_toll_free_carrier: true)
check(client.calls.last[0] == "/number?subgroupId=S1&currentTollFreeCarrier=true", "phone numbers by subgroup send currentTollFreeCarrier")
numbers.get_phone_numbers(group_id: "G1", current_toll_free_carrier: false)
check(client.calls.last[0] == "/number?groupId=G1&currentTollFreeCarrier=false", "phone numbers send currentTollFreeCarrier false as lowercase")
numbers.get_phone_numbers(group_id: "G1")
check(client.calls.last[0] == "/number?groupId=G1", "phone numbers omit currentTollFreeCarrier by default")

puts "Toll-free carrier filter Ruby contract passed"
