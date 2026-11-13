# frozen_string_literal: true

module SignalHouseSms
  # Carrier phone-number checks under /verify: SIM Swap and Number Verify. Every check the carrier answers is billed to
  # the group's wallet (402 on insufficient funds); a check the carrier cannot run for the number is a 422 and is not charged.
  class Verify
    def initialize(client, _enable_admin)
      @client = client
    end

    # POST /verify/sim-swap — whether a number's SIM card changed recently, as reported by its carrier.
    # Billed once when the check answers; 422 when the check is not available for the number (not charged).
    # Roles: api, admin, developer.
    #
    # @param phone_number [String] The number to check, in international format (e.g. "+12025550123")
    # @param max_age [Integer, nil] Lookback window in hours, 1-2400; nil uses the carrier's default
    # @param include_swap_date [Boolean, nil] Also return the latest SIM change date (no extra charge); nil uses the API default (false)
    # @return [Hash] {checkId, phoneNumber, swapped, maxAge, latestSimChange?, cost}
    # @raise [SignalHouseSms::ValidationError] If phone_number is missing
    def check_sim_swap(phone_number:, max_age: nil, include_swap_date: nil, **opts)
      @client.require_params("phoneNumber" => phone_number)
      body = { phoneNumber: phone_number, maxAge: max_age, includeSwapDate: include_swap_date }.compact
      @client.request("/verify/sim-swap", method: :post, body: body, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /verify/number — start a Number Verify check. The end user's phone must open the returned authorizationUrl
    # on mobile data (Wi-Fi off) within 10 minutes; read the result with get_number_verification. Billed only when the
    # check is answered (VERIFIED or NOT_VERIFIED). Roles: api, admin, developer.
    #
    # @param phone_number [String] The number to verify, in international format (e.g. "+12025550123")
    # @param device_phone_number [String, nil] The phone's own number, sent to the carrier as a login hint
    # @param redirect_url [String, nil] An https URL the end user's browser is sent to after the check, with ?checkId=…
    # @return [Hash] {checkId, phoneNumber, status: "PENDING", authorizationUrl, expiresAt}
    # @raise [SignalHouseSms::ValidationError] If phone_number is missing
    def start_number_verification(phone_number:, device_phone_number: nil, redirect_url: nil, **opts)
      @client.require_params("phoneNumber" => phone_number)
      body = { phoneNumber: phone_number, devicePhoneNumber: device_phone_number, redirectUrl: redirect_url }.compact
      @client.request("/verify/number", method: :post, body: body, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /verify/number/:checkId — a Number Verify check's status and result. A PENDING check past its expiresAt
    # reads as EXPIRED. Roles: api, admin, developer, billing, user.
    #
    # @param check_id [String] The check ID (e.g. "NVC…")
    # @return [Hash] {checkId, phoneNumber, status, devicePhoneNumberVerified, failureReason, createdAt, expiresAt, completedAt, cost}
    # @raise [SignalHouseSms::ValidationError] If check_id is missing
    def get_number_verification(check_id:, **opts)
      @client.require_params("checkId" => check_id)
      safe_check_id = CGI.escape(check_id.to_s)
      @client.request("/verify/number/#{safe_check_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
