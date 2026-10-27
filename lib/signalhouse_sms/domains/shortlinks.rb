# frozen_string_literal: true

module SignalHouseSms
  class Shortlinks
    def initialize(client, _enable_admin)
      @client = client
    end

    # GET /shortlink/redirect/:shortlinkId
    def get_shortlink_redirect(shortlink_id:, **opts)
      @client.require_params("shortlinkId" => shortlink_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_shortlink_id = CGI.escape(shortlink_id.to_s)
      @client.request("/shortlink/redirect/#{safe_shortlink_id}", method: :get, token: token, headers: headers)
    end

    # GET /shortlink/optout/:code (public) — {code, senderName, maskedRecipient, optedOut}
    def get_opt_out(code:, **opts)
      @client.require_params("code" => code)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_code = CGI.escape(code.to_s)
      @client.request("/shortlink/optout/#{safe_code}", method: :get, token: token, headers: headers)
    end

    # POST /shortlink/optout/:code (public, idempotent) — {code, senderName, maskedRecipient, optedOut: true}
    def confirm_opt_out(code:, **opts)
      @client.require_params("code" => code)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_code = CGI.escape(code.to_s)
      @client.request("/shortlink/optout/#{safe_code}", method: :post, token: token, headers: headers)
    end

    # GET /shortlink?...
    def get_shortlink(shortlink_id: nil, message_id: nil, phone_number: nil, campaign_id: nil, brand_id: nil, subgroup_id: nil, group_id: nil, page: nil, limit: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(shortlinkId: shortlink_id, messageId: message_id, phoneNumber: phone_number, campaignId: campaign_id, brandId: brand_id, subgroupId: subgroup_id, groupId: group_id, page: page, limit: limit)
      @client.request("/shortlink#{qs}", method: :get, token: token, headers: headers)
    end
  end
end
