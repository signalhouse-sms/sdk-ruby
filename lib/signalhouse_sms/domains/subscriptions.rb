# frozen_string_literal: true

module SignalHouseSms
  class Subscriptions
    attr_reader :admin

    def initialize(client, enable_admin)
      @client = client
      @admin = Admin.new(client) if enable_admin
    end

    # GET /subscription/user?groupId=...&onlyActive=...
    def get_subscriptions(group_id:, only_active: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, onlyActive: only_active)
      @client.request("/subscription/user#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /subscription/user/subscribe/:groupId/:templateId
    def subscribe(group_id:, template_id:, **opts)
      @client.require_params("groupId" => group_id, "templateId" => template_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      safe_template_id = CGI.escape(template_id.to_s)
      @client.request("/subscription/user/subscribe/#{safe_group_id}/#{safe_template_id}", method: :post, body: {}, token: token, headers: headers)
    end

    # POST /subscription/user/cancel/:groupId
    def unsubscribe(group_id:, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      @client.request("/subscription/user/cancel/#{safe_group_id}", method: :post, token: token, headers: headers)
    end

    class Admin
      def initialize(client)
        @client = client
      end

      # GET /subscription/template?templateId=...
      def get_templates(template_id: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(templateId: template_id)
        @client.request("/subscription/template#{qs}", method: :get, token: token, headers: headers)
      end

      # POST /subscription/template
      def create_template(template_data:, **opts)
        @client.require_params("templateData" => template_data)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        @client.request("/subscription/template", method: :post, body: template_data, token: token, headers: headers)
      end

      # PUT /subscription/template/:templateId
      def update_template(template_id:, template_data:, **opts)
        @client.require_params("templateId" => template_id, "templateData" => template_data)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_template_id = CGI.escape(template_id.to_s)
        @client.request("/subscription/template/#{safe_template_id}", method: :put, body: template_data, token: token, headers: headers)
      end

      # DELETE /subscription/template/:templateId
      def delete_template(template_id:, **opts)
        @client.require_params("templateId" => template_id)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_template_id = CGI.escape(template_id.to_s)
        @client.request("/subscription/template/#{safe_template_id}", method: :delete, token: token, headers: headers)
      end

      # POST /subscription/user/custom/:groupId
      def create_custom_subscription(group_id:, subscription_data:, **opts)
        @client.require_params("groupId" => group_id, "subscriptionData" => subscription_data)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_group_id = CGI.escape(group_id.to_s)
        @client.request("/subscription/user/custom/#{safe_group_id}", method: :post, body: subscription_data, token: token, headers: headers)
      end

      # PUT /subscription/user/custom/:groupId
      def update_custom_subscription(group_id:, update_data:, **opts)
        @client.require_params("groupId" => group_id, "updateData" => update_data)
        token = opts[:token]
        headers = opts[:headers]
        safe_group_id = CGI.escape(group_id.to_s)
        @client.request("/subscription/user/custom/#{safe_group_id}", method: :put, body: update_data, token: token, headers: headers)
      end
    end
  end
end
