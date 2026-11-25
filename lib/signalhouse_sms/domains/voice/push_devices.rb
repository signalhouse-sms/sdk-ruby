# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # Mobile Push Devices — your mobile app registers each device so incoming
  # calls wake it.
  #
  # These methods are called by the app with the user's voice token, not the API
  # key or a dashboard token: pass the token from client.voice.tokens.create
  # (minted with a subgroupId) as the token: keyword, which the SDK sends as the
  # bearer token. The device is tied to that token's identity.
  #
  #   client.voice.push_devices.register(
  #     device_data: { provider: "fcm", deviceToken: fcm_token },
  #     token: voice_token
  #   )
  #
  # Routes mounted under /voice/api/v1/push-devices on the Voice service.
  # Accessed via client.voice.push_devices.
  class VoicePushDevices
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # POST /voice/api/v1/push-devices
    #
    # Register this device for push. Call it after each token mint and whenever
    # the OS gives the app a new push token. A push token already registered to
    # another user moves to this one. device_data keys (camelCase): provider
    # ("apns" for iOS with a PushKit VoIP token, "fcm" for Android with a
    # Firebase registration token), deviceToken, environment (apns only:
    # "production" (default) or "sandbox" for development builds), appId (the
    # bundle ID or Firebase project ID; only needed when the account has several
    # apps for the provider). Pass the voice token as token:.
    # Returns { success, data: { id, identity, provider, environment, appId, registeredAt } } (201).
    def register(device_data:, **opts)
      @client.require_params("deviceData" => device_data)
      @client.request("/voice/api/v1/push-devices", method: :post, body: device_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # DELETE /voice/api/v1/push-devices/:deviceToken
    #
    # Unregister this device, e.g. when the user signs out. The device token is
    # URL-encoded here, since FCM tokens contain ":". Pass the voice token as token:.
    # Returns { success, data: { removed } }.
    def unregister(device_token:, **opts)
      @client.require_params("deviceToken" => device_token)
      safe_token = CGI.escape(device_token.to_s)
      @client.request("/voice/api/v1/push-devices/#{safe_token}", method: :delete, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/api/v1/push-devices/deliveries?limit=
    #
    # The pushes recently sent to the voice token's user, newest first (kept 7
    # days), for debugging. limit is 1 to 100 (the service defaults to 20). Pass
    # the voice token as token:.
    # Returns { success, data: [{ id, callUuid, provider, kind, status, error, createdAt }] }.
    def list_deliveries(limit: nil, **opts)
      qs = @client.get_query_string({ limit: limit })
      @client.request("/voice/api/v1/push-devices/deliveries#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
