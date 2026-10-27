# frozen_string_literal: true

module SignalHouseSms
  class Users
    attr_reader :admin

    def initialize(client, enable_admin)
      @client = client
      @admin = Admin.new(client) if enable_admin
    end

    # GET /user?...
    def get_users(id: nil, group_id: nil, user_type: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(id: id, groupId: group_id, userType: user_type)
      @client.request("/user#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /user
    def create_user(data:, **opts)
      @client.require_params("data" => data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/user", method: :post, body: data, token: token, headers: headers)
    end

    # POST /user/serviceuser
    # Customer API keys (role "api") may set "allowedIps" (IPv4/IPv6 addresses or CIDR ranges, max 100)
    # and "allowedCountries" (ISO 3166-1 alpha-2 codes such as "US", max 250); both must match when both are set.
    # "allowedDestinationCountries" (ISO 3166-1 alpha-2, max 250) limits the countries the key can send messages to.
    def create_service_user(data:, **opts)
      @client.require_params("data" => data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/user/serviceuser", method: :post, body: data, token: token, headers: headers)
    end

    # PUT /user/:id
    # For a customer API key, "allowedIps" / "allowedCountries" / "allowedDestinationCountries" replace its restrictions ([] removes one);
    # this needs an interactive admin or developer session, so an API key cannot change its own.
    def update_user(id:, data:, **opts)
      @client.require_params("id" => id, "data" => data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/user/#{safe_id}", method: :put, body: data, token: token, headers: headers)
    end

    # DELETE /user/:id
    def delete_user(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/user/#{safe_id}", method: :delete, token: token, headers: headers)
    end

    # GET /user/:id/notification-preferences
    def get_notification_preferences(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/user/#{safe_id}/notification-preferences", method: :get, token: token, headers: headers)
    end

    # PUT /user/:id/notification-preferences
    def update_notification_preferences(id:, notification_preferences:, **opts)
      @client.require_params("id" => id, "notificationPreferences" => notification_preferences)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/user/#{safe_id}/notification-preferences", method: :put, body: { notificationPreferences: notification_preferences }, token: token, headers: headers)
    end

    class Admin
      def initialize(client)
        @client = client
      end

      # GET /user?email=...&userType=...
      def get_users(email: nil, user_type: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(email: email, userType: user_type)
        @client.request("/user#{qs}", method: :get, token: token, headers: headers)
      end

      # POST /user/signalhouse
      def create_internal_user(data:, **opts)
        @client.require_params("data" => data)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        @client.request("/user/signalhouse", method: :post, body: data, token: token, headers: headers)
      end
    end
  end
end
