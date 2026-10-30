# frozen_string_literal: true

module SignalHouseSms
  class Auth
    attr_reader :admin

    def initialize(client, enable_admin)
      @client = client
      @admin = Admin.new(client) if enable_admin
    end

    # POST /auth
    # Returns { token }, or { mfaRequired: true, challengeId, ... } when the account has 2FA on, or
    # { token, twoFactorSetupRequired: true } (a setup-only session) when the user's group requires 2FA
    # and they haven't turned it on.
    # device_token (from verify_two_factor_challenge) skips 2FA on a trusted device.
    def login(email:, password:, device_token: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = { email: email, password: password }
      body[:deviceToken] = device_token unless device_token.nil?
      @client.request("/auth", method: :post, body: body, token: token, headers: headers)
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

    # GET /auth/oauth/providers
    # List the OAuth sign-in providers enabled on this API (only providers with credentials configured).
    def get_oauth_providers(**opts)
      token = opts[:token]
      headers = opts[:headers]
      @client.request("/auth/oauth/providers", method: :get, token: token, headers: headers)
    end

    # GET /auth/oauth/links
    # The sign-in providers linked to the caller's account. Returns { passwordKnown, links }; passwordKnown is
    # false for an account without its own password (it confirms identity with an emailed code instead).
    def get_oauth_links(**opts)
      @client.request("/auth/oauth/links", method: :get, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/oauth/:provider/link
    # Start linking a sign-in provider to the caller's account. Returns { linkTicket, expiresInSeconds }; pass
    # linkTicket as link_ticket: to get_oauth_authorization_url and navigate the browser there to finish.
    # provider is "google", "microsoft" or "apple"; the ticket is single-use and valid 2 minutes.
    # Requires a fresh confirm_two_factor_identity from the same session, which this spends (403 otherwise).
    def create_oauth_link(provider:, **opts)
      @client.require_params("provider" => provider)
      @client.request("/auth/oauth/#{CGI.escape(provider.to_s)}/link", method: :post, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/oauth/:provider/reauth
    # Start signing in again with a provider already linked to the caller's account, to confirm it's them.
    # Returns { reauthTicket, reauthSecret, expiresInSeconds }. Keep reauthSecret in the client that started the
    # flow: it is returned only here, and confirm_oauth_reauth needs it. Pass reauthTicket as reauth_ticket: to
    # get_oauth_authorization_url and navigate the browser there. provider is "google", "microsoft", "apple" or
    # "sso"; the ticket is single-use and valid 2 minutes, and nothing is spent. The browser comes back to
    # /Settings/Security with a single-use `pendingReauth` (the session that started it redeems it with confirm_oauth_reauth) or `reauthError` (reauth_wrong_account, reauth_unsupported,
    # reauth_stale, invalid_state, sso_not_configured, access_denied or provider_error).
    def create_oauth_reauth(provider:, **opts)
      @client.require_params("provider" => provider)
      @client.request("/auth/oauth/#{CGI.escape(provider.to_s)}/reauth", method: :post, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/oauth/reauth/confirm
    # Finish signing in again with a linked provider. The round trip started with create_oauth_reauth returns the
    # browser to /Settings/Security with a single-use `pendingReauth` (valid 5 minutes); this redeems it, but only
    # for the same account and the same session that called create_oauth_reauth, so a re-sign-in completed in
    # someone else's browser confirms nothing. 400 when it expired or was used, 403 for another account or session.
    # pending_reauth (sent as `pendingReauth`): the `pendingReauth` query parameter from the redirect.
    # reauth_secret (sent as `reauthSecret`): the reauthSecret create_oauth_reauth returned; a wrong or missing
    # secret is refused (403) and uses up the pending re-sign-in.
    # Returns { identityConfirmed }: true when 2FA is off, so it counts as a confirmed identity.
    def confirm_oauth_reauth(pending_reauth:, reauth_secret:, **opts)
      @client.require_params("pendingReauth" => pending_reauth, "reauthSecret" => reauth_secret)
      @client.request("/auth/oauth/reauth/confirm", method: :post, body: { pendingReauth: pending_reauth, reauthSecret: reauth_secret }, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/oauth/links/confirm
    # Finish linking a provider. The provider round trip started with create_oauth_link returns the browser to
    # /Settings/Security with a single-use `pendingLink`; this links it, but only for the account the link was
    # started for, so a link URL opened in someone else's browser can't attach their provider to your account.
    # pending_link (sent as `pendingLink`): the `pendingLink` query parameter from the redirect.
    # Returns the caller's { passwordKnown, links }.
    def confirm_oauth_link(pending_link:, **opts)
      @client.require_params("pendingLink" => pending_link)
      @client.request("/auth/oauth/links/confirm", method: :post, body: { pendingLink: pending_link }, token: opts[:token], headers: opts[:headers])
    end

    # DELETE /auth/oauth/:provider/link
    # Unlink a sign-in provider (provider may be "sso") from the caller's account. Refused (400) if it is the
    # account's only way to sign in. Requires a fresh confirm_two_factor_identity from the same session (403 otherwise).
    def delete_oauth_link(provider:, **opts)
      @client.require_params("provider" => provider)
      @client.request("/auth/oauth/#{CGI.escape(provider.to_s)}/link", method: :delete, token: opts[:token], headers: opts[:headers])
    end

    # Build the URL that starts an OAuth sign-in for provider ("google", "microsoft", "apple" or "sso").
    # Navigate a browser to it; it is a redirect, not an API call. The API returns the user to the
    # portal's /auth/callback with a single-use ticket.
    # email (optional; required for "sso" sign-in): the address whose domain selects the group's SSO
    # connection. Not needed with a reauth_ticket.
    # link_ticket (optional; sent as `linkTicket`): the ticket from create_oauth_link, to link the provider
    # to the signed-in account instead of signing in.
    # reauth_ticket (optional; sent as `reauthTicket`): the ticket from create_oauth_reauth, to sign the
    # account in again with a linked provider to confirm it's them.
    # next_path (optional; sent as the `next` query parameter, named next_path here because `next`
    # is a Ruby keyword): a same-site path (e.g. "/oauth/consent?request=abc") to return the user to
    # after sign-in. The API hands it back on the /auth/callback redirect as `next`; anything that
    # isn't a rooted path on the portal is dropped.
    # Query keys are emitted in the order email, linkTicket, reauthTicket, next, and only when set.
    def get_oauth_authorization_url(provider:, next_path: nil, email: nil, link_ticket: nil, reauth_ticket: nil)
      @client.require_params("provider" => provider)
      url = "#{@client.base_url}/auth/oauth/#{CGI.escape(provider.to_s)}"
      query = [["email", email], ["linkTicket", link_ticket], ["reauthTicket", reauth_ticket], ["next", next_path]]
        .reject { |_key, value| value.nil? || value.to_s.empty? }
        .map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }
      url += "?#{query.join("&")}" unless query.empty?
      url
    end

    # POST /auth/oauth/ticket
    # Read what a single-use OAuth ticket resolves to without consuming it: a "session" (ready to
    # exchange), a "select" (pick one of several accounts) or a "signup" (finish registration).
    def read_oauth_ticket(ticket:, **opts)
      @client.require_params("ticket" => ticket)
      token = opts[:token]
      headers = opts[:headers]
      @client.request("/auth/oauth/ticket", method: :post, body: { ticket: ticket }, token: token, headers: headers)
    end

    # POST /auth/oauth/exchange
    # Exchange a single-use "session" or "select" OAuth ticket for a JWT. Consumes the ticket.
    # user_id is required for a "select" ticket: the chosen account from "accounts".
    def exchange_oauth_ticket(ticket:, user_id: nil, device_token: nil, **opts)
      @client.require_params("ticket" => ticket)
      token = opts[:token]
      headers = opts[:headers]
      body = { ticket: ticket }
      body[:userId] = user_id unless user_id.nil?
      body[:deviceToken] = device_token unless device_token.nil?
      @client.request("/auth/oauth/exchange", method: :post, body: body, token: token, headers: headers)
    end

    # GET /auth/2fa
    # The caller's two-factor settings: methods (targets masked), default, backup-code counts, trusted devices.
    def get_two_factor_settings(**opts)
      @client.request("/auth/2fa", method: :get, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/2fa/confirm-identity
    # Confirm it's really the account owner before a sensitive change: start_two_factor_enrollment,
    # remove_two_factor_method, regenerate_backup_codes, disable_two_factor, create_oauth_link, delete_oauth_link,
    # or groups.save_sso_connection / groups.delete_sso_connection. With 2FA on, pass a current code (or a backup
    # code); with 2FA off, pass the account password, or, for an account without a password of its own
    # (get_oauth_links returns passwordKnown: false), the code from send_two_factor_identity_code(method: "email")
    # with method: "email". A confirmation lasts 5 minutes, belongs to the session that made it, and unlocks
    # exactly one change. Returns { confirmed, expiresInSeconds }.
    def confirm_two_factor_identity(password: nil, code: nil, method: nil, using_backup_code: nil, **opts)
      body = { password: password, code: code, method: method, usingBackupCode: using_backup_code }.compact
      @client.request("/auth/2fa/confirm-identity", method: :post, body: body, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/2fa/confirm-identity/send
    # Send a code by an enrolled "sms" or "email" method to use with confirm_two_factor_identity (not needed for "app").
    # An account without a password of its own (passwordKnown false from get_oauth_links) uses "email" even with 2FA off.
    # Returns { sent, target, expiresInSeconds? }.
    def send_two_factor_identity_code(method:, **opts)
      @client.require_params("method" => method)
      @client.request("/auth/2fa/confirm-identity/send", method: :post, body: { method: method }, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/2fa/enroll
    # Start enrolling "app", "sms" or "email". App returns secret + otpauthUri; sms/email send a code.
    # Requires a fresh confirm_two_factor_identity from the same session (403 otherwise); each confirmation unlocks one change.
    def start_two_factor_enrollment(method:, phone: nil, address: nil, device_name: nil, **opts)
      @client.require_params("method" => method)
      body = { method: method, phone: phone, address: address, deviceName: device_name }.compact
      @client.request("/auth/2fa/enroll", method: :post, body: body, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/2fa/enroll/:enrollmentId/verify
    # Confirm a pending enrollment. The first method turns 2FA on and returns backup codes (shown once).
    def confirm_two_factor_enrollment(enrollment_id:, code:, **opts)
      @client.require_params("enrollmentId" => enrollment_id, "code" => code)
      safe_id = CGI.escape(enrollment_id.to_s)
      @client.request("/auth/2fa/enroll/#{safe_id}/verify", method: :post, body: { code: code }, token: opts[:token], headers: opts[:headers])
    end

    # PUT /auth/2fa/primary
    # Choose which enrolled method is offered first at sign-in.
    def set_two_factor_primary_method(method:, **opts)
      @client.require_params("method" => method)
      @client.request("/auth/2fa/primary", method: :put, body: { method: method }, token: opts[:token], headers: opts[:headers])
    end

    # DELETE /auth/2fa/methods/:method
    # Remove an enrolled method. Removing the last one turns 2FA off.
    # Requires a fresh confirm_two_factor_identity from the same session (403 otherwise); each confirmation unlocks one change.
    def remove_two_factor_method(method:, **opts)
      @client.require_params("method" => method)
      @client.request("/auth/2fa/methods/#{CGI.escape(method.to_s)}", method: :delete, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/2fa/backup-codes
    # Replace all backup codes (shown once); the previous codes stop working.
    # Requires a fresh confirm_two_factor_identity from the same session (403 otherwise); each confirmation unlocks one change.
    def regenerate_backup_codes(**opts)
      @client.request("/auth/2fa/backup-codes", method: :post, token: opts[:token], headers: opts[:headers])
    end

    # DELETE /auth/2fa/trusted-devices/:deviceId
    # Stop trusting a device, so its next sign-in asks for the second factor again.
    def revoke_trusted_device(device_id:, **opts)
      @client.require_params("deviceId" => device_id)
      @client.request("/auth/2fa/trusted-devices/#{CGI.escape(device_id.to_s)}", method: :delete, token: opts[:token], headers: opts[:headers])
    end

    # DELETE /auth/2fa
    # Turn 2FA off: removes every method, backup code and trusted device.
    # Requires a fresh confirm_two_factor_identity from the same session (403 otherwise); each confirmation unlocks one change.
    def disable_two_factor(**opts)
      @client.request("/auth/2fa", method: :delete, token: opts[:token], headers: opts[:headers])
    end

    # GET /auth/2fa/prompt
    # Whether the "secure your account" enrollment prompt is due.
    def get_two_factor_prompt(**opts)
      @client.request("/auth/2fa/prompt", method: :get, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/2fa/prompt/dismiss
    # Dismiss the prompt until the next sign-in; it stops for good after three dismissals.
    def dismiss_two_factor_prompt(**opts)
      @client.request("/auth/2fa/prompt/dismiss", method: :post, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/2fa/challenge/:challengeId/send
    # Send a sign-in code by "sms" or "email" (not needed for "app").
    def send_two_factor_challenge_code(challenge_id:, method:, **opts)
      @client.require_params("challengeId" => challenge_id, "method" => method)
      safe_id = CGI.escape(challenge_id.to_s)
      @client.request("/auth/2fa/challenge/#{safe_id}/send", method: :post, body: { method: method }, token: opts[:token], headers: opts[:headers])
    end

    # POST /auth/2fa/challenge/:challengeId/verify
    # Verify a sign-in code or backup code; returns { token, deviceToken? }.
    def verify_two_factor_challenge(challenge_id:, code:, method: nil, using_backup_code: nil, remember_device: nil, device_name: nil, **opts)
      @client.require_params("challengeId" => challenge_id, "code" => code)
      safe_id = CGI.escape(challenge_id.to_s)
      body = { code: code, method: method, usingBackupCode: using_backup_code, rememberDevice: remember_device, deviceName: device_name }.compact
      @client.request("/auth/2fa/challenge/#{safe_id}/verify", method: :post, body: body, token: opts[:token], headers: opts[:headers])
    end

    # DELETE /auth/2fa/challenge/:challengeId
    # Cancel a pending two-factor challenge.
    def cancel_two_factor_challenge(challenge_id:, **opts)
      @client.require_params("challengeId" => challenge_id)
      @client.request("/auth/2fa/challenge/#{CGI.escape(challenge_id.to_s)}", method: :delete, token: opts[:token], headers: opts[:headers])
    end

    class Admin
      def initialize(client)
        @client = client
      end

      # DELETE /auth/2fa/users/:userId
      # Turn 2FA off for a user who has lost every factor (lockout recovery). Staff only; audited.
      def reset_user_two_factor(user_id:, **opts)
        @client.require_params("userId" => user_id)
        @client.request("/auth/2fa/users/#{CGI.escape(user_id.to_s)}", method: :delete, token: opts[:token], headers: opts[:headers])
      end
    end
  end
end
