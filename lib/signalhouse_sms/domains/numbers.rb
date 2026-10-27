# frozen_string_literal: true

module SignalHouseSms
  class Numbers
    attr_reader :admin

    def initialize(client, multipart_client, enable_admin)
      @client = client
      @multipart_client = multipart_client
      @admin = Admin.new(client) if enable_admin
    end

    # GET /number?...
    # Every record carries a `sentiment` object -- trailing 7-day and 30-day inbound reply sentiment,
    # refreshed periodically from analytics rather than computed per request: `{ sevenDay, thirtyDay,
    # updatedAt }`, each window being `{ score, label, scoredCount, positive, neutral, negative }`. The
    # object is always present and fully populated, so it can be read without a presence check.
    # `score` is a volume-weighted average in -100..100 and is null when nothing was scored in the
    # window, which is not the same as a score of 0 -- null means nobody replied, 0 means replies
    # averaged neutral. `updatedAt` is null until the first rollup writes the record, and it tracks when
    # the figures last CHANGED, not when the job last ran.
    #
    # Every record also carries a `health` object -- trailing 7-day and 30-day delivery/opt-out health from
    # the same periodic refresh: `{ sevenDay, thirtyDay, updatedAt }`, each window being `{ score,
    # deliveryRate, optOutRate, deliveryScore, optOutScore, messagesSent, messagesDelivered, messagesFailed,
    # optOuts }`. `score` is 1.0..10.0 (the mean of the two bucket scores) and is null when nothing was sent
    # in the window; the volumes say how much traffic sits behind it. A campaign's figure is scored from the
    # campaign's own summed counters, never averaged from its numbers. For a live figure use GET /number/health
    # or GET /campaign/health.
    # registration_id filters to numbers provisioned under this registration.
    # current_toll_free_carrier: true, with group_id or subgroup_id, returns only toll-free numbers from the group's
    # current toll-free carrier, the ones a new toll-free campaign in that group can use.
    def get_phone_numbers(phone_number: nil, campaign_id: nil, registration_id: nil, brand_id: nil, subgroup_id: nil, group_id: nil, page: nil, limit: nil, current_toll_free_carrier: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(phoneNumber: phone_number, campaignId: campaign_id, registrationId: registration_id, brandId: brand_id, subgroupId: subgroup_id, groupId: group_id, page: page, limit: limit,
                                    currentTollFreeCarrier: current_toll_free_carrier)
      @client.request("/number#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /number/health?...
    # Return the health score, the same one the portal shows, (1–10) for an owned phone number.
    def get_number_health(phone_number:, **opts)
      @client.require_params("phoneNumber" => phone_number)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(phoneNumber: phone_number)
      @client.request("/number/health#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /number/available?...
    # City is a prefix requiring country US and state.
    def get_available_phone_numbers(sms_enabled: nil, mms_enabled: nil, voice_enabled: nil, country: nil, state: nil, city: nil, npa: nil, nxx: nil, phone_number: nil, limit: nil, page: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(smsEnabled: sms_enabled, mmsEnabled: mms_enabled, voiceEnabled: voice_enabled, country: country, state: state, city: city, npa: npa, nxx: nxx, phoneNumber: phone_number, limit: limit, page: page)
      @client.request("/number/available#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /number
    #
    # Purchase phone numbers and assign them to a subgroup. Each requested number is queued
    # and processed independently. Per-number success or failure is delivered via
    # NUMBER_PURCHASE_SUCCESSFUL / NUMBER_PURCHASE_FAILED webhooks — not in this response.
    def purchase_phone_number(phone_numbers:, subgroup_id:, country: "US", **opts)
      @client.require_params("phoneNumbers" => phone_numbers, "subgroupId" => subgroup_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number", method: :post, body: { phoneNumbers: phone_numbers, subgroupId: subgroup_id, country: country }, token: token, headers: headers)
    end

    # POST /number/toll-free
    #
    # Purchase one or more Toll-Free numbers via the asynchronous resource-request flow. Toll-Free
    # numbers are ordered by quantity (1-10, not picked individually) and provisioned asynchronously;
    # per-number completion is delivered via webhook/polling, not in this response. Poll the returned
    # orderId with get_toll_free_order_status.
    def purchase_toll_free_numbers(quantity:, subgroup_id:, country: "US", **opts)
      @client.require_params("subgroupId" => subgroup_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number/toll-free", method: :post, body: { quantity: quantity, subgroupId: subgroup_id, country: country }, token: token, headers: headers)
    end

    # POST /number/short-code
    #
    # Request a campaign-bound Short Code acquisition or register a customer-owned Registry lease.
    # RANDOM and VANITY requests are fulfilled by Signal House staff. EXTERNAL_LEASE creates a pending Short Code
    # number immediately; it becomes READY only when its campaign becomes ACTIVE. A YYYY-MM-DD lease end date
    # expires at 23:59:59 UTC.
    def request_short_code_acquisition(subgroup_id:, brand_id:, campaign_id:, request_type:, lease_term_months: nil, requested_vanity_code: nil, actual_code: nil, order_id: nil, lease_end_date: nil, lease_receipt_file: nil, **opts)
      @client.require_params("subgroupId" => subgroup_id, "brandId" => brand_id, "campaignId" => campaign_id, "requestType" => request_type)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      form_data = { "acquisitionData" => { subgroupId: subgroup_id, brandId: brand_id, campaignId: campaign_id, requestType: request_type, leaseTermMonths: lease_term_months, requestedVanityCode: requested_vanity_code, actualCode: actual_code, orderId: order_id, leaseEndDate: lease_end_date }.to_json }
      form_data["leaseReceipt"] = lease_receipt_file if lease_receipt_file
      @multipart_client.request("/number/short-code", method: :post, body: form_data, token: token, headers: headers)
    end

    # GET /number/toll-free/order/:orderId
    #
    # Read the outcome of a Toll-Free number purchase by its order id. Reports per-number
    # ready/provisioning/failed counts (plus failure reasons) and the provisioned numbers; numbers
    # fills in as the order completes, so poll until the order reaches a terminal state.
    def get_toll_free_order_status(order_id:, **opts)
      @client.require_params("orderId" => order_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_order_id = CGI.escape(order_id.to_s)
      @client.request("/number/toll-free/order/#{safe_order_id}", method: :get, token: token, headers: headers)
    end

    # PUT /number/:phoneNumber
    def update_phone_number(phone_number:, update_data:, **opts)
      @client.require_params("phoneNumber" => phone_number, "updateData" => update_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_phone_number = CGI.escape(phone_number.to_s)
      @client.request("/number/#{safe_phone_number}", method: :put, body: update_data, token: token, headers: headers)
    end

    # GET /number/:phoneNumber/cnam
    # Get a phone number's outbound caller name (CNAM) - the name US carriers show for calls from it.
    # Roles: api, admin, developer, billing, user.
    # Returns { phoneNumber, cnam, autoApply, eligible, ineligibleReason }.
    def get_caller_name(phone_number:, **opts)
      @client.require_params("phoneNumber" => phone_number)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_phone_number = CGI.escape(phone_number.to_s)
      @client.request("/number/#{safe_phone_number}/cnam", method: :get, token: token, headers: headers)
    end

    # PUT /number/:phoneNumber/cnam
    # Set a phone number's outbound caller name (CNAM). The name may only remove characters from the
    # registered name of the number's brand (its campaign's brand, else brand_id, else the subgroup's
    # default caller-ID brand), and must be 1-15 letters, digits, spaces, - or _.
    # brand_id is only for numbers with no campaign, and is sent only when provided.
    # Roles: api, admin, developer.
    # Returns { phoneNumber, cnam, autoApply, eligible, ineligibleReason }.
    def set_caller_name(phone_number:, name:, brand_id: nil, **opts)
      @client.require_params("phoneNumber" => phone_number, "name" => name)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_phone_number = CGI.escape(phone_number.to_s)
      body = { name: name }
      body[:brandId] = brand_id if brand_id && !brand_id.to_s.empty?
      @client.request("/number/#{safe_phone_number}/cnam", method: :put, body: body, token: token, headers: headers)
    end

    # DELETE /number/:phoneNumber/cnam
    # Remove a phone number's own caller name (CNAM). If its subgroup has caller name auto-apply on,
    # the number goes back to the automatic name.
    # Roles: api, admin, developer.
    # Returns { phoneNumber, cnam, autoApply, eligible, ineligibleReason }.
    def delete_caller_name(phone_number:, **opts)
      @client.require_params("phoneNumber" => phone_number)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_phone_number = CGI.escape(phone_number.to_s)
      @client.request("/number/#{safe_phone_number}/cnam", method: :delete, token: token, headers: headers)
    end

    # POST /number/portin
    # Submit a port-in request for one or more phone numbers from another provider.
    def port_in_phone_number(number_data:, **opts)
      @client.require_params("numberData" => number_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number/portin", method: :post, body: number_data, token: token, headers: headers)
    end

    # GET /number/portin?...
    # Get port-in requests with optional filters.
    # Signal House staff can view all requests; regular users see only their group's requests.
    # exclude_documents: true leaves signatureUrl and billingUrl out of each request.
    def get_port_requests(group_id: nil, phone_number: nil, status: nil, page: nil, limit: nil, exclude_documents: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, phoneNumber: phone_number, status: status, page: page, limit: limit,
                                    excludeDocuments: exclude_documents)
      @client.request("/number/portin#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /number/portin/:id
    # Get a single port-in request by its ID.
    def get_port_request_by_id(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/number/portin/#{safe_id}", method: :get, token: token, headers: headers)
    end

    # Convenience method: fetches a single porting request by ID when porting_id is provided,
    # otherwise lists porting requests with optional filters.
    def get_porting_requests(porting_id: nil, page: nil, limit: nil, **opts)
      if porting_id
        get_port_request_by_id(id: porting_id, **opts)
      else
        get_port_requests(page: page, limit: limit, **opts)
      end
    end

    # POST /number/assign/:campaignId
    # Numbers that are not found, already RELEASED, already assigned to a different campaign, on a
    # mismatched DCA, or (for a 10DLC campaign without a number pool) beyond the remaining 49-number limit
    # are not queued; the response resolves to { "Message" => ..., "queued" => [...], "skipped" => [...] },
    # where skipped entries were rejected individually for one of those reasons. A Toll-Free campaign whose
    # brand reports tollFree.maxNumbersPerCampaign as 1 holds one number: a request that would give it a
    # second is refused with a 400 and nothing is queued.
    def assign_phone_number_to_campaign(campaign_id:, phone_numbers:, **opts)
      @client.require_params("campaignId" => campaign_id, "phoneNumbers" => phone_numbers)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_campaign_id = CGI.escape(campaign_id.to_s)
      @client.request("/number/assign/#{safe_campaign_id}", method: :post, body: { phoneNumbers: phone_numbers }, token: token, headers: headers)
    end

    # POST /number/unassign
    def unassign_phone_numbers_from_campaigns(phone_numbers:, **opts)
      @client.require_params("phoneNumbers" => phone_numbers)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number/unassign", method: :post, body: { phoneNumbers: phone_numbers }, token: token, headers: headers)
    end

    # DELETE /number
    def delete_phone_numbers(phone_numbers:, **opts)
      @client.require_params("phoneNumbers" => phone_numbers)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number", method: :delete, body: { phoneNumbers: phone_numbers }, token: token, headers: headers)
    end

    # POST /number/deactivate
    def deactivate_phone_numbers(phone_numbers:, **opts)
      @client.require_params("phoneNumbers" => phone_numbers)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number/deactivate", method: :post, body: { phoneNumbers: phone_numbers }, token: token, headers: headers)
    end

    # POST /number/reactivate
    def reactivate_phone_numbers(phone_numbers:, **opts)
      @client.require_params("phoneNumbers" => phone_numbers)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number/reactivate", method: :post, body: { phoneNumbers: phone_numbers }, token: token, headers: headers)
    end

    # POST /number/transfer
    def transfer_phone_numbers(phone_numbers:, new_subgroup_id:, **opts)
      @client.require_params("phoneNumbers" => phone_numbers, "newSubgroupId" => new_subgroup_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number/transfer", method: :post, body: { phoneNumbers: phone_numbers, newSubgroupId: new_subgroup_id }, token: token, headers: headers)
    end

    # GET /number/lookup?...
    # Country may scope NPA/NXX filters; state and city cannot be combined with them.
    def search_npa_nxx(country: nil, state: nil, city: nil, npa: nil, nxx: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(country: country, state: state, city: city, npa: npa, nxx: nxx)
      @client.request("/number/lookup#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /number/lookup/location
    def lookup_locations(entries:, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number/lookup/location", method: :post, body: { entries: entries }, token: token, headers: headers)
    end

    # Migrate a phone number (or all numbers in a group) from v1 to v2.
    #
    # @param phone_number [String, nil] Phone number to migrate. If provided, group_id is ignored.
    # @param campaign_id [String, nil] Campaign ID to migrate all numbers for.
    # @param group_id [String, nil] Group ID to migrate all non-released numbers for.
    # @param opts [Hash] Additional request options (:token, :headers, :idempotency_key)
    # @return [Hash] API response
    def migrate_phone_number_to_v2(phone_number: nil, campaign_id: nil, group_id: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/number/migrate", method: :post, body: { phoneNumber: phone_number, campaignId: campaign_id, groupId: group_id }, token: token, headers: headers)
    end

    class Admin
      def initialize(client)
        @client = client
      end

      # PUT /number/portin/:id/status
      # Change the status of a port-in request (admin only). Infobip exposes no porting-status
      # API or webhook, so ON_HOLD and its reason are always staff-entered here.
      # @param status [String] PENDING, IN_PROGRESS, ON_HOLD, or REJECTED.
      # @param on_hold_reason [String, nil] Required when status is ON_HOLD (DOCUMENTATION_MISMATCH,
      #   ACCOUNT_INFO_INCORRECT, CARRIER_REJECTED, PENDING_CUSTOMER_ACTION, OTHER).
      def change_porting_status(porting_id:, status:, description: nil, on_hold_reason: nil, **opts)
        @client.require_params("portingId" => porting_id, "status" => status)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_id = CGI.escape(porting_id.to_s)
        body = { status: status }
        body[:description] = description unless description.nil?
        body[:onHoldReason] = on_hold_reason unless on_hold_reason.nil?
        @client.request("/number/portin/#{safe_id}/status", method: :put, body: body, token: token, headers: headers)
      end

      # POST /number/portin/:id/approve
      # Approve a port-in request (admin only).
      def approve_port_request(porting_id:, **opts)
        @client.require_params("portingId" => porting_id)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_id = CGI.escape(porting_id.to_s)
        @client.request("/number/portin/#{safe_id}/approve", method: :post, token: token, headers: headers)
      end

      # GET /number/short-code/requests — list campaign-bound Short Code acquisition requests.
      def get_short_code_acquisition_requests(page: nil, limit: nil, status: nil, search: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(page: page, limit: limit, status: status, search: search)
        @client.request("/number/short-code/requests#{qs}", method: :get, token: token, headers: headers)
      end
    end
  end
end
