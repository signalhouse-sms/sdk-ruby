# frozen_string_literal: true

require "json"

module SignalHouseSms
  # Messages domain.
  #
  # Date-range parameters (start_date, end_date) on list and analytics methods
  # accept ISO-8601 date or timestamp strings, bound per date_bounds. A bare date is
  # always that whole UTC day. A timestamp is widened to its whole UTC day in "day"
  # mode and bound as the instant it names, in whatever
  # offset it was written ("2026-09-14T00:00:00-04:00" is 04:00Z), in "exact" mode,
  # where day buckets also align to the offset end_date carries. Omitted, date_bounds is "day".
  # Business-number filters and SMS/MMS senders accept digits-only 5-6 digit
  # Short Codes or 10+ digit long numbers. Recipient numbers remain 10+ digits.
  class Messages
    def initialize(client, multipart_client, _enable_admin)
      @client = client
      @multipart_client = multipart_client
    end

    # Estimate Canadian or UK retail cost in microdollars; no charge or send. A Ready Canadian sender takes SMS or MMS
    # to Canadian or US recipients; a UK (+44) virtual long code takes SMS only to GB mobile recipients (10-15 digits).
    # The response region is "CA" or "GB". Unavailable unless that region is enabled for the environment. The sender
    # may also be a READY alphanumeric sender ID (e.g. "ACME"; UK recipients, SMS only); its estimate counts the
    # "\nOpt out: sihou.io/o/{code}" footer the server appends to every such message.
    def estimate_message(sender_phone_number:, recipient_phone_numbers:, message_body:, message_type: "SMS", **opts)
      @client.request("/message/estimate", method: :post, body: { senderPhoneNumber: sender_phone_number, recipientPhoneNumbers: recipient_phone_numbers, messageBody: message_body, messageType: message_type }, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /message?...
    # message_type accepts a single value or array (e.g. ["SMS", "MMS"]).
    # Allowed values: SMS, MMS, RCS, WHATSAPP, VIBER, P2P. When omitted, defaults to all non-P2P types.
    # channel filters by "tenDLC", "virtualLongCode", "tollFree", "shortCode", or "p2p" (single value or array); older messages
    # without a stored channel count as tenDLC.
    # sentiment_label filters by sentiment bucket: "positive", "neutral", or "negative" (single value or array).
    # It is applied as the sentimentScore range the label threshold produces, so unscored messages match no
    # bucket and outbound messages (never scored) are excluded.
    # sort_field accepts "createdAt", "segmentCount", "status", or "sentimentScore".
    # Inbound messages in the response also carry sentimentScore (-100..100, nil when unscored),
    # sentimentLabel ("positive", "neutral" or "negative", nil when sentimentScore is nil) and
    # sentimentScoredAt. Outbound messages are never scored.
    # registration_id filters to messages attributed to these registrations (single value or array). It cannot be
    # combined with campaign_id, and each id must belong to the group.
    # date_bounds is which contract binds start_date/end_date. "day": each bound is widened to its whole UTC day
    #. "exact": a timestamp is bound as the instant it names and a bare date is its
    # whole UTC day. Omitted: "day".
    # error_code filters FAILED messages by Signal House error code (single value or array); "OUT" is the campaign
    # opt-out, displayed as RECIPIENT_OPTED_OUT. Carrier codes are not filterable here.
    # sender_phone_number/recipient_phone_number accept a plain digits-only exact value, or a value
    # containing % as a wildcard for a partial match (e.g. "%1234" matches numbers ending in 1234);
    # 3-15 digits are required alongside any %.
    # region filters by "US", "GB", or "CA" (any case of "UK"/"GB"/"GBR"/"United Kingdom" is accepted for GB; single value or array). region_scopes is an
    # array of OR-ed branches { region:, channels:, brandId:?, campaignId:?, phoneNumber:? } (channels: tenDLC,
    # virtualLongCode, tollFree, shortCode, p2p), JSON-encoded for the query; a String is sent as-is and [] matches
    # nothing.
    def get_messages(id: nil, campaign_id: nil, registration_id: nil, brand_id: nil, subgroup_id: nil, group_id: nil, phone_number: nil, sender_phone_number: nil, recipient_phone_number: nil, status: nil, direction: nil, message_type: nil, channel: nil, region: nil, region_scopes: nil, carrier: nil, sentiment_label: nil, error_code: nil, start_date: nil, end_date: nil, sort_field: nil, sort_order: nil, page: nil, limit: nil, date_bounds: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(
        id: id, campaignId: campaign_id, registrationId: registration_id, brandId: brand_id, subgroupId: subgroup_id,
        groupId: group_id, phoneNumber: phone_number, senderPhoneNumber: sender_phone_number,
        recipientPhoneNumber: recipient_phone_number, status: status, direction: direction,
        messageType: message_type, channel: channel, region: region, regionScopes: encode_region_scopes(region_scopes), carrier: carrier, sentimentLabel: sentiment_label,
        errorCode: error_code, startDate: start_date, endDate: end_date,
        sortField: sort_field, sortOrder: sort_order, page: page, limit: limit, dateBounds: date_bounds
      )
      @client.request("/message#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /message/analytics?...
    # channel filters by "tenDLC", "virtualLongCode", "tollFree", "shortCode", or "p2p" (single value or array); a tenDLC selection
    # also includes older messages with no channel, and p2p is matched by carrier.
    # subgroup_id, brand_id, campaign_id, phone_number and carrier each accept a single value, an array, or a
    # comma-separated string; group_id is single-valued.
    # The response also includes inbound-message sentiment for the requested scope: sentimentScore
    # (volume-weighted average of every scored inbound message in range, -100..100, nil when nothing was
    # scored), sentimentLabel, sentimentScoredCount, sentimentPositive, sentimentNeutral and sentimentNegative.
    # sentimentScore is an average, so it must never be summed across responses.
    # message_type scopes the SENTIMENT figures to "SMS", "MMS" or "P2P" (single value, array, or comma-separated
    # string); omit for all scored types. It does NOT narrow the message counts, which are always returned split per type.
    # carrier_family filters by the recipient's resolved carrier family (Default, ATT, TMobile, Verizon, USCellular, GoogleVoice, ClearSky, Interop, RogueMobile, P2P, Standard, IceWireless, Bell, Rogers, Telus, Videotron, SaskTel, Eastlink, Fibernetics); single value, array,
    # or comma-separated string. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400 -- omit the parameter unless it is wanted.
    # date_bounds is which contract binds start_date/end_date. "day": each bound is widened to its whole UTC day
    #. "exact": a timestamp is bound as the instant it names and a bare date is its
    # whole UTC day. Omitted: "day".
    # region filters by "US", "GB", or "CA" (any case of "UK"/"GB"/"GBR"/"United Kingdom" is accepted for GB; single value or array). region_scopes is an
    # array of OR-ed branches { region:, channels:, brandId:?, campaignId:?, phoneNumber:? } (channels: tenDLC,
    # virtualLongCode, tollFree, shortCode, p2p), JSON-encoded for the query; a String is sent as-is and [] matches
    # nothing. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400.
    # registration_id filters to traffic attributed to these registrations (hourly analytics only; a 400 while hourly
    # reads are off); single value or array. A phone_number filter takes precedence.
    def get_analytics(group_id: nil, subgroup_id: nil, brand_id: nil, campaign_id: nil, registration_id: nil, phone_number: nil, carrier: nil, carrier_family: nil, start_date: nil, end_date: nil, channel: nil, region: nil, region_scopes: nil, message_type: nil, date_bounds: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, brandId: brand_id,
        campaignId: campaign_id, registrationId: registration_id, phoneNumber: phone_number, carrier: carrier, carrierFamily: carrier_family,
        startDate: start_date, endDate: end_date, channel: channel, region: region, regionScopes: encode_region_scopes(region_scopes), messageType: message_type, dateBounds: date_bounds
      )
      @client.request("/message/analytics#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /message/analytics/detail?...
    # channel filters by "tenDLC", "virtualLongCode", "tollFree", "shortCode", or "p2p" (single value or array); a tenDLC selection
    # also includes older messages with no channel, and p2p is a real channel here.
    # subgroup_id, brand_id, campaign_id, phone_number and carrier each accept a single value, an array, or a
    # comma-separated string; group_id is single-valued.
    # cardTotals and every byDate/byPhoneNumber/byCarrier row also carry that row's own inbound-message
    # sentiment: sentimentScore (volume-weighted average, -100..100, nil when nothing in that row's scope was
    # scored), sentimentLabel, sentimentScoredCount, sentimentPositive, sentimentNeutral and sentimentNegative.
    # The fields are always present; sentimentScore is an average and must never be summed across rows or responses.
    # message_type scopes the SENTIMENT figures to "SMS", "MMS" or "P2P" (single value, array, or comma-separated
    # string); omit for all scored types. It does NOT narrow the message counts, which are always returned split per type.
    # carrier_family filters by the recipient's resolved carrier family (Default, ATT, TMobile, Verizon, USCellular, GoogleVoice, ClearSky, Interop, RogueMobile, P2P, Standard, IceWireless, Bell, Rogers, Telus, Videotron, SaskTel, Eastlink, Fibernetics); single value, array,
    # or comma-separated string. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400 -- omit the parameter unless it is wanted.
    # granularity ("day" | "hour") is the time-bucket grain of the byDate rows. Omit for day (each row's _id is a
    # "YYYY-MM-DD" date). "hour" buckets by hour (each row's _id is a "YYYY-MM-DD HH:MM:SS" UTC hour; start_date is
    # floored to its hour and end_date honoured as given) and is capped to a 7-day span. Only accepted where the
    # environment serves hourly analytics; elsewhere any value, including "day", is rejected with a 400 -- omit it
    # unless hour grain is wanted.
    # breakdown ("carrier" | "carrierFamily") adds a byBreakdown time × dimension series to the response
    # ({dimension, rows}: each row is one byDate bucket (_id) for one carrier or carrier family (key), top 50 keys
    # by volume, excluding P2P) and caps the span at 31 days. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400 -- omit the parameter unless it is wanted.
    # date_bounds is which contract binds start_date/end_date. "day": each bound is widened to its whole UTC day
    #. "exact": a timestamp is bound as the instant it names and a bare date is its
    # whole UTC day. Omitted: "day".
    # region filters by "US", "GB", or "CA" (any case of "UK"/"GB"/"GBR"/"United Kingdom" is accepted for GB; single value or array). region_scopes is an
    # array of OR-ed branches { region:, channels:, brandId:?, campaignId:?, phoneNumber:? } (channels: tenDLC,
    # virtualLongCode, tollFree, shortCode, p2p), JSON-encoded for the query; a String is sent as-is and [] matches
    # nothing. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400.
    # registration_id filters to traffic attributed to these registrations (hourly analytics only; a 400 while hourly
    # reads are off); single value or array. A phone_number filter takes precedence.
    def get_analytics_detail(group_id: nil, subgroup_id: nil, brand_id: nil, campaign_id: nil, registration_id: nil, phone_number: nil, carrier: nil, carrier_family: nil, start_date: nil, end_date: nil, channel: nil, region: nil, region_scopes: nil, message_type: nil, granularity: nil, breakdown: nil, date_bounds: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, brandId: brand_id,
        campaignId: campaign_id, registrationId: registration_id, phoneNumber: phone_number, carrier: carrier, carrierFamily: carrier_family,
        startDate: start_date, endDate: end_date, channel: channel, region: region, regionScopes: encode_region_scopes(region_scopes), messageType: message_type,
        granularity: granularity, breakdown: breakdown, dateBounds: date_bounds
      )
      @client.request("/message/analytics/detail#{qs}", method: :get, token: token, headers: headers)
    end

    # Per-minute send throughput (peak segments per minute, sending minutes, minutes at a ceiling) per time
    # bucket and per carrier family, measured from SENT transitions at campaign x carrier-family grain -- the
    # grain carrier ceilings are enforced at. Only accepted where the environment serves hourly analytics;
    # elsewhere the request is rejected with a 400.
    #
    # group_id is required; campaign_id wins over brand_id (single value or array); carrier_family filters by
    # family (ATT, TMobile, Verizon, USCellular, ...). start_date / end_date are ISO-8601 (span capped at 35
    # days); granularity is "hour" (default; span capped at 7 days) or "day". ceiling is a positive integer
    # segments per minute -- when given every row also reports minutesAtCeiling, otherwise it is nil.
    #
    # Returns totals, byDate, byCarrierFamily and byBreakdown ({dimension: "carrierFamily", rows}); every row
    # carries segments, messages, peakSegmentsPerMinute, peakMessagesPerMinute, peakMinute (UTC
    # "YYYY-MM-DD HH:MM:SS", nil when no traffic), sendingMinutes, averageSegmentsPerSendingMinute and
    # minutesAtCeiling.
    #
    # GET /message/analytics/throughput?...
    # date_bounds is which contract binds start_date/end_date. "day": each bound is widened to its whole UTC day
    #. "exact": a timestamp is bound as the instant it names and a bare date is its
    # whole UTC day. Omitted: "day".
    # registration_id filters to traffic attributed to these registrations (hourly analytics only; a 400 while hourly
    # reads are off); single value or array.
    def get_analytics_throughput(group_id:, start_date:, end_date:, brand_id: nil, campaign_id: nil, registration_id: nil, carrier_family: nil, granularity: nil, ceiling: nil, date_bounds: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(
        groupId: group_id, brandId: brand_id, campaignId: campaign_id, registrationId: registration_id, carrierFamily: carrier_family,
        startDate: start_date, endDate: end_date, granularity: granularity, ceiling: ceiling, dateBounds: date_bounds
      )
      @client.request("/message/analytics/throughput#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /message/analytics/filter-options?...
    # Returns subgroups, brands, campaigns, phoneNumbers, and carriers arrays. region restricts the options to "US", "GB", or "CA" (any case of "UK"/"GB"/"GBR"/"United Kingdom" is accepted for GB; single value or array). Only
    # accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400.
    # Each phone number carries type (TOLL_FREE, SHORT_CODE, ALPHANUMERIC, VIRTUAL_LONG_NUMBER, ...) and country
    # (ISO-2), nil when unknown: TOLL_FREE, SHORT_CODE and ALPHANUMERIC are channels by type; any other US number is
    # 10DLC and a non-US one is a Virtual Long Code. carriers is a plain array of carrier name strings.
    def get_analytics_filter_options(group_id:, region: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, region: region)
      @client.request("/message/analytics/filter-options#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /message/analytics/by-subgroup?...
    # Paginated breakdown grouped by subgroup. Each row carries all sms/mms/p2p columns plus
    # smsOptOuts/mmsOptOuts (sourced from the DNC analytics MV — P2P has no opt-outs), and that
    # subgroup's inbound-message sentiment: sentimentScore (volume-weighted, -100..100, nil when
    # nothing was scored), sentimentLabel, sentimentScoredCount, sentimentPositive/Neutral/Negative,
    # plus the same six per message type under smsSentiment*, mmsSentiment*, p2pSentiment*. The
    # score is derived server-side; combine counts across rows, never the scores.
    # channel: "both" (default, all activity) or "tenDLC" | "virtualLongCode" | "tollFree" | "shortCode" | "p2p"
    # (single value or array) — scopes ORDER BY + row inclusion by the stored channel column.
    # message_type: SMS | MMS | P2P (single value or array) — scopes ONLY the sentiment figures.
    # Omit for all scored types; it does not narrow the message counts, which are always returned
    # split per type and have no filterable type dimension.
    # carrier_family filters by the recipient's resolved carrier family (Default, ATT, TMobile, Verizon, USCellular, GoogleVoice, ClearSky, Interop, RogueMobile, P2P, Standard, IceWireless, Bell, Rogers, Telus, Videotron, SaskTel, Eastlink, Fibernetics); single value, array,
    # or comma-separated string. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400 -- omit the parameter unless it is wanted.
    # registration_id filters to traffic attributed to these registrations (hourly analytics only; a 400 while hourly
    # reads are off); single value or array. A phone_number filter takes precedence.
    # date_bounds is which contract binds start_date/end_date. "day": each bound is widened to its whole UTC day
    #. "exact": a timestamp is bound as the instant it names and a bare date is its
    # whole UTC day. Omitted: "day".
    # region filters by "US", "GB", or "CA" (any case of "UK"/"GB"/"GBR"/"United Kingdom" is accepted for GB; single value or array). region_scopes is an
    # array of OR-ed branches { region:, channels:, brandId:?, campaignId:?, phoneNumber:? } (channels: tenDLC,
    # virtualLongCode, tollFree, shortCode, p2p), JSON-encoded for the query; a String is sent as-is and [] matches
    # nothing. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400.
    def get_analytics_by_subgroup(group_id:, subgroup_id: nil, brand_id: nil, campaign_id: nil, registration_id: nil, phone_number: nil, carrier: nil, carrier_family: nil, start_date: nil, end_date: nil, page: nil, limit: nil, channel: nil, region: nil, region_scopes: nil, message_type: nil, date_bounds: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, brandId: brand_id,
        campaignId: campaign_id, registrationId: registration_id, phoneNumber: phone_number, carrier: carrier, carrierFamily: carrier_family,
        startDate: start_date, endDate: end_date, page: page, limit: limit, channel: channel, region: region, regionScopes: encode_region_scopes(region_scopes),
        messageType: message_type, dateBounds: date_bounds
      )
      @client.request("/message/analytics/by-subgroup#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /message/analytics/by-error-code?...
    # Paginated breakdown of failed messages grouped by error code. Per-channel counts plus enriched description.
    # channel: "both" (default, every code) or "tenDLC" | "virtualLongCode" | "tollFree" | "shortCode" | "p2p" (single value or
    # array) — scopes ORDER BY + totalCount by the stored channel column; when one channel is
    # selected, totalErrors reflects only that channel.
    # carrier_family filters by the recipient's resolved carrier family (Default, ATT, TMobile, Verizon, USCellular, GoogleVoice, ClearSky, Interop, RogueMobile, P2P, Standard, IceWireless, Bell, Rogers, Telus, Videotron, SaskTel, Eastlink, Fibernetics); single value, array,
    # or comma-separated string. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400 -- omit the parameter unless it is wanted.
    # registration_id filters to traffic attributed to these registrations (hourly analytics only; a 400 while hourly
    # reads are off); single value or array. A phone_number filter takes precedence.
    # date_bounds is which contract binds start_date/end_date. "day": each bound is widened to its whole UTC day
    #. "exact": a timestamp is bound as the instant it names and a bare date is its
    # whole UTC day. Omitted: "day".
    # region filters by "US", "GB", or "CA" (any case of "UK"/"GB"/"GBR"/"United Kingdom" is accepted for GB; single value or array). region_scopes is an
    # array of OR-ed branches { region:, channels:, brandId:?, campaignId:?, phoneNumber:? } (channels: tenDLC,
    # virtualLongCode, tollFree, shortCode, p2p), JSON-encoded for the query; a String is sent as-is and [] matches
    # nothing. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400.
    # error_code narrows the breakdown to a single failure reason: a numeric Infobip carrier code (as a string,
    # e.g. "607"), the Signal House campaign-opt-out code "OUT", or a no-code failure class (other, moderation,
    # att_limit, p2p_stop, campaign_opt_out, dnc_blocked, bind_hold_expired). Omitted: every reason.
    def get_analytics_by_error_code(group_id:, subgroup_id: nil, brand_id: nil, campaign_id: nil, registration_id: nil, phone_number: nil, carrier: nil, carrier_family: nil, start_date: nil, end_date: nil, page: nil, limit: nil, channel: nil, region: nil, region_scopes: nil, date_bounds: nil, error_code: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, brandId: brand_id,
        campaignId: campaign_id, registrationId: registration_id, phoneNumber: phone_number, carrier: carrier, carrierFamily: carrier_family,
        startDate: start_date, endDate: end_date, page: page, limit: limit, channel: channel, region: region, regionScopes: encode_region_scopes(region_scopes), dateBounds: date_bounds, errorCode: error_code
      )
      @client.request("/message/analytics/by-error-code#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /message/dnc/analytics?...
    # channel filters by "tenDLC", "virtualLongCode", "tollFree", or "shortCode" (single value or array); opt-outs are A2P-only, so
    # "p2p" applies no filter, and a tenDLC selection also includes older opt-outs with no channel.
    # Returns totals, byDate, byPhoneNumber, bySenderNumber, byCampaign, bySubgroup, byType, byCarrier, byKeyword.
    # bySenderNumber ({senderPhoneNumber, total, sms, mms}) attributes each opt-out to the first business number
    # that received it, so it is unchanged by later campaign moves and START replies. byCampaign counts
    # campaign-scoped opt-outs only, by the campaign at the time of the STOP; subgroup-scoped opt-outs (non-US
    # recipients) are never attributed to a campaign and appear under bySubgroup instead. byType splits SMS/MMS.
    # byKeyword breaks opt-outs down by the
    # normalized keyword that revoked consent ({optOutKeyword, total, sms, mms}); opt-outs recorded before
    # keyword capture shipped appear as a single optOutKeyword: nil bucket ("not recorded"). The distinct
    # keyword set is open-ended (campaigns register their own keywords beyond the mandatory floor) — render
    # top-N plus Other, never a fixed list.
    # date_bounds is which contract binds start_date/end_date. "day": each bound is widened to its whole UTC day
    #. "exact": a timestamp is bound as the instant it names and a bare date is its
    # whole UTC day. Omitted: "day".
    # region filters by "US", "GB", or "CA" (any case of "UK"/"GB"/"GBR"/"United Kingdom" is accepted for GB; single value or array). region_scopes is an
    # array of OR-ed branches { region:, channels:, brandId:?, campaignId:?, phoneNumber:? } (channels: tenDLC,
    # virtualLongCode, tollFree, shortCode, p2p), JSON-encoded for the query; a String is sent as-is and [] matches
    # nothing. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400.
    # registration_id filters to traffic attributed to these registrations (hourly analytics only; a 400 while hourly
    # reads are off); single value or array. A phone_number filter takes precedence.
    def get_dnc_analytics(group_id: nil, subgroup_id: nil, brand_id: nil, campaign_id: nil, registration_id: nil, phone_number: nil, carrier: nil, start_date: nil, end_date: nil, channel: nil, region: nil, region_scopes: nil, date_bounds: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, brandId: brand_id,
        campaignId: campaign_id, registrationId: registration_id, phoneNumber: phone_number, carrier: carrier,
        startDate: start_date, endDate: end_date, channel: channel, region: region, regionScopes: encode_region_scopes(region_scopes), dateBounds: date_bounds
      )
      @client.request("/message/dnc/analytics#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /message/dnc?...
    # channel filters by "tenDLC", "virtualLongCode", "tollFree", or "shortCode" (single value or array); opt-outs are A2P-only, so
    # "p2p" applies no filter, and a tenDLC selection also includes older opt-outs with no channel.
    # Each record carries senderPhoneNumber — the first business number that received the opt-out (set once, never
    # changed by a later STOP or a campaign move; the same value as phoneNumber), campaignId (nil on subgroup-scoped
    # records for non-US recipients), optOutKeyword — the normalized keyword that revoked consent (e.g. "stop", "opt out";
    # a repeat opt-out records the most recent word), nil for opt-outs recorded before keyword capture
    # shipped — and carrierFamily, the resolved carrier family of the recipient number (Default, ATT, TMobile,
    # Verizon, USCellular, GoogleVoice, ClearSky, Interop, RogueMobile, Standard, IceWireless, Bell, Rogers, Telus, Videotron, SaskTel, Eastlink, Fibernetics), copied from the inbound message that
    # triggered the opt-out.
    # registration_id filters to traffic attributed to these registrations (hourly analytics only; a 400 while hourly
    # reads are off); single value or array. A phone_number filter takes precedence.
    # date_bounds is which contract binds start_date/end_date. "day": each bound is widened to its whole UTC day
    #. "exact": a timestamp is bound as the instant it names and a bare date is its
    # whole UTC day. Omitted: "day".
    # region filters by "US", "GB", or "CA" (any case of "UK"/"GB"/"GBR"/"United Kingdom" is accepted for GB; single value or array). region_scopes is an
    # array of OR-ed branches { region:, channels:, brandId:?, campaignId:?, phoneNumber:? } (channels: tenDLC,
    # virtualLongCode, tollFree, shortCode, p2p), JSON-encoded for the query; a String is sent as-is and [] matches
    # nothing. Only accepted where the environment serves hourly analytics; elsewhere any value is rejected with a 400.
    def get_dnc_records(group_id: nil, subgroup_id: nil, brand_id: nil, campaign_id: nil, registration_id: nil, phone_number: nil, carrier: nil, start_date: nil, end_date: nil, page: nil, limit: nil, sort_field: nil, sort_order: nil, channel: nil, region: nil, region_scopes: nil, date_bounds: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, brandId: brand_id,
        campaignId: campaign_id, registrationId: registration_id, phoneNumber: phone_number, carrier: carrier,
        startDate: start_date, endDate: end_date, page: page, limit: limit,
        sortField: sort_field, sortOrder: sort_order, channel: channel, region: region, regionScopes: encode_region_scopes(region_scopes), dateBounds: date_bounds
      )
      @client.request("/message/dnc#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /message/sms
    # The response reports the send outcome via requestedRecipientCount, enqueuedCount, and failedCount.
    # enqueuedCount is the number of recipients accepted for delivery and is 0 when the send was fully
    # blocked (moderation filter or campaign opt-out); the request still succeeds in that case, so treat
    # enqueuedCount, not the HTTP status, as the signal that a message was accepted. Blocked recipients
    # are returned in insertedMessages with status "FAILED"; global Do Not Contact recipients are reported
    # in dncBlockedNumbers with no message record. Each FAILED message carries errorCode (campaign opt-out
    # is "OUT"; nil otherwise), also included on the FAILED status-callback payload.
    # sender_phone_number accepts a digits-only 5-6 digit Short Code or 10+ digit long number, or a READY
    # alphanumeric sender ID (e.g. "ACME"; UK recipients and SMS only) — every message from an alphanumeric sender
    # gets "\nOpt out: sihou.io/o/{code}" appended by the server, counted in segments. A Short Code
    # sender permits exactly one 10+ digit recipient, and it must be a +1 (US/Canada) number (a bare 10-digit
    # number is treated as +1); the API rejects multiple recipients or a non-+1 recipient.
    def send_sms(sender_phone_number:, recipient_phone_numbers:, message_body:, status_callback_url: nil, enable_shortlink: false, filter_landlines_and_inactive_numbers: false, **opts)
      @client.require_params("senderPhoneNumber" => sender_phone_number, "recipientPhoneNumbers" => recipient_phone_numbers, "messageBody" => message_body)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = {
        senderPhoneNumber: sender_phone_number,
        recipientPhoneNumber: recipient_phone_numbers,
        messageBody: message_body,
        statusCallbackUrl: status_callback_url,
        enableShortlink: enable_shortlink
      }
      body[:filterLandlinesAndInactiveNumbers] = true if filter_landlines_and_inactive_numbers
      @client.request("/message/sms", method: :post, body: body, token: token, headers: headers)
    end

    # POST /message/p2p
    # group_id: optional. Explicit group to send from. Defaults to the group in your auth context.
    # subgroup_id: optional. Explicit subgroup to attribute the send (and its inbound reply) to. P2P has no
    #   dedicated sender number, so pass this to record the send against a specific subgroup; it also resolves
    #   the group. Defaults to the group's oldest subgroup.
    # use_signal_house_shortlinks: optional boolean. When false, SignalHouse applies no
    # link-shortening or text-spin and your pre-spun links/content are sent verbatim
    # (bring-your-own spinner). Defaults to true. Pass nil to omit and keep the server default.
    def send_p2p(recipient_phone_numbers:, message_body:, status_callback_url: nil, group_id: nil, subgroup_id: nil, use_signal_house_shortlinks: nil, **opts)
      @client.require_params("recipientPhoneNumbers" => recipient_phone_numbers, "messageBody" => message_body)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = {
        recipientPhoneNumber: recipient_phone_numbers,
        messageBody: message_body,
      }
      body[:statusCallbackUrl] = status_callback_url if status_callback_url
      body[:groupId] = group_id if group_id
      body[:subgroupId] = subgroup_id if subgroup_id
      body[:useSignalHouseShortlinks] = use_signal_house_shortlinks unless use_signal_house_shortlinks.nil?
      @client.request("/message/p2p", method: :post, body: body, token: token, headers: headers)
    end

    # GET /message/p2p/batches/:batchId
    def get_p2p_batch(batch_id:, **opts)
      @client.require_params("batchId" => batch_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_batch_id = CGI.escape(batch_id.to_s)
      @client.request("/message/p2p/batches/#{safe_batch_id}", method: :get, token: token, headers: headers)
    end

    # POST /message/mms (multipart)
    # The response reports the send outcome via requestedRecipientCount, enqueuedCount, and failedCount.
    # enqueuedCount is the number of recipients accepted for delivery and is 0 when the send was fully
    # blocked (moderation filter or campaign opt-out); the request still succeeds in that case, so treat
    # enqueuedCount, not the HTTP status, as the signal that a message was accepted. Blocked recipients
    # are returned in insertedMessages with status "FAILED"; global Do Not Contact recipients are reported
    # in dncBlockedNumbers with no message record. Each FAILED message carries errorCode (campaign opt-out
    # is "OUT"; nil otherwise), also included on the FAILED status-callback payload.
    # sender_phone_number accepts a digits-only 5-6 digit Short Code or 10+ digit long number. A Short Code
    # sender permits exactly one 10+ digit recipient, and it must be a +1 (US/Canada) number (a bare 10-digit
    # number is treated as +1); the API rejects multiple recipients or a non-+1 recipient.
    def send_mms(sender_phone_number:, recipient_phone_numbers:, message_body:, media_urls: nil, status_callback_url: nil, enable_shortlink: false, enable_compression: true, filter_landlines_and_inactive_numbers: false, images: nil, **opts)
      @client.require_params("senderPhoneNumber" => sender_phone_number, "recipientPhoneNumbers" => recipient_phone_numbers)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)

      form_data = build_message_form_data(
        sender_phone_number: sender_phone_number,
        recipient_phone_numbers: recipient_phone_numbers,
        message_body: message_body,
        media_urls: media_urls,
        status_callback_url: status_callback_url,
        enable_shortlink: enable_shortlink,
        enable_compression: enable_compression,
        filter_landlines_and_inactive_numbers: filter_landlines_and_inactive_numbers,
        images: images
      )

      @multipart_client.request("/message/mms", method: :post, body: form_data, token: token, headers: headers)
    end

    # POST /message/groupMessage (multipart)
    # Short Codes do not support group messaging; sender_phone_number must be a long number.
    # The response reports the send outcome via requestedRecipientCount, enqueuedCount, and failedCount.
    # enqueuedCount is the number of recipients accepted for delivery and is 0 when the send was fully
    # blocked (moderation filter or campaign opt-out); the request still succeeds in that case, so treat
    # enqueuedCount, not the HTTP status, as the signal that a message was accepted. Blocked recipients
    # are returned in insertedMessages with status "FAILED"; global Do Not Contact recipients are reported
    # in dncBlockedNumbers with no message record. Each FAILED message carries errorCode (campaign opt-out
    # is "OUT"; nil otherwise), also included on the FAILED status-callback payload.
    def send_group_message(sender_phone_number:, recipient_phone_numbers:, message_body:, media_urls: nil, status_callback_url: nil, enable_shortlink: false, enable_compression: true, filter_landlines_and_inactive_numbers: false, images: nil, **opts)
      @client.require_params("senderPhoneNumber" => sender_phone_number, "recipientPhoneNumbers" => recipient_phone_numbers)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)

      form_data = build_message_form_data(
        sender_phone_number: sender_phone_number,
        recipient_phone_numbers: recipient_phone_numbers,
        message_body: message_body,
        media_urls: media_urls,
        status_callback_url: status_callback_url,
        enable_shortlink: enable_shortlink,
        enable_compression: enable_compression,
        filter_landlines_and_inactive_numbers: filter_landlines_and_inactive_numbers,
        images: images
      )

      @multipart_client.request("/message/groupMessage", method: :post, body: form_data, token: token, headers: headers)
    end

    # POST /message/carrier-id
    def carrier_id_lookup(phone_number:, **opts)
      @client.require_params("phoneNumber" => phone_number)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = { phoneNumber: phone_number }
      @client.request("/message/carrier-id", method: :post, body: body, token: token, headers: headers)
    end

    # Fetch the latest upstream carrier delivery report for a set of messages by ID.
    #
    # Useful for reconciling messages stuck in a non-terminal state. Outbound SMS and MMS messages sent
    # from numbers on supported carriers are looked up upstream (reports are retained about
    # 48 hours); every other message, including P2P messages and messages sent from numbers on other
    # carriers, is returned with its stored status and upstreamReportAvailable false. The request fails
    # with a 500 when the sending numbers can't be read.
    def get_delivery_reports(message_ids:, **opts)
      @client.require_params("messageIds" => message_ids)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/message/delivery-report", method: :post, body: { messageIds: message_ids }, token: token, headers: headers)
    end

    private

    # Serialize regionScopes for the query: arrays become JSON, strings pass through, nil is omitted.
    def encode_region_scopes(region_scopes)
      region_scopes.is_a?(String) ? region_scopes : region_scopes&.to_json
    end

    def build_message_form_data(sender_phone_number:, recipient_phone_numbers:, message_body:, media_urls:, status_callback_url:, enable_shortlink:, enable_compression:, filter_landlines_and_inactive_numbers:, images:)
      form_data = {}

      # Images as array of file hashes
      if images.is_a?(Array) && !images.empty?
        form_data["images"] = images
      end

      form_data["senderPhoneNumber"] = sender_phone_number.to_s

      # recipientPhoneNumber: JSON-encode if array
      if recipient_phone_numbers.is_a?(Array)
        form_data["recipientPhoneNumber"] = JSON.generate(recipient_phone_numbers)
      else
        form_data["recipientPhoneNumber"] = recipient_phone_numbers.to_s
      end

      form_data["messageBody"] = message_body.to_s

      if media_urls.is_a?(Array) && !media_urls.empty?
        form_data["mediaUrls"] = JSON.generate(media_urls)
      end

      form_data["statusCallbackUrl"] = status_callback_url.to_s if status_callback_url

      form_data["enableShortlink"] = enable_shortlink.to_s
      form_data["enableCompression"] = enable_compression.to_s
      form_data["filterLandlinesAndInactiveNumbers"] = "true" if filter_landlines_and_inactive_numbers

      form_data
    end
  end
end
