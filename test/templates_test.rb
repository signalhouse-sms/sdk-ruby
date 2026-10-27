# frozen_string_literal: true

# Request-contract coverage for the templates namespace.
# Run from sdks/ruby: ruby -Ilib test/templates_test.rb
require "cgi"
require "json"
require "uri"
require "stringio"
require "securerandom"
require "signalhouse_sms/errors"
require "signalhouse_sms/http_client"
require "signalhouse_sms/domains/templates"

# Capture serialized requests without sending them; mirrors HttpClient's query and validation rules.
class TemplateSpyClient
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
rescue error_class
  true
end

body = {
  channel: "rcs", contentFormat: "rcs.blocks.v1",
  content: { blocks: [{ id: "b1", kind: "text", text: "Hi {{first_name}}" }] },
  variables: [{ key: "first_name", type: "text", required: true }], defaults: {}, fallback: {}
}

client = TemplateSpyClient.new
multipart = TemplateSpyClient.new
templates = SignalHouseSms::Templates.new(client, multipart, false)

templates.create(group_id: "G1", name: "Welcome", body: body, tag: "Promo", idempotency_key: "key-1")
path, options = client.calls.last
check(path == "/template" && options[:method] == :post, "create path")
check(options[:body] == { groupId: "G1", name: "Welcome", body: body, tag: "Promo" }, "create body")
check(options[:headers] == { "Idempotency-Key" => "key-1" }, "create idempotency")
templates.create(group_id: "G1", name: "Welcome", body: body)
check(client.calls.last[1][:body].keys == %i[groupId name body], "create omits unset optionals")

templates.list(group_id: "G1", state: "PUBLISHED", channel: "rcs", tag: "Promo", search: "wel",
               sort_by: "name", sort_order: "asc", page: 2, limit: 50, token: "session")
path, options = client.calls.last
check(path_of(path) == "/template" && options[:method] == :get && options[:token] == "session", "list")
check(query_of(path) == { "groupId" => "G1", "state" => "PUBLISHED", "channel" => "rcs", "tag" => "Promo",
                          "search" => "wel", "sortBy" => "name", "sortOrder" => "asc", "page" => "2", "limit" => "50" }, "list query")

templates.get(template_id: "TPL/1", group_id: "G1", version: "draft")
check(client.calls.last[0] == "/template/TPL%2F1?groupId=G1&version=draft", "get escapes id")

templates.update(template_id: "TPL1", group_id: "G1")
path, options = client.calls.last
check(path == "/template/TPL1" && options[:method] == :put, "update path")
check(options[:body] == { groupId: "G1" }, "update sends only groupId, keeps tag")
templates.update(template_id: "TPL1", group_id: "G1", tag: nil)
check(client.calls.last[1][:body] == { groupId: "G1", tag: nil }, "update clears tag with explicit nil")
templates.update(template_id: "TPL1", group_id: "G1", name: "New", tag: "Promo", body: body)
check(client.calls.last[1][:body] == { groupId: "G1", name: "New", tag: "Promo", body: body }, "update full")

templates.publish(template_id: "TPL1", group_id: "G1")
path, options = client.calls.last
check(path == "/template/TPL1/publish" && options[:method] == :post &&
      options[:body] == { groupId: "G1" }, "publish")
templates.archive(template_id: "TPL1", group_id: "G1")
check(client.calls.last[0] == "/template/TPL1/archive" &&
      client.calls.last[1][:body] == { groupId: "G1" }, "archive")
templates.versions(template_id: "TPL1", group_id: "G1", page: 1, limit: 10)
check(client.calls.last[0] == "/template/TPL1/versions?groupId=G1&page=1&limit=10", "versions")
templates.validate(template_id: "TPL1", group_id: "G1", body: body)
check(client.calls.last[0] == "/template/TPL1/validate" && client.calls.last[1][:body] == { groupId: "G1", body: body }, "validate body")
templates.validate(template_id: "TPL1", group_id: "G1", version: "published")
check(client.calls.last[1][:body] == { groupId: "G1", version: "published" }, "validate version")
check(raises?(SignalHouseSms::Error) { templates.validate(template_id: "TPL1", group_id: "G1") }, "validate needs one")
check(raises?(SignalHouseSms::Error) { templates.validate(template_id: "TPL1", group_id: "G1", body: body, version: 1) }, "validate rejects both")
templates.capabilities(group_id: "G1", channel: "rcs", provider: "sinch")
check(client.calls.last[0] == "/template/capabilities?groupId=G1&channel=rcs&provider=sinch", "capabilities")

io = StringIO.new("\x89PNG".b)
calls_before = client.calls.size
templates.upload_media(group_id: "G1", file: io, file_name: "logo.png", idempotency_key: "key-2")
path, options = multipart.calls.last
check(client.calls.size == calls_before, "upload uses the multipart client")
check(path == "/template/media" && options[:method] == :post, "upload path")
check(options[:body] == { "file" => { filename: "logo.png", io: io }, "groupId" => "G1" }, "upload fields")
check(options[:headers] == { "Idempotency-Key" => "key-2" }, "upload idempotency")
part = { filename: "a.jpg", io: io, content_type: "image/jpeg" }
templates.upload_media(group_id: "G1", file: part)
check(multipart.calls.last[1][:body]["file"] == part, "upload passes a file hash through")

wire = SignalHouseSms::HttpClient.new(base_url: "https://example.invalid", api_key: "k", multipart: true)
encoded = wire.send(:build_multipart_body, { "file" => { filename: "logo.png", io: StringIO.new("PNG") }, "groupId" => "G1" }, "B")
check(encoded.include?("name=\"file\"; filename=\"logo.png\"") && encoded.include?("name=\"groupId\"\r\n\r\nG1\r\n"),
      "multipart body carries file and groupId parts")

[
  -> { templates.list(group_id: nil) },
  -> { templates.create(group_id: "G1", name: nil, body: body) },
  -> { templates.get(template_id: nil, group_id: "G1") },
  -> { templates.update(template_id: "TPL1", group_id: nil) },
  -> { templates.publish(template_id: nil, group_id: "G1") },
  -> { templates.archive(template_id: "TPL1", group_id: nil) },
  -> { templates.upload_media(group_id: "G1", file: nil) }
].each_with_index { |call, index| check(raises?(SignalHouseSms::ValidationError, &call), "required parameter #{index}") }

puts "Template Ruby contracts passed (update null semantics, validate, multipart upload, required params)"
