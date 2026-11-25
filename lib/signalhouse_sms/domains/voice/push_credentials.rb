# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # Mobile Push Credentials — the Apple APNs auth key and Firebase service
  # account the Voice service uses to wake your mobile app for incoming calls.
  # One credential per app; secrets are encrypted and never returned (responses
  # show a fingerprint instead).
  #
  # credential_data is one of (camelCase keys):
  #   * Apple (iOS): { provider: "apns", name:, keyId:, teamId:, bundleId:, privateKey: }
  #     keyId is the 10-character key ID of the APNs auth key, teamId your
  #     10-character Apple developer team ID, privateKey the contents of the .p8
  #     file. VoIP pushes go to the bundle ID's .voip topic.
  #   * Firebase (Android): { provider: "fcm", name:, serviceAccount: } where
  #     serviceAccount is the service account key file, as its JSON text or a Hash.
  # name is an optional label, up to 100 characters.
  #
  # Routes mounted under /voice/api/v1/push-credentials on the Voice service.
  # Accessed via client.voice.push_credentials.
  class VoicePushCredentials
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/api/v1/push-credentials
    #
    # List the account's push credentials (metadata only).
    # Returns { success, data: [{ id, provider, name, appId, keyId, teamId, bundleId,
    # projectId, clientEmail, fingerprint, createdAt, updatedAt }] }.
    def list(**opts)
      @client.request("/voice/api/v1/push-credentials", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/api/v1/push-credentials/:id
    #
    # Get one push credential (metadata only).
    # Returns { success, data: { ...credential } }.
    def get(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/push-credentials/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/api/v1/push-credentials
    #
    # Upload push credentials for one app: an Apple APNs auth key, or a Firebase
    # service account (see the class comment). The key is checked on upload.
    # Returns { success, data: { ...credential } } (201).
    def create(credential_data:, **opts)
      @client.require_params("credentialData" => credential_data)
      @client.request("/voice/api/v1/push-credentials", method: :post, body: credential_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PUT /voice/api/v1/push-credentials/:id
    #
    # Replace a credential's key or service account (and name). Same body as
    # create; the provider cannot change. Registered devices keep working with
    # the new key.
    # Returns { success, data: { ...credential } }.
    def update(id:, credential_data:, **opts)
      @client.require_params("id" => id, "credentialData" => credential_data)
      safe_id = CGI.escape(id.to_s)
      @client.request(
        "/voice/api/v1/push-credentials/#{safe_id}",
        method: :put,
        body: credential_data,
        token: opts[:token],
        headers: HttpClient.headers_for(opts)
      )
    end

    # DELETE /voice/api/v1/push-credentials/:id
    #
    # Delete a credential and every device registered for that app; their calls
    # stop being pushed.
    # Returns { success }.
    def delete(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/push-credentials/#{safe_id}", method: :delete, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
