# frozen_string_literal: true

require_relative "voice/sip_trunks"
require_relative "voice/sip_profiles"
require_relative "voice/programmable_voice_profiles"
require_relative "voice/number_routes"
require_relative "voice/calls"
require_relative "voice/call_logs"
require_relative "voice/analytics"
require_relative "voice/tokens"
require_relative "voice/global_voice_settings"

module SignalHouseSms
  # Voice domain — wraps the Voice service (mounted under /voice).
  #
  # Sub-resources, accessed via `client.voice.*`:
  #   * client.voice.sip_trunks                 — SIP trunk (peer-to-peer connections to PBX/carrier)
  #   * client.voice.sip_profiles               — SIP profile / endpoint (single registerable UA)
  #   * client.voice.programmable_voice_profiles — Programmable Voice Profile (route a set of numbers through Signal House)
  #   * client.voice.number_routes              — Per-number inbound route (overrides the profile and subgroup settings)
  #   * client.voice.calls                      — Outbound call origination + call log queries
  #   * client.voice.call_logs                  — Account-scoped voice call history (cost, recording, attribution)
  #   * client.voice.analytics                  — Aggregated call metrics (summary tiles + byDate/byNumber/byCarrier breakdowns)
  #   * client.voice.tokens                     — Mint ephemeral SIP credentials for the browser voice SDK
  #   * client.voice.global_voice_settings      — Account-wide voice defaults (accepted regions, max spend/min, E911)
  class Voice
    attr_reader :sip_trunks, :sip_profiles, :programmable_voice_profiles, :number_routes, :calls, :call_logs, :analytics,
                :tokens, :global_voice_settings

    def initialize(client, enable_admin)
      @sip_trunks = VoiceSipTrunks.new(client, enable_admin)
      @sip_profiles = VoiceSipProfiles.new(client, enable_admin)
      @programmable_voice_profiles = VoiceProgrammableVoiceProfiles.new(client, enable_admin)
      @number_routes = VoiceNumberRoutes.new(client, enable_admin)
      @calls = VoiceCalls.new(client, enable_admin)
      @call_logs = VoiceCallLogs.new(client, enable_admin)
      @analytics = VoiceAnalytics.new(client, enable_admin)
      @tokens = VoiceTokens.new(client, enable_admin)
      @global_voice_settings = VoiceGlobalVoiceSettings.new(client, enable_admin)
    end
  end
end
