# frozen_string_literal: true

# Request-contract coverage for the voice mobile push namespaces.
# Run from sdks/ruby: ruby -Ilib test/push_test.rb
require "cgi"
require "json"
require "uri"
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/voice"

# Capture serialized requests without sending them; mirrors HttpClient's query and validation rules.
class PushSpyClient
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

id = "5a3c2f8e-1b7d-4c9a-9e2f-0d4b6a8c1e33"
cred_base = "/voice/api/v1/push-credentials"
device_base = "/voice/api/v1/push-devices"

voice = SignalHouseSms::Voice.new(PushSpyClient.new, false)
check(voice.push_credentials.is_a?(SignalHouseSms::VoicePushCredentials), "reachable as client.voice.push_credentials")
check(voice.push_devices.is_a?(SignalHouseSms::VoicePushDevices), "reachable as client.voice.push_devices")

# ---- Push credentials --------------------------------------------------------

client = PushSpyClient.new
creds = SignalHouseSms::VoicePushCredentials.new(client, false)
apns = { provider: "apns", keyId: "ABC123DEFG", teamId: "TEAM123456", bundleId: "com.example.app", privateKey: "p8-key-contents" }
fcm = { provider: "fcm", serviceAccount: "{}" }

creds.list
creds.get(id: id)
creds.create(credential_data: apns)
creds.update(id: id, credential_data: fcm)
creds.delete(id: id, token: "t", idempotency_key: "k1")

list, get, create, update, delete = client.calls

check(list[0] == cred_base && list[1][:method] == :get, "list path")
check(get[0] == "#{cred_base}/#{id}" && get[1][:method] == :get, "get")
check(create[0] == cred_base && create[1][:method] == :post && create[1][:body] == apns, "create posts the credential")
check(update[0] == "#{cred_base}/#{id}" && update[1][:method] == :put && update[1][:body] == fcm, "update puts the credential")
check(delete[0] == "#{cred_base}/#{id}" && delete[1][:method] == :delete, "delete")
check(delete[1][:token] == "t" && delete[1][:headers] == { "Idempotency-Key" => "k1" }, "per-call token and idempotency key pass through")

check(raises?(SignalHouseSms::ValidationError) { creds.get(id: nil) }, "get requires an id")
check(raises?(SignalHouseSms::ValidationError) { creds.create(credential_data: nil) }, "create requires credential_data")
check(raises?(SignalHouseSms::ValidationError) { creds.update(id: id, credential_data: nil) }, "update requires credential_data")
check(raises?(SignalHouseSms::ValidationError) { creds.delete(id: nil) }, "delete requires an id")

encoded = PushSpyClient.new
SignalHouseSms::VoicePushCredentials.new(encoded, false).get(id: "a/b")
check(encoded.calls[0][0] == "#{cred_base}/a%2Fb", "credential ids are URL-encoded")

# ---- Push devices (the app, with its voice token) -----------------------------

client = PushSpyClient.new
devices = SignalHouseSms::VoicePushDevices.new(client, false)
device_data = { provider: "fcm", deviceToken: "fcm:tok/1" }

devices.register(device_data: device_data, token: "voice-jwt")
devices.unregister(device_token: "fcm:tok/1", token: "voice-jwt")
devices.list_deliveries(limit: 5, token: "voice-jwt")
devices.list_deliveries(token: "voice-jwt")

register, unregister, limited, unlimited = client.calls

check(register[0] == device_base && register[1][:method] == :post && register[1][:body] == device_data, "register posts the device")
check(unregister[0] == "#{device_base}/fcm%3Atok%2F1" && unregister[1][:method] == :delete, "unregister encodes the device token: #{unregister[0]}")
check(limited[0] == "#{device_base}/deliveries?limit=5" && limited[1][:method] == :get, "list_deliveries sends the limit: #{limited[0]}")
check(unlimited[0] == "#{device_base}/deliveries" && unlimited[1][:method] == :get, "list_deliveries without a limit sends no query: #{unlimited[0]}")
client.calls.each { |path, options| check(options[:token] == "voice-jwt", "#{path} carries the voice token") }

check(raises?(SignalHouseSms::ValidationError) { devices.register(device_data: nil, token: "voice-jwt") }, "register requires device_data")
check(raises?(SignalHouseSms::ValidationError) { devices.unregister(device_token: nil, token: "voice-jwt") }, "unregister requires a device_token")

puts "push: ok"
