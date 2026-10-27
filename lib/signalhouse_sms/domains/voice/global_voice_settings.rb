# frozen_string_literal: true

module SignalHouseSms
  # Global Voice Settings — account-wide voice defaults (accepted regions, max
  # spend per minute, E911). SIP trunks and Programmable Voice Profiles override
  # these. Calls the Voice service mounted under /voice. Accessed via
  # client.voice.global_voice_settings.
  class VoiceGlobalVoiceSettings
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/api/v1/global-voice-settings
    #
    # Get the current account's global voice settings. Returns data: null if the
    # account has never configured them (defaults apply).
    # Returns { success, data: { accountId, acceptedRegions, maxSpendPerMinute, e911Enabled, ... } | null }.
    def get(**opts)
      @client.request("/voice/api/v1/global-voice-settings", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PUT /voice/api/v1/global-voice-settings
    #
    # Upsert the account's global voice settings. Partial — only the fields you
    # provide are written; omitted fields are preserved. settings_data keys
    # (camelCase): acceptedRegions (array), maxSpendPerMinute (numeric|nil),
    # e911Enabled (bool).
    # Returns { success, data: { ...settings } }.
    def update(settings_data:, **opts)
      @client.require_params("settingsData" => settings_data)
      @client.request(
        "/voice/api/v1/global-voice-settings",
        method: :put,
        body: settings_data,
        token: opts[:token],
        headers: HttpClient.headers_for(opts)
      )
    end
  end
end
