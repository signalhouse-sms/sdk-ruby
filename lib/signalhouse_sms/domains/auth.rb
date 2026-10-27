# frozen_string_literal: true

module SignalHouseSms
  class Auth
    def initialize(client, _enable_admin)
      @client = client
    end

    # POST /auth
    def login(email:, password:, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/auth", method: :post, body: { email: email, password: password }, token: token, headers: headers)
    end

    # PUT /auth/resetpassword/:userId
    def reset_password(user_id:, new_password:, **opts)
      @client.require_params("userId" => user_id, "newPassword" => new_password)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_user_id = CGI.escape(user_id.to_s)
      @client.request("/auth/resetpassword/#{safe_user_id}", method: :put, body: { newPassword: new_password }, token: token, headers: headers)
    end

    # POST /auth/forgot-password
    # Request a password-reset link be emailed to the given address (public). Always succeeds
    # regardless of whether an account exists for the email, so it cannot be used to enumerate
    # registered emails.
    def forgot_password(email:, **opts)
      @client.require_params("email" => email)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/auth/forgot-password", method: :post, body: { email: email }, token: token, headers: headers)
    end

    # POST /auth/reset-password
    # Reset a password using the single-use token from a reset email (public).
    def reset_password_with_token(token:, password:, **opts)
      @client.require_params("token" => token, "password" => password)
      auth_token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/auth/reset-password", method: :post, body: { token: token, password: password }, token: auth_token, headers: headers)
    end

    # GET /auth/history?groupId=...&userId=...&page=...&limit=...
    def get_auth_history(group_id: nil, user_id: nil, page: nil, limit: nil, **opts)
      @client.require_params("groupId or userId" => (group_id || user_id))
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, userId: user_id, page: page, limit: limit)
      @client.request("/auth/history#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /auth/logout-all
    def logout_all(**opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/auth/logout-all", method: :post, token: token, headers: headers)
    end

    # GET /auth/group-id
    # Get the Group ID associated with the caller's JWT (their active group).
    def get_group_id(**opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/auth/group-id", method: :get, token: token, headers: headers)
    end

    # POST /auth/external-link-token
    # Mint a single-use, short-lived external-link token for the authenticated caller. The token is
    # handed to the GHL/Shopify backend so it can link the caller's existing V2 group to its tenant.
    def request_external_link_token(product:, **opts)
      @client.require_params("product" => product)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/auth/external-link-token", method: :post, body: { product: product }, token: token, headers: headers)
    end
  end
end
