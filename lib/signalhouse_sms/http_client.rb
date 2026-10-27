# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "cgi"

module SignalHouseSms
  class HttpClient
    attr_reader :base_url, :api_key, :multipart

    def initialize(base_url:, api_key:, multipart: false)
      @base_url = base_url.chomp("/")
      @api_key = api_key
      @multipart = multipart
    end

    # Per-request headers from a domain method's opts: :headers, plus :idempotency_key as the Idempotency-Key header.
    #
    # @param opts [Hash] Request options (:token, :headers, :idempotency_key)
    # @return [Hash, nil] Headers to send, or nil when there are none
    def self.headers_for(opts)
      key = opts[:idempotency_key]
      return opts[:headers] if key.nil? || key.to_s.empty?

      (opts[:headers] || {}).merge("Idempotency-Key" => key.to_s)
    end

    # Build a query string from a hash of parameters.
    # Skips nil values. Arrays are joined with commas.
    def get_query_string(params)
      return "" if params.nil? || params.empty?

      parts = []
      params.each do |key, value|
        next if value.nil?

        str_value = if value.is_a?(Array)
                      value.map { |v| CGI.escape(v.to_s) }.join(",")
                    else
                      CGI.escape(value.to_s)
                    end
        parts << "#{CGI.escape(key.to_s)}=#{str_value}"
      end

      parts.empty? ? "" : "?#{parts.join("&")}"
    end

    # Validate that all named fields are present (non-nil).
    # fields is a Hash like { "paramName" => value }.
    def require_params(fields)
      fields.each do |name, value|
        raise SignalHouseSms::ValidationError.new(name.to_s) if value.nil?
      end
    end

    # Perform an HTTP request.
    #
    # @param path [String] The API path (e.g. "/auth")
    # @param method [Symbol] :get, :post, :put, :patch, :delete
    # @param body [Hash, nil] Request body (JSON) or form data hash for multipart
    # @param token [String, nil] Bearer token override; falls back to api_key
    # @param headers [Hash, nil] Additional headers to merge
    # @return [Hash] Standardized response hash
    def request(path, method:, body: nil, token: nil, headers: nil)
      uri = URI("#{@base_url}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 30
      http.read_timeout = 60

      req = build_request(uri, method, body)

      # Auth header
      auth_token = token || @api_key
      req["Authorization"] = "Bearer #{auth_token}" if auth_token

      # Merge extra headers
      if headers.is_a?(Hash)
        headers.each { |k, v| req[k.to_s] = v.to_s }
      end

      response = http.request(req)
      parse_response(response)
    rescue StandardError => e
      raise e if e.is_a?(SignalHouseSms::Error)
      raise SignalHouseSms::Error.new("HTTP request failed: #{e.message}")
    end

    private

    def build_request(uri, method, body)
      case method
      when :get
        req = Net::HTTP::Get.new(uri)
        req["Content-Type"] = "application/json"
        req
      when :post
        req = Net::HTTP::Post.new(uri)
        set_body(req, body)
        req
      when :put
        req = Net::HTTP::Put.new(uri)
        set_body(req, body)
        req
      when :patch
        req = Net::HTTP::Patch.new(uri)
        set_body(req, body)
        req
      when :delete
        req = Net::HTTP::Delete.new(uri)
        set_body(req, body) if body
        req
      else
        raise SignalHouseSms::Error.new("Unsupported HTTP method: #{method}")
      end
    end

    def set_body(req, body)
      if @multipart && body.is_a?(Hash)
        boundary = "SignalHouse#{SecureRandom.hex(16)}"
        req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        req.body = build_multipart_body(body, boundary)
      else
        req["Content-Type"] = "application/json"
        req.body = body.to_json if body
      end
    end

    def build_multipart_body(fields, boundary)
      body = +""
      fields.each do |key, value|
        next if value.nil?

        if value.is_a?(Hash) && value[:filename] && value[:io]
          # File upload part
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{value[:filename]}\"\r\n"
          content_type = value[:content_type] || "application/octet-stream"
          body << "Content-Type: #{content_type}\r\n"
          body << "\r\n"
          io = value[:io]
          body << (io.respond_to?(:read) ? io.read : io.to_s)
          body << "\r\n"
        elsif value.is_a?(Array) && value.all? { |v| v.is_a?(Hash) && v[:filename] && v[:io] }
          # Array of file uploads (e.g. images)
          value.each do |file|
            body << "--#{boundary}\r\n"
            body << "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{file[:filename]}\"\r\n"
            content_type = file[:content_type] || "application/octet-stream"
            body << "Content-Type: #{content_type}\r\n"
            body << "\r\n"
            io = file[:io]
            body << (io.respond_to?(:read) ? io.read : io.to_s)
            body << "\r\n"
          end
        else
          # Regular field
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"#{key}\"\r\n"
          body << "\r\n"
          body << value.to_s
          body << "\r\n"
        end
      end
      body << "--#{boundary}--\r\n"
      body
    end

    def parse_response(response)
      status = response.code.to_i
      body = response.body

      parsed = begin
        JSON.parse(body)
      rescue JSON::ParserError
        { "rawBody" => body }
      end

      if status >= 200 && status < 300
        { "success" => true, "data" => parsed, "status" => status }
      else
        error_message = if parsed.is_a?(Hash)
                          parsed["error"] || parsed["message"] || parsed["externalMessage"] || body
                        else
                          body
                        end
        { "success" => false, "error" => error_message, "status" => status }
      end
    end
  end
end
