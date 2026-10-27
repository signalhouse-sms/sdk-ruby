# frozen_string_literal: true

module SignalHouseSms
  class Webhooks
    def initialize(client, _enable_admin)
      @client = client
    end

    # GET /webhook?...
    # Each returned endpoint carries "hasSigningSecret" (bool) instead of the signing secret
    # itself — see create_webhook.
    def get_webhooks(id: nil, group_id: nil, endpoint_type: nil, phone_number: nil, page: nil, limit: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(id: id, groupId: group_id, endpointType: endpoint_type, phoneNumber: phone_number, page: page, limit: limit)
      @client.request("/webhook#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /webhook
    # Response includes a "signingSecret" (plaintext HMAC-SHA256 secret) used to sign every delivery
    # to this endpoint via the X-SignalHouse-Signature header. Returned exactly once, here — store it
    # now, it is never exposed again by any read.
    #
    # webhook_data "authType" is one of "NONE" (default), "BASIC", "API_KEY", "OAUTH2" or "HMAC". "HMAC"
    # sends no credentials (the receiver authenticates by the signature alone) and must be sent without
    # "credentials" or "apiHeaderPrefix".
    #
    # webhook_data "eventSettings" holds per-event options keyed by event name: "NUMBER_HEALTH_BELOW_THRESHOLD"
    # and "CAMPAIGN_HEALTH_BELOW_THRESHOLD" each take { "threshold" => n }, the 7-day health score (1.5–10, in
    # 0.5 steps) below which the event fires. A subscribed health event without a threshold is stored with
    # the default, 6.
    def create_webhook(webhook_data:, **opts)
      @client.require_params("webhookData" => webhook_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/webhook", method: :post, body: webhook_data, token: token, headers: headers)
    end

    # PUT /webhook/:id
    # Like every other read of a webhook, the response carries "hasSigningSecret" (bool), never the
    # signing secret itself — see create_webhook.
    #
    # Switching "authType" to "NONE" or "HMAC" clears the stored credentials. "HMAC" is rejected for an
    # endpoint with no signing secret; call rotate_webhook_secret first.
    #
    # update_data "eventSettings" changes per-event options by event name ("NUMBER_HEALTH_BELOW_THRESHOLD",
    # "CAMPAIGN_HEALTH_BELOW_THRESHOLD", each { "threshold" => n }, 1.5–10 in 0.5 steps); events you omit
    # keep their stored settings.
    def update_webhook(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/webhook/#{safe_id}", method: :put, body: update_data, token: token, headers: headers)
    end

    # POST /webhook/:id/rotate-secret
    # Rotate a webhook's signing secret (or give a webhook created before signing its first one). The
    # response includes the new plaintext signingSecret, returned this one time only. The replaced secret
    # keeps working for grace_seconds (default 86400, max 604800, 0 = stop now).
    def rotate_webhook_secret(id:, grace_seconds: nil, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      body = grace_seconds.nil? ? {} : { "graceSeconds" => grace_seconds }
      @client.request("/webhook/#{safe_id}/rotate-secret", method: :post, body: body, token: token, headers: headers)
    end

    # DELETE /webhook/:id
    def delete_webhook(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/webhook/#{safe_id}", method: :delete, token: token, headers: headers)
    end
  end
end
