# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # Call Logs — the account-scoped voice call history (Voice service
  # /voice/api/v1/call-logs). Distinct from client.voice.calls, which is the
  # Twilio-compatible programmatic call-control surface; this is the richer log
  # read surface with cost, recording, and voice-config attribution used by the
  # portal Call Logs view. Accessed via client.voice.call_logs.
  class VoiceCallLogs
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/api/v1/call-logs?...
    #
    # List call logs for the current account, paginated and filterable.
    # Optional filters (camelCase keys, passed through as-is): page, limit,
    # direction, status, callSource, subgroupId, sipTrunkId, from, to, q,
    # sentiment, voicemail, dateFrom, dateTo, sort, order.
    # Returns { success, data: [...call logs], meta: { total, page, limit, totalPages } }.
    def list(filters: {}, **opts)
      qs = @client.get_query_string(filters || {})
      @client.request("/voice/api/v1/call-logs#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/api/v1/call-logs/:id
    #
    # Get a single call log by its UUID or callId.
    # Returns { success, data: { ...call log } }.
    def get(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/call-logs/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/api/v1/call-logs/:id/recording
    #
    # Get a short-TTL presigned playback URL for a call's recording. Account-scoped
    # — only the owning account can presign. 404 if the call has no recording.
    # Returns { success, data: { callId, url, expiresIn } }.
    def get_recording(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/call-logs/#{safe_id}/recording", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PATCH /voice/api/v1/call-logs/:id/voicemail-read
    #
    # Mark a voicemail (a call log with a recording) read or unread. Account-scoped.
    # Pass read: true to mark read (default), read: false to mark unread.
    # Returns { success, data: { id, voicemailReadAt } }.
    def mark_voicemail_read(id:, read: true, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request(
        "/voice/api/v1/call-logs/#{safe_id}/voicemail-read",
        method: :patch,
        body: { read: read },
        token: opts[:token],
        headers: HttpClient.headers_for(opts)
      )
    end
  end
end
