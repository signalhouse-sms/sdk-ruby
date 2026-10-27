# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # Number Routes — one inbound route set directly on a single phone number. A
  # number's own route takes priority over its Programmable Voice Profile and
  # subgroup voice settings.
  #
  # Routes mounted under /voice/api/v1/numbers/:e164/route on the Voice service
  # service. Accessed via client.voice.number_routes.
  class VoiceNumberRoutes
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/api/v1/numbers/:e164/route
    #
    # Get a number's own route and the routing currently in effect for it.
    # e164 leading + optional. Roles: api, admin, developer, billing, user.
    # Returns { e164:, route: {...} | nil, effective: {...} }.
    def get(e164:, **opts)
      @client.require_params("e164" => e164)
      safe_e164 = CGI.escape(e164.to_s)
      @client.request("/voice/api/v1/numbers/#{safe_e164}/route", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PUT /voice/api/v1/numbers/:e164/route
    #
    # Set (create or replace) a number's route. The whole route is replaced:
    # fields the new routeAction doesn't use are cleared. Roles: api, admin,
    # developer.
    #
    # route_data keys (camelCase, as the API expects): routeAction (required;
    # FORWARD|WEBRTC|SIP_TRUNK|SIP_PROFILE|CALL_CONTROL|AI|VOICEMAIL),
    # forwardToE164 (required for FORWARD, or the WEBRTC no-answer destination
    # when noAnswerAction is FORWARD), noAnswerAction (WEBRTC only:
    # VOICEMAIL|FORWARD|KEEP_RINGING, default VOICEMAIL), noAnswerSeconds (WEBRTC
    # only: 5-120, default 20), routeSipTrunkId (required for SIP_TRUNK),
    # routeSipProfileId (required for SIP_PROFILE), webhookUrl (SHML program URL;
    # required for CALL_CONTROL), routeAgentProfileId (AI agent profile id, AGP...;
    # required for AI), recordingEnabled (bool).
    # Returns { e164:, route: {...}, effective: {...} }.
    def set(e164:, route_data:, **opts)
      @client.require_params("e164" => e164, "routeData" => route_data)
      safe_e164 = CGI.escape(e164.to_s)
      @client.request("/voice/api/v1/numbers/#{safe_e164}/route", method: :put, body: route_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # DELETE /voice/api/v1/numbers/:e164/route
    #
    # Remove a number's own route. The number falls back to its Programmable
    # Voice Profile, subgroup voice settings, or the default. Roles: api, admin,
    # developer.
    # Returns { e164:, route: nil, effective: {...} }.
    def delete(e164:, **opts)
      @client.require_params("e164" => e164)
      safe_e164 = CGI.escape(e164.to_s)
      @client.request("/voice/api/v1/numbers/#{safe_e164}/route", method: :delete, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
