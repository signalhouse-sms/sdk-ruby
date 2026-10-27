# frozen_string_literal: true

module SignalHouseSms
  # Voice tokens — mints ephemeral SIP identities the browser/mobile voice SDK
  # uses to register against the SignalHouse voice fabric. Wraps the Voice service's
  # /voice/tokens endpoint. Accessed via client.voice.tokens.
  #
  # Customer flow:
  #   1. Backend calls client.voice.tokens.create(token_data: { identity: "alice", ttl: 1800 })
  #      and returns the resulting `token` to the customer's browser/app.
  #   2. Browser SDK registers using the embedded sip_credentials.
  #   3. Outbound calls from the SDK go through OpenSIPS -> Asterisk -> carrier;
  #      the server-side calls.create(call_data: { to_identity: "alice", ... }) flow
  #      can also ring this identity for click-to-call patterns.
  class VoiceTokens
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # POST /voice/tokens
    #
    # All token_data fields are optional: identity (logical name; defaults to
    # "anonymous"), ttl (seconds, clamped server-side), grants (capability
    # grants). Returns { token, identity, expires_at, sip_credentials }.
    def create(token_data: {}, **opts)
      @client.request("/voice/tokens", method: :post, body: token_data || {}, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
