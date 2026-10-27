# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # Programmable Voice Profiles — group a set of the account's numbers (across
  # one or more subgroups) under a single inbound call-handling decision routed
  # through Signal House's own voice servers. The same idea as a SIP trunk, but
  # without a customer SBC. A number can belong to at most one profile and is
  # mutually exclusive with SIP trunks.
  #
  # Routes mounted under /voice/api/v1/programmable-voice-profiles on the
  # Voice service. Accessed via client.voice.programmable_voice_profiles.
  class VoiceProgrammableVoiceProfiles
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/api/v1/programmable-voice-profiles
    #
    # List all Programmable Voice Profiles for the current account.
    # Returns { profiles: [...] }.
    def list(**opts)
      @client.request("/voice/api/v1/programmable-voice-profiles", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/api/v1/programmable-voice-profiles/:id
    #
    # Get a single Programmable Voice Profile by ID. Returns { profile: {...} }.
    def get(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/programmable-voice-profiles/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/api/v1/programmable-voice-profiles
    #
    # Required: name, subgroupIds (array, at least one). Optional: region,
    # routeAction (FORWARD|WEBRTC|SIP_TRUNK|SIP_PROFILE|CALL_CONTROL, default
    # FORWARD) — deliver to a PSTN number (FORWARD), ring the profile's subgroup
    # registered softphones (WEBRTC), send to a SIP trunk (SIP_TRUNK), ring a
    # registered SIP endpoint (SIP_PROFILE), or hand the call to your inbound
    # voice webhook / SHML program (CALL_CONTROL). forwardToE164 (required when
    # routeAction is FORWARD), routeSipTrunkId (required when routeAction is
    # SIP_TRUNK), routeSipProfileId (required when routeAction is SIP_PROFILE),
    # webhookUrl (inbound voice webhook / SHML program URL; required when
    # routeAction is CALL_CONTROL), forwardAfterSeconds, recordingEnabled,
    # enabled.
    # Returns { profile: {...} }.
    def create(profile_data:, **opts)
      @client.require_params("profileData" => profile_data)
      @client.request("/voice/api/v1/programmable-voice-profiles", method: :post, body: profile_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PATCH /voice/api/v1/programmable-voice-profiles/:id
    #
    # Partial update of an existing Programmable Voice Profile. Any create field
    # may be supplied: name, subgroupIds, region, routeAction
    # (FORWARD|WEBRTC|SIP_TRUNK|SIP_PROFILE|CALL_CONTROL), forwardToE164,
    # routeSipTrunkId (required when routeAction is SIP_TRUNK),
    # routeSipProfileId (required when routeAction is SIP_PROFILE),
    # webhookUrl (inbound voice webhook / SHML program URL; required when
    # routeAction is CALL_CONTROL), forwardAfterSeconds, recordingEnabled, enabled.
    # Returns { profile: {...} }.
    def update(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/programmable-voice-profiles/#{safe_id}", method: :patch, body: update_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/api/v1/programmable-voice-profiles/:id/toggle-active
    #
    # Toggle a profile active/inactive. Returns { profile: {...} }.
    def toggle_active(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/programmable-voice-profiles/#{safe_id}/toggle-active", method: :post, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # DELETE /voice/api/v1/programmable-voice-profiles/:id
    #
    # Delete a Programmable Voice Profile. Its number assignments cascade away,
    # so those numbers fall back to subgroup/global routing.
    # Returns { message: "..." }.
    def delete(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/programmable-voice-profiles/#{safe_id}", method: :delete, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/api/v1/programmable-voice-profiles/:id/assign-number
    #
    # Assign a phone number (by E.164) to this profile. Rejected if the number
    # is already configured on a SIP trunk/endpoint or another profile — it
    # must be de-configured there first (mutual exclusivity).
    # Returns { profile: {...} }.
    def assign_number(id:, e164:, **opts)
      @client.require_params("id" => id, "e164" => e164)
      safe_id = CGI.escape(id.to_s)
      @client.request(
        "/voice/api/v1/programmable-voice-profiles/#{safe_id}/assign-number",
        method: :post,
        body: { e164: e164 },
        token: opts[:token],
        headers: HttpClient.headers_for(opts),
      )
    end

    # POST /voice/api/v1/programmable-voice-profiles/:id/unassign-number
    #
    # Unassign a phone number (by E.164) from this profile.
    # Returns { profile: {...} }.
    def unassign_number(id:, e164:, **opts)
      @client.require_params("id" => id, "e164" => e164)
      safe_id = CGI.escape(id.to_s)
      @client.request(
        "/voice/api/v1/programmable-voice-profiles/#{safe_id}/unassign-number",
        method: :post,
        body: { e164: e164 },
        token: opts[:token],
        headers: HttpClient.headers_for(opts),
      )
    end
  end
end
