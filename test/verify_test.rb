# frozen_string_literal: true

# Request-contract coverage for the verify namespace (SIM Swap and Number Verify).
# Run from sdks/ruby: ruby -Ilib test/verify_test.rb
require "cgi"
require "json"
require "uri"
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/verify"

# Capture serialized requests without sending them; mirrors HttpClient's validation rules.
class VerifySpyClient
  attr_reader :calls

  def initialize
    @calls = []
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
rescue error_class => e
  e
end

phone = "+12025550123"
client = VerifySpyClient.new
verify = SignalHouseSms::Verify.new(client, false)

verify.check_sim_swap(phone_number: phone, max_age: 240, include_swap_date: true, idempotency_key: "k1")
path, options = client.calls.last
check(path == "/verify/sim-swap" && options[:method] == :post, "check_sim_swap")
check(options[:headers] == { "Idempotency-Key" => "k1" }, "check_sim_swap idempotency")
check(options[:body] == { phoneNumber: phone, maxAge: 240, includeSwapDate: true }, "check_sim_swap body")
verify.check_sim_swap(phone_number: phone, include_swap_date: false)
check(client.calls.last[1][:body] == { phoneNumber: phone, includeSwapDate: false }, "check_sim_swap keeps an explicit false")
verify.check_sim_swap(phone_number: phone)
check(client.calls.last[1][:body] == { phoneNumber: phone }, "check_sim_swap body omits unset fields")
check(raises?(SignalHouseSms::ValidationError) { verify.check_sim_swap(phone_number: nil) }, "check_sim_swap requires phone_number")

verify.start_number_verification(phone_number: phone, device_phone_number: phone, redirect_url: "https://example.com/done")
path, options = client.calls.last
check(path == "/verify/number" && options[:method] == :post, "start_number_verification")
check(options[:body] == { phoneNumber: phone, devicePhoneNumber: phone, redirectUrl: "https://example.com/done" }, "start_number_verification body")
verify.start_number_verification(phone_number: phone, token: "session")
path, options = client.calls.last
check(options[:body] == { phoneNumber: phone } && options[:token] == "session", "start_number_verification body omits unset fields")
check(raises?(SignalHouseSms::ValidationError) { verify.start_number_verification(phone_number: nil) }, "start_number_verification requires phone_number")

verify.get_number_verification(check_id: "NVC1/2")
path, options = client.calls.last
check(path == "/verify/number/NVC1%2F2" && options[:method] == :get && !options.key?(:body), "get_number_verification")
check(raises?(SignalHouseSms::ValidationError) { verify.get_number_verification(check_id: nil) }, "get_number_verification requires check_id")

puts "Verify Ruby contracts passed (check_sim_swap, start_number_verification, get_number_verification, validation)"
