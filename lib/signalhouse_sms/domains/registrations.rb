# frozen_string_literal: true

module SignalHouseSms
  # Sender registrations: the catalog, quotes, submission and status tracking for every jurisdiction.
  class Registrations
    attr_reader :admin

    def initialize(client, enable_admin)
      @client = client
      @admin = Admin.new(client) if enable_admin
    end

    # GET /registration/catalog?region=...
    # The registration types a jurisdiction offers and whether each can be acquired right now:
    # { region, jurisdiction, sendingRequiresRegistration, registeredThrough, provisioning, types: [{ type, kind, channel,
    # bundles, quantity: { min, max }, requiresParent, available }] }. region is US, GB, CA or AU (any case of "UK"/"GB"/"GBR"/"United Kingdom"
    # is accepted for GB).
    def get_catalog(region:, **opts)
      @client.require_params("region" => region)
      qs = @client.get_query_string(region: region)
      @client.request("/registration/catalog#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /registration/quotes?region=...&type=...&quantity=...
    # Setup and monthly prices, in integer microdollars, for each capability bundle of a type. data is one quote per
    # bundle: { capabilities, quantity, currency, setupAmount, monthlyAmount, totalSetupAmount, totalMonthlyAmount,
    # etaDays }; setupAmount/monthlyAmount are per sender and the totals cover quantity (1-100, default 1).
    # group_id is staff-only and quotes on behalf of another group. type is e.g. VIRTUAL_LONG_CODE, or
    # ALPHANUMERIC_SENDER_ID for GB (one ["SMS"] bundle, 6000000 setup and 6000000 monthly by default).
    def get_quotes(region:, type:, quantity: 1, group_id: nil, **opts)
      @client.require_params("region" => region, "type" => type)
      qs = @client.get_query_string(region: region, type: type, quantity: quantity, groupId: group_id)
      @client.request("/registration/quotes#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /registration?...
    # region filters by one jurisdiction or a list (String or Array, sent comma-separated).
    # kind is identity, program or sender. status filters by one registration status or a list (String or Array,
    # sent comma-separated) from DRAFT, SIGNAL_HOUSE_REVIEW, SIGNAL_HOUSE_APPROVED,
    # SIGNAL_HOUSE_REJECTED, SUBMITTING, PENDING_PROVIDER, NEEDS_INFORMATION, PAYMENT_REQUIRED, APPROVED, REJECTED,
    # CANCELLED, PENDING_DELETE, DELETED, EXPIRED, RECONCILIATION_REQUIRED. limit is at most 100.
    # phone_number filters to registrations holding this phone number.
    # sort_by is createdAt (default), subgroupId, registrationId, region or status; sort_order is asc or desc (default).
    # Response: { data, totalCount, page, limit }.
    def get_registrations(group_id: nil, subgroup_id: nil, region: nil, type: nil, kind: nil, status: nil,
                          parent_registration_id: nil, phone_number: nil, sort_by: nil, sort_order: nil, page: nil,
                          limit: nil, **opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, region: region, type: type, kind: kind, status: status,
        parentRegistrationId: parent_registration_id, phoneNumber: phone_number, sortBy: sort_by, sortOrder: sort_order,
        page: page, limit: limit
      )
      @client.request("/registration#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /registration/:registrationId
    # The registration with its type data, review outcome and status history.
    def get_registration(registration_id:, **opts)
      @client.require_params("registrationId" => registration_id)
      safe_id = CGI.escape(registration_id.to_s)
      @client.request("/registration/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # DELETE /registration/:registrationId
    # Cancel a registration. Allowed from SIGNAL_HOUSE_REVIEW, SIGNAL_HOUSE_APPROVED, PENDING_PROVIDER,
    # NEEDS_INFORMATION, PAYMENT_REQUIRED and APPROVED (409 otherwise). Numbers already allocated stay on the account
    # and stop sending.
    def cancel_registration(registration_id:, **opts)
      @client.require_params("registrationId" => registration_id)
      safe_id = CGI.escape(registration_id.to_s)
      @client.request("/registration/#{safe_id}", method: :delete, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /registration
    # registration_data: { region, type, subgroupId, capabilities (one of the type's
    # bundles), data }. type selects the data shape; for VIRTUAL_LONG_CODE it is { quantity (1-100), useCases (1-10),
    # voice? } with voice required exactly when capabilities include VOICE. For GB ALPHANUMERIC_SENDER_ID
    # (capabilities ["SMS"]) it is { requestedSenderId (3-11 letters/digits/space/dot/dash, at least one letter),
    # trafficOrigin (LOCAL | INTERNATIONAL), trafficType (TRANSACTIONAL | PROMOTIONAL), companyName, companyCountry,
    # companyWebsite, industry, messageExample, senderRelationship? } with senderRelationship required when
    # requestedSenderId differs from companyName; quantity is always 1 and data.phoneNumbers carries the granted
    # sender (e.g. ["ACME"]) once APPROVED. Pass idempotency_key: to make a retry
    # safe. Returns 201 with the new registration.
    def create_registration(registration_data:, **opts)
      @client.require_params("registrationData" => registration_data)
      @client.request("/registration", method: :post, body: registration_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # Staff-only registration review and recovery. Enabling the SDK admin namespace grants no server permission.
    class Admin
      def initialize(client)
        @client = client
      end

      # POST /registration/:registrationId/review
      # action is "APPROVE" (submits the registration to the provider) or "REJECT"; reason is required for REJECT.
      def review_registration(registration_id:, action:, reason: nil, **opts)
        @client.require_params("registrationId" => registration_id, "action" => action)
        safe_id = CGI.escape(registration_id.to_s)
        body = { action: action }
        body[:reason] = reason unless reason.nil?
        @client.request("/registration/#{safe_id}/review", method: :post, body: body, token: opts[:token], headers: HttpClient.headers_for(opts))
      end

      # POST /registration/:registrationId/corrections
      # Saves the type's correctable fields (VIRTUAL_LONG_CODE: useCases, voice?) for a registration the provider
      # sent back for more information. Owner, quantity, bundle and provider order are fixed.
      def correct_registration(registration_id:, reason:, data:, **opts)
        @client.require_params("registrationId" => registration_id, "reason" => reason, "data" => data)
        safe_id = CGI.escape(registration_id.to_s)
        @client.request("/registration/#{safe_id}/corrections", method: :post, body: { reason: reason, data: data }, token: opts[:token], headers: HttpClient.headers_for(opts))
      end

      # POST /registration/:registrationId/numbers
      # Allocate a provider-owned number (10-15 digits, optional leading +) through the staff recovery path.
      def add_number(registration_id:, phone_number:, **opts)
        @client.require_params("registrationId" => registration_id, "phoneNumber" => phone_number)
        safe_id = CGI.escape(registration_id.to_s)
        @client.request("/registration/#{safe_id}/numbers", method: :post, body: { phoneNumber: phone_number }, token: opts[:token], headers: HttpClient.headers_for(opts))
      end

      # POST /registration/:registrationId/reconcile
      # Link a RECONCILIATION_REQUIRED registration to the provider order that was actually placed. Never place a
      # second order to retry an ambiguous submission.
      def reconcile(registration_id:, external_id:, **opts)
        @client.require_params("registrationId" => registration_id, "externalId" => external_id)
        safe_id = CGI.escape(registration_id.to_s)
        @client.request("/registration/#{safe_id}/reconcile", method: :post, body: { externalId: external_id }, token: opts[:token], headers: HttpClient.headers_for(opts))
      end

      # GET /registration/:registrationId/application?format=json
      # The completed carrier application as { filename, contentType, base64 }; decode base64 to save the file.
      def get_application(registration_id:, **opts)
        @client.require_params("registrationId" => registration_id)
        safe_id = CGI.escape(registration_id.to_s)
        @client.request("/registration/#{safe_id}/application?format=json", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
      end
    end
  end
end
