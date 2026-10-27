# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # Voice calls — REST API for placing outbound calls and inspecting call logs.
  # Wraps the Voice service's /voice/v1/calls surface. Accessed via client.voice.calls.
  #
  # Origination modes:
  #   * Single-leg (no trunk/profile/identity): Twilio-style direct outbound — dial
  #     `to` from caller-ID `from`. The `from` must be an account-owned number.
  #   * SIP trunk (sip_trunk_id): route via a configured trunk; the trunk's
  #     auth/ACL governs caller-ID rules.
  #   * Two-leg-with-bridge (sip_profile_id OR to_identity): ring the SDK-
  #     registered endpoint first, then dial `to` and bridge. `to_identity`
  #     resolves to the most recently-minted unexpired ephemeral identity for
  #     that name.
  class VoiceCalls
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # POST /voice/v1/calls
    #
    # Required: call_data with `to` and `from`. Optional: sip_trunk_id,
    # sip_profile_id, to_identity, answer_url, answer_method, status_callback,
    # status_callback_method, recording_enabled, transcription_enabled,
    # ivr_flow_id, metadata.
    def create(call_data:, **opts)
      @client.require_params("callData" => call_data)
      @client.request("/voice/v1/calls", method: :post, body: call_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/v1/calls?...
    #
    # Optional filters: page, limit, status, direction, from, to, date_from, date_to.
    # Filter keys are passed through as-is (snake_case, matching the Voice service API).
    def list(filters: {}, **opts)
      qs = @client.get_query_string(filters || {})
      @client.request("/voice/v1/calls#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/v1/calls/:id
    def get(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/v1/calls/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/v1/calls/:id/hangup
    #
    # Optional reason ("NORMAL", "BUSY", "NO_ANSWER", "REJECTED"). Defaults to NORMAL server-side.
    def hangup(id:, reason: nil, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      body = reason ? { reason: reason } : {}
      @client.request("/voice/v1/calls/#{safe_id}/hangup", method: :post, body: body, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
