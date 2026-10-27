# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # SIP Profiles / endpoints — single registerable SIP UAs (desk phones,
  # softphones, SIP apps) that register to Signal House with username +
  # password. Distinct from a SIP trunk (peer-to-peer link to a PBX/carrier).
  #
  # Routes mounted under /voice/sip-profiles on the Voice service.
  # Accessed via client.voice.sip_profiles.
  class VoiceSipProfiles
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/sip-profiles
    def list(**opts)
      @client.request("/voice/sip-profiles", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/sip-profiles/:id
    #
    # Response does NOT include the password — use #get_password to retrieve it.
    def get(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-profiles/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/sip-profiles/:id/password
    #
    # Fetch the SIP password for this profile. Returns { password: "..." }.
    def get_password(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-profiles/#{safe_id}/password", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/sip-profiles/transports
    def get_transports(**opts)
      @client.request("/voice/sip-profiles/transports", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/sip-profiles
    #
    # Required: name. Optional: recordingAllowed, transcriptionEnabled, sentimentFlag.
    # The server generates the SIP username and password; the password is
    # returned at the TOP LEVEL of the response (not nested in sipProfile)
    # and is the only chance to surface it without an explicit get_password call.
    def create(profile_data:, **opts)
      @client.require_params("profileData" => profile_data)
      @client.request("/voice/sip-profiles", method: :post, body: profile_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PATCH /voice/sip-profiles/:id
    #
    # To rotate the password, pass a new `password` value — there is no
    # dedicated regenerate endpoint.
    def update(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-profiles/#{safe_id}", method: :patch, body: update_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # DELETE /voice/sip-profiles/:id
    def delete(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/sip-profiles/#{safe_id}", method: :delete, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/sip-profiles/:id/assign-number
    #
    # Assign a phone number to this SIP profile. Prefer e164;
    # the legacy phone_number_id (a Voice service
    # phone-number UUID) is still accepted. Provide at least one of the two.
    def assign_number(id:, phone_number_id: nil, e164: nil, **opts)
      @client.require_params("id" => id)
      @client.require_params("e164" => e164) if e164.nil? && phone_number_id.nil?
      safe_id = CGI.escape(id.to_s)
      body = e164 ? { e164: e164 } : { phoneNumberId: phone_number_id }
      @client.request(
        "/voice/sip-profiles/#{safe_id}/assign-number",
        method: :post,
        body: body,
        token: opts[:token],
        headers: HttpClient.headers_for(opts),
      )
    end

    # POST /voice/sip-profiles/:id/unassign-number
    #
    # Unassign a phone number from this SIP profile. Prefer e164; the legacy
    # phone_number_id (a Voice service phone-number UUID) is still accepted.
    # Provide at least one of the two.
    def unassign_number(id:, phone_number_id: nil, e164: nil, **opts)
      @client.require_params("id" => id)
      @client.require_params("e164" => e164) if e164.nil? && phone_number_id.nil?
      safe_id = CGI.escape(id.to_s)
      body = e164 ? { e164: e164 } : { phoneNumberId: phone_number_id }
      @client.request(
        "/voice/sip-profiles/#{safe_id}/unassign-number",
        method: :post,
        body: body,
        token: opts[:token],
        headers: HttpClient.headers_for(opts),
      )
    end
  end
end
