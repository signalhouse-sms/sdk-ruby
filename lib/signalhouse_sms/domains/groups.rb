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

    # GET /group/sso?groupId=...
    # The group's SSO connection (client secret never returned) and its email domains with verification status.
    def get_sso_configuration(group_id:, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id)
      @client.request("/group/sso#{qs}", method: :get, token: token, headers: headers)
    end

    # PUT /group/sso
    # Create or update the group's OIDC SSO connection. client_secret may be omitted on update to keep the
    # stored one. Requires a fresh auth.confirm_two_factor_identity from the same session (403 otherwise).
    def save_sso_connection(group_id:, issuer:, client_id:, client_secret: nil, enabled: nil, **opts)
      @client.require_params("groupId" => group_id, "issuer" => issuer, "clientId" => client_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = { groupId: group_id, issuer: issuer, clientId: client_id }
      body[:clientSecret] = client_secret unless client_secret.nil?
      body[:enabled] = enabled unless enabled.nil?
      @client.request("/group/sso", method: :put, body: body, token: token, headers: headers)
    end

    # DELETE /group/sso?groupId=...
    # Delete the group's SSO connection. Requires a fresh auth.confirm_two_factor_identity from the same
    # session (403 otherwise).
    def delete_sso_connection(group_id:, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id)
      @client.request("/group/sso#{qs}", method: :delete, token: token, headers: headers)
    end

    # POST /group/sso/domains
    # Claim an email domain for the group's SSO. Returns the DNS TXT record to publish before verify_sso_domain.
    def add_sso_domain(group_id:, domain:, **opts)
      @client.require_params("groupId" => group_id, "domain" => domain)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/group/sso/domains", method: :post, body: { groupId: group_id, domain: domain }, token: token, headers: headers)
    end

    # POST /group/sso/domains/:domain/verify
    # Check the domain's DNS TXT record and mark the domain verified when it matches.
    def verify_sso_domain(group_id:, domain:, **opts)
      @client.require_params("groupId" => group_id, "domain" => domain)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_domain = CGI.escape(domain.to_s)
      @client.request("/group/sso/domains/#{safe_domain}/verify", method: :post, body: { groupId: group_id }, token: token, headers: headers)
    end

    # DELETE /group/sso/domains/:domain?groupId=...
    # Remove an email domain from the group's SSO.
    def remove_sso_domain(group_id:, domain:, **opts)
      @client.require_params("groupId" => group_id, "domain" => domain)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_domain = CGI.escape(domain.to_s)
      qs = @client.get_query_string(groupId: group_id)
      @client.request("/group/sso/domains/#{safe_domain}#{qs}", method: :delete, token: token, headers: headers)
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
