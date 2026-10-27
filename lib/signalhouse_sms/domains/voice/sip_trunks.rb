# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # SIP Trunks — peer-to-peer SIP connections to a customer PBX or carrier.
  # Routes mounted under /voice/sip-trunks on the Voice service.
  # Accessed via client.voice.sip_trunks.
  class VoiceSipTrunks
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/sip-trunks
    def list(**opts)
      @client.request("/voice/sip-trunks", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/sip-trunks/:id
    def get(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-trunks/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/sip-trunks
    #
    # Required: name, region, connectionType ("IP_AUTH" or "REGISTRATION").
    # Optional: allowedIps, transport, maxSpendPerMinute, destinationHosts, sourceHosts.
    # Registration trunks return a one-time-visible password on the response.
    def create(trunk_data:, **opts)
      @client.require_params("trunkData" => trunk_data)
      @client.request("/voice/sip-trunks", method: :post, body: trunk_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PATCH /voice/sip-trunks/:id
    def update(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-trunks/#{safe_id}", method: :patch, body: update_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # DELETE /voice/sip-trunks/:id
    def delete(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-trunks/#{safe_id}", method: :delete, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/sip-trunks/:id/toggle-active
    def toggle_active(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-trunks/#{safe_id}/toggle-active", method: :post, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/sip-trunks/:id/regenerate-password
    #
    # Regenerate the SIP password for a REGISTRATION-type trunk. The old
    # password stops working immediately. Returns { password: "..." }.
    def regenerate_password(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-trunks/#{safe_id}/regenerate-password", method: :post, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/sip-trunks/:id/assign-numbers
    #
    # Assign one or more phone numbers to a SIP trunk for inbound routing.
    def assign_numbers(id:, phone_numbers:, **opts)
      @client.require_params("id" => id, "phoneNumbers" => phone_numbers)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-trunks/#{safe_id}/assign-numbers", method: :post, body: { phoneNumbers: phone_numbers }, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/sip-trunks/:id/unassign-numbers
    #
    # Unassign one or more phone numbers from a SIP trunk.
    def unassign_numbers(id:, phone_numbers:, **opts)
      @client.require_params("id" => id, "phoneNumbers" => phone_numbers)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-trunks/#{safe_id}/unassign-numbers", method: :post, body: { phoneNumbers: phone_numbers }, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/sip-trunks/pops
    def get_pops(**opts)
      @client.request("/voice/sip-trunks/pops", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
