# frozen_string_literal: true

# The idempotency_key option reaches the request as the Idempotency-Key header.
# Run from sdks/ruby: ruby -Ilib test/idempotency_test.rb
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/registrations"

# Capture requests without sending them.
class IdempotencySpyClient
  attr_reader :calls

  def initialize
    @calls = []
  end

  def require_params(_fields); end

  def request(path, **options)
    @calls << [path, options]
    { success: true }
  end
end

def check(condition, message)
  raise message unless condition
end

check(SignalHouseSms::HttpClient.headers_for({}).nil?, "no options send no headers")
check(SignalHouseSms::HttpClient.headers_for(headers: { "X-Trace" => "t" }) == { "X-Trace" => "t" }, "headers pass through unchanged")
check(SignalHouseSms::HttpClient.headers_for(headers: { "X-Trace" => "t" }, idempotency_key: "key-1") == { "X-Trace" => "t", "Idempotency-Key" => "key-1" },
      "idempotency_key joins the custom headers")

client = IdempotencySpyClient.new
registrations = SignalHouseSms::Registrations.new(client, false)
registrations.create_registration(registration_data: { region: "GB", type: "VIRTUAL_LONG_CODE", subgroupId: "SG1" }, idempotency_key: "key-1")
check(client.calls.last[1][:headers] == { "Idempotency-Key" => "key-1" }, "a domain method sends the Idempotency-Key header")

puts "Idempotency Ruby contract passed"
