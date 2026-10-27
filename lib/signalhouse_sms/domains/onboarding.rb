# frozen_string_literal: true

module SignalHouseSms
  class Onboarding
    attr_reader :admin

    def initialize(client, enable_admin)
      @client = client
      @admin = Admin.new(client) if enable_admin
    end

    class Admin
      def initialize(client)
        @client = client
      end

      # GET /group/onboarding — staff-only
      def get_onboardings(**opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        @client.request("/group/onboarding", method: :get, token: token, headers: headers)
      end

      # GET /group/onboarding/:groupId — staff-only
      def get_onboarding(group_id:, **opts)
        @client.require_params("groupId" => group_id)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_group_id = CGI.escape(group_id.to_s)
        @client.request("/group/onboarding/#{safe_group_id}", method: :get, token: token, headers: headers)
      end

      # POST /group/onboarding/:groupId/pricing-comments — staff-only
      def add_pricing_comment(group_id:, comment:, **opts)
        @client.require_params("groupId" => group_id, "comment" => comment)
        token = opts[:token]
        headers = opts[:headers]
        safe_group_id = CGI.escape(group_id.to_s)
        @client.request("/group/onboarding/#{safe_group_id}/pricing-comments", method: :post, body: { comment: comment }, token: token, headers: headers)
      end

      # POST /group/onboarding/:groupId/credit-comments — staff-only
      def add_credit_comment(group_id:, comment:, **opts)
        @client.require_params("groupId" => group_id, "comment" => comment)
        token = opts[:token]
        headers = opts[:headers]
        safe_group_id = CGI.escape(group_id.to_s)
        @client.request("/group/onboarding/#{safe_group_id}/credit-comments", method: :post, body: { comment: comment }, token: token, headers: headers)
      end

      # PUT /group/onboarding/:groupId/toll-free-provider — staff-only
      # Set where a group's new toll-free brands and numbers go ("infobip" or "twilio").
      # Existing brands, numbers and campaigns stay where they are.
      def set_toll_free_provider(group_id:, toll_free_provider:, **opts)
        @client.require_params("groupId" => group_id, "tollFreeProvider" => toll_free_provider)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_group_id = CGI.escape(group_id.to_s)
        @client.request("/group/onboarding/#{safe_group_id}/toll-free-provider", method: :put, body: { tollFreeProvider: toll_free_provider }, token: token, headers: headers)
      end
    end
  end
end
