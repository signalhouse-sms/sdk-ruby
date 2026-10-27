# frozen_string_literal: true

module SignalHouseSms
  # Voice Analytics — aggregated call metrics for the portal Voice Analytics view
  # (Voice service /voice/stats/voice-analytics). Returns per-direction summary
  # tiles (both directions) plus byDate / byNumber / byCarrier status breakdowns
  # for charts. Distinct from client.voice.call_logs, which is the raw call
  # history. Accessed via client.voice.analytics.
  class VoiceAnalytics
    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/stats/voice-analytics?...
    #
    # Get aggregated voice analytics for the current account. Optional filters
    # (camelCase keys, passed through as-is): dateFrom, dateTo, groupBy
    # (day|week|month), direction (INBOUND|OUTBOUND), callSource (comma list),
    # subgroupId, number, carrier. Summary tiles honor every filter except
    # direction; breakdowns honor all filters.
    # Returns { success, range, outbound, inbound, byDate, byNumber, byCarrier, byChannel }
    # (byChannel = per-callSource breakdown).
    def get(filters: {}, **opts)
      qs = @client.get_query_string(filters || {})
      @client.request("/voice/stats/voice-analytics#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
