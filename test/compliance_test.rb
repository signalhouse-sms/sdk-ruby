# frozen_string_literal: true

# Request-contract coverage for the compliance namespace (customer case methods).
# Run from sdks/ruby: ruby -Ilib test/compliance_test.rb
require "cgi"
require "json"
require "uri"
require "stringio"
require "securerandom"
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/compliance"

# Capture serialized requests without sending them; mirrors HttpClient's query and validation rules.
class ComplianceSpyClient
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

client = ComplianceSpyClient.new
multipart = ComplianceSpyClient.new
compliance = SignalHouseSms::Compliance.new(client, multipart, false)

compliance.get_cases(group_id: "G0000001", status: "OPEN", stage: "customer", object_type: "CAMPAIGN", object_id: "C1",
                     subgroup_id: "S1", suspended: true, from: "2026-11-01T00:00:00Z", to: "2026-11-13T00:00:00Z",
                     sort: "fixBy", page: 2, limit: 50, token: "session")
path, options = client.calls.last
check(path_of(path) == "/compliance/cases" && options[:method] == :get && options[:token] == "session" && !options.key?(:body), "get_cases")
check(query_of(path) == { "groupId" => "G0000001", "status" => "OPEN", "stage" => "customer", "objectType" => "CAMPAIGN",
                          "objectId" => "C1", "subgroupId" => "S1", "suspended" => "true", "from" => "2026-11-01T00:00:00Z",
                          "to" => "2026-11-13T00:00:00Z", "sort" => "fixBy", "page" => "2", "limit" => "50" }, "get_cases query")
compliance.get_cases
check(client.calls.last[0] == "/compliance/cases", "get_cases sends no query when no filter is given")
compliance.get_cases(suspended: false, page: 1)
check(client.calls.last[0] == "/compliance/cases?suspended=false&page=1", "get_cases keeps an explicit false and drops unset filters")

compliance.get_case(case_id: "CASE-12/a")
path, options = client.calls.last
check(path == "/compliance/cases/CASE-12%2Fa" && options[:method] == :get && !options.key?(:body), "get_case escapes caseId")

compliance.answer_requirement(case_id: "CASE-12", requirement_id: "CASE-12-1", answer: "Removed the number", file_ids: %w[F1 F2],
                              idempotency_key: "k1")
path, options = client.calls.last
check(path == "/compliance/cases/CASE-12/requirements/CASE-12-1" && options[:method] == :put, "answer_requirement")
check(options[:body] == { answer: "Removed the number", fileIds: %w[F1 F2] }, "answer_requirement body")
check(options[:headers] == { "Idempotency-Key" => "k1" }, "answer_requirement idempotency")
compliance.answer_requirement(case_id: "CASE-12", requirement_id: "CASE-12-1", answer: "Done")
check(client.calls.last[1][:body] == { answer: "Done" }, "answer_requirement body omits unset fileIds")
compliance.answer_requirement(case_id: "CASE-12", requirement_id: "CASE-12-1", file_ids: ["F1"])
check(client.calls.last[1][:body] == { fileIds: ["F1"] }, "answer_requirement body omits unset answer")
compliance.answer_requirement(case_id: "CASE-12/a", requirement_id: "CASE-12/1")
check(client.calls.last[0] == "/compliance/cases/CASE-12%2Fa/requirements/CASE-12%2F1" && client.calls.last[1][:body] == {},
      "answer_requirement escapes both ids and sends an empty body when nothing is given")

io = StringIO.new("%PDF".b)
part = { filename: "optin.pdf", io: io, content_type: "application/pdf" }
calls_before = client.calls.size
compliance.upload_file(case_id: "CASE-12", requirement_id: "CASE-12-1", file: part, idempotency_key: "k2")
path, options = multipart.calls.last
check(client.calls.size == calls_before, "upload_file uses the multipart client")
check(path == "/compliance/files" && options[:method] == :post, "upload_file")
check(options[:body] == { "caseId" => "CASE-12", "requirementId" => "CASE-12-1", "file" => part }, "upload_file fields")
check(options[:headers] == { "Idempotency-Key" => "k2" }, "upload_file idempotency")
compliance.upload_file(case_id: "CASE-12", file: part)
check(multipart.calls.last[1][:body] == { "caseId" => "CASE-12", "file" => part }, "upload_file omits an unset requirementId")
compliance.upload_file(case_id: "CASE-12", requirement_id: "", file: part)
check(!multipart.calls.last[1][:body].key?("requirementId"), "upload_file omits an empty requirementId")

wire = SignalHouseSms::HttpClient.new(base_url: "https://example.invalid", api_key: "k", multipart: true)
encoded = wire.send(:build_multipart_body, { "caseId" => "CASE-12", "requirementId" => "CASE-12-1",
                                             "file" => { filename: "optin.pdf", io: StringIO.new("PDF"), content_type: "application/pdf" } }, "B")
check(encoded.include?("name=\"caseId\"\r\n\r\nCASE-12\r\n") && encoded.include?("name=\"requirementId\"\r\n\r\nCASE-12-1\r\n") &&
      encoded.include?("name=\"file\"; filename=\"optin.pdf\"\r\nContent-Type: application/pdf"),
      "multipart body carries caseId, requirementId and file parts")

compliance.get_file(file_id: "CF1/2", token: "session")
path, options = client.calls.last
check(path == "/compliance/files/CF1%2F2" && options[:method] == :get && options[:token] == "session" && !options.key?(:body), "get_file")

[
  -> { compliance.get_case(case_id: nil) },
  -> { compliance.answer_requirement(case_id: nil, requirement_id: "CASE-12-1") },
  -> { compliance.answer_requirement(case_id: "CASE-12", requirement_id: nil) },
  -> { compliance.upload_file(case_id: nil, file: part) },
  -> { compliance.upload_file(case_id: "CASE-12", file: nil) },
  -> { compliance.get_file(file_id: nil) }
].each_with_index { |call, index| check(raises?(SignalHouseSms::ValidationError, &call), "required parameter #{index}") }

puts "Compliance Ruby contracts passed (get_cases, get_case, answer_requirement, upload_file, get_file, validation)"
