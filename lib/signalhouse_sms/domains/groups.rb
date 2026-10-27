# frozen_string_literal: true

module SignalHouseSms
  class Groups
    attr_reader :admin

    def initialize(client, enable_admin)
      @client = client
      @admin = Admin.new(client) if enable_admin
    end

    # GET /group?id=...
    def get_group(id:, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(id: id)
      @client.request("/group#{qs}", method: :get, token: token, headers: headers)
    end

    # PUT /group/:id
    # group_data may include optional CNP fields: cspId (String|nil), defaultCnpSubgroupId (String|nil)
    def update_group(id:, group_data:, **opts)
      @client.require_params("id" => id, "groupData" => group_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/group/#{safe_id}", method: :put, body: group_data, token: token, headers: headers)
    end

    class Admin
      def initialize(client)
        @client = client
      end

      # GET /group/counts?groupId=...&limit=...&offset=... Only signalhouse_admin can query all
      # groups; every other allowed role is restricted to its JWT group scope.
      def get_group_counts(group_id: nil, limit: nil, offset: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(groupId: group_id, limit: limit, offset: offset)
        @client.request("/group/counts#{qs}", method: :get, token: token, headers: headers)
      end

      # GET /group?page=...&limit=...
      def get_groups(page: nil, limit: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(page: page, limit: limit)
        @client.request("/group#{qs}", method: :get, token: token, headers: headers)
      end

      # POST /group
      # group_data optionally accepts psPartnerKey and ownerEmail to credit a referring partner.
      def create_group(group_data:, **opts)
        @client.require_params("groupData" => group_data)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        @client.request("/group", method: :post, body: group_data, token: token, headers: headers)
      end

      # DELETE /group/:groupId
      def delete_group(group_id:, **opts)
        @client.require_params("groupId" => group_id)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_group_id = CGI.escape(group_id.to_s)
        @client.request("/group/#{safe_group_id}", method: :delete, token: token, headers: headers)
      end

      # PUT /group/:groupId/compliance-status
      # Set a group's KYC complianceStatus. Only flips the field — it does not trigger any
      # lockout side effects (halted sends, revoked API keys, etc.) for "rejected".
      def update_compliance_status(group_id:, compliance_status:, **opts)
        @client.require_params("groupId" => group_id, "complianceStatus" => compliance_status)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_group_id = CGI.escape(group_id.to_s)
        @client.request("/group/#{safe_group_id}/compliance-status", method: :put, body: { complianceStatus: compliance_status }, token: token, headers: headers)
      end

      # POST /group/link-external
      # Link an external tenant (GHL/Shopify) to a V2 group (server-to-server). Exchanges a single-use
      # link token for a canonical group, adopting an empty portal group, repointing to an existing
      # group, or flagging for manual review.
      def link_external(link_token:, external_system:, external_id:, existing_group_id: nil, **opts)
        @client.require_params("linkToken" => link_token, "externalSystem" => external_system, "externalId" => external_id)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        body = { linkToken: link_token, externalSystem: external_system, externalId: external_id }
        body[:existingGroupId] = existing_group_id unless existing_group_id.nil?
        @client.request("/group/link-external", method: :post, body: body, token: token, headers: headers)
      end
    end
  end
end
