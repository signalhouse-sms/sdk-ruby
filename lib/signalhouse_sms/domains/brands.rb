# frozen_string_literal: true

# Brand lookup id: carrier Brand ID (B… or TFNB…), record _id, or internal reference UUID.
# Read/create responses return brandId: null for pending brands — poll GET /brand?id=<record _id>.
module SignalHouseSms
  class Brands
    def initialize(client, multipart_client, _enable_admin)
      @client = client
      @multipart_client = multipart_client
    end

    # GET /brand?... — brandId may be null until carrier assignment; poll by record _id.
    # registration_type optionally filters by "TEN_DLC", "TOLL_FREE", or "SHORT_CODE".
    # Each brand carries `carrierSuspensions` (carrier brand suspension rules; active while liftedAt is null).
    # current_toll_free_carrier: true, with group_id or subgroup_id, returns only toll-free brands on the group's
    # current toll-free carrier, the ones a new toll-free campaign in that group can use.
    def get_brands(id: nil, subgroup_id: nil, group_id: nil, page: nil, limit: nil, status: nil, registration_type: nil, current_toll_free_carrier: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(id: id, subgroupId: subgroup_id, groupId: group_id, page: page, limit: limit, status: status, registrationType: registration_type,
                                    currentTollFreeCarrier: current_toll_free_carrier)
      @client.request("/brand#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /brand/externalvetting/:brandId — brandId path param is a brand lookup id.
    def get_external_vetting(brand_id:, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      @client.request("/brand/externalvetting/#{safe_brand_id}", method: :get, token: token, headers: headers)
    end

    # POST /brand — response brandId may be null until carrier assignment.
    def create_brand(brand_data:, **opts)
      @client.require_params("brandData" => brand_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/brand", method: :post, body: brand_data, token: token, headers: headers)
    end

    # POST /brand/toll-free — create a Toll-Free (TFN) brand.
    #
    # registrationType is forced to TOLL_FREE server-side; TFN-specific fields live under
    # brand_data[:tollFree] (businessRegistrationType, legalEntityType, taxId, countryCode,
    # supportPhone, and optional taxIdIssuingCountry / businessDBA / businessWebsite). supportPhone must be
    # E.164 with an optional leading "+" and no spaces, parentheses or hyphens (e.g. "17025550100").
    # For Toll-Free, brandId is a
    # TFNB-prefixed id when assigned; otherwise null — poll by record _id.
    #
    # tollFree.businessVerificationId names the business verification the brand uses (starts with BV). A group whose
    # toll-free brands need a business verification must send a VERIFIED one of the brand's group (in a group that
    # verifies each subgroup's business separately, of the brand's subgroup); any other group gets 400 if it sends one.
    # With it, the legal fields (companyName, street, city, state, postalCode, country, firstName, lastName and
    # tollFree's businessRegistrationType, taxId, countryCode and taxIdIssuingCountry) are optional: the business
    # verification's values replace any that are sent. It can't be changed after creation.
    def create_toll_free_brand(brand_data:, **opts)
      @client.require_params("brandData" => brand_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/brand/toll-free", method: :post, body: brand_data, token: token, headers: headers)
    end

    # GET /brand/business-verification/:groupId?subgroupId=...
    # List a group's business verifications, newest first, and whether its toll-free brands need one (required).
    # subgroup_id is sent only when given. A group that verifies each subgroup's business separately requires it.
    def get_business_verifications(group_id:, subgroup_id: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      qs = @client.get_query_string(subgroupId: subgroup_id)
      @client.request("/brand/business-verification/#{safe_group_id}#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /brand/business-verification/:groupId/:businessVerificationId
    # Get one of a group's business verifications by its ID, plus required. 404 when it isn't one of the group's.
    def get_business_verification(group_id:, business_verification_id:, **opts)
      @client.require_params("groupId" => group_id, "businessVerificationId" => business_verification_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      safe_business_verification_id = CGI.escape(business_verification_id.to_s)
      @client.request("/brand/business-verification/#{safe_group_id}/#{safe_business_verification_id}", method: :get, token: token, headers: headers)
    end

    # POST /brand/business-verification/:groupId?subgroupId=...
    # Create and submit a new business verification. Review usually takes 1–2 business days; once it is VERIFIED, a new
    # toll-free brand can use it as tollFree.businessVerificationId. subgroup_id is sent only when given and must name an
    # active subgroup of the group. A group that verifies each subgroup's business separately requires it.
    def create_business_verification(group_id:, details:, subgroup_id: nil, **opts)
      @client.require_params("groupId" => group_id, "details" => details)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      qs = @client.get_query_string(subgroupId: subgroup_id)
      @client.request("/brand/business-verification/#{safe_group_id}#{qs}", method: :post, body: details, token: token, headers: headers)
    end

    # PUT /brand/business-verification/:groupId/:businessVerificationId
    # Correct and resubmit a business verification. Allowed only while it needs changes (400 otherwise); the toll-free
    # brands that use it stay pending until it is verified.
    def update_business_verification(group_id:, business_verification_id:, details:, **opts)
      @client.require_params("groupId" => group_id, "businessVerificationId" => business_verification_id, "details" => details)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      safe_business_verification_id = CGI.escape(business_verification_id.to_s)
      @client.request("/brand/business-verification/#{safe_group_id}/#{safe_business_verification_id}", method: :put, body: details, token: token, headers: headers)
    end

    # GET /brand/toll-free-isv-account/:groupId — get a group's toll-free ISV account, its own parent account at the
    # toll-free provider; data is nil when it has none (signalhouse_api, signalhouse_admin or signalhouse_user only).
    def get_toll_free_isv_account(group_id:, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      @client.request("/brand/toll-free-isv-account/#{safe_group_id}", method: :get, token: token, headers: headers)
    end

    # PUT /brand/toll-free-isv-account/:groupId — register a group's toll-free ISV account, or replace the API key of the
    # one it has (signalhouse_admin only). The provider checks the account and key first; the secret is never returned.
    def set_toll_free_isv_account(group_id:, account_sid:, api_key_sid:, api_key_secret:, **opts)
      @client.require_params("groupId" => group_id, "accountSid" => account_sid, "apiKeySid" => api_key_sid, "apiKeySecret" => api_key_secret)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      body = { accountSid: account_sid, apiKeySid: api_key_sid, apiKeySecret: api_key_secret }
      @client.request("/brand/toll-free-isv-account/#{safe_group_id}", method: :put, body: body, token: token, headers: headers)
    end

    # POST /brand/short-code — create a local Short Code brand in PENDING_APPROVAL for manual review.
    # The route forces registrationType to SHORT_CODE and returns a synchronous 201 record with an
    # SCB-prefixed brandId.
    def create_short_code_brand(brand_data:, **opts)
      @client.require_params("brandData" => brand_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/brand/short-code", method: :post, body: brand_data, token: token, headers: headers)
    end

    # POST /brand/approve/:brandId — approve a pending Short Code brand (signalhouse_admin only).
    def approve_short_code_brand(brand_id:, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/brand/approve/#{CGI.escape(brand_id.to_s)}", method: :post, token: token, headers: headers)
    end

    # POST /brand/reject/:brandId — reject a pending Short Code brand with a required customer-visible reason (signalhouse_admin only).
    def reject_short_code_brand(brand_id:, internal_rejection_reason:, **opts)
      @client.require_params("brandId" => brand_id, "internalRejectionReason" => internal_rejection_reason)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/brand/reject/#{CGI.escape(brand_id.to_s)}", method: :post, body: { internalRejectionReason: internal_rejection_reason }, token: token, headers: headers)
    end

    # POST /brand/transfer/:subgroupId
    def transfer_brand(subgroup_id:, brand_ids:, **opts)
      @client.require_params("subgroupId" => subgroup_id, "brandIds" => brand_ids)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_subgroup_id = CGI.escape(subgroup_id.to_s)
      @client.request("/brand/transfer/#{safe_subgroup_id}", method: :post, body: { brandIds: brand_ids }, token: token, headers: headers)
    end

    # Create external vetting for a brand. vetting_provider_id is AEGIS or WMC; vetting_class is STANDARD,
    # ENHANCED, AUTHPLUS, or RCS (AEGIS accepts all four; WMC accepts STANDARD only). additional_data is
    # provider-specific data forwarded to TCR; omit it when there is none.
    #
    # POST /brand/externalvetting/:brandId
    def create_external_vetting(brand_id:, vetting_provider_id:, vetting_class:, additional_data: nil, **opts)
      @client.require_params("brandId" => brand_id, "vettingProviderId" => vetting_provider_id, "vettingClass" => vetting_class)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      body = { vettingProviderId: vetting_provider_id, vettingClass: vetting_class }
      body[:additionalData] = additional_data unless additional_data.nil?
      @client.request("/brand/externalvetting/#{safe_brand_id}", method: :post, body: body, token: token, headers: headers)
    end

    # Import an existing external vetting record for a brand.
    #
    # Unlike create_external_vetting (which orders a new, billable vetting), this attaches a vetting
    # the brand already completed directly with the provider, using the provider-issued vettingId
    # and vettingToken. It is synchronous and not billable. vetting_token is required by some
    # providers (e.g. AEGIS); omit it for providers that do not issue one.
    #
    # POST /brand/externalvetting/import/:brandId
    def import_external_vetting(brand_id:, vetting_provider_id:, vetting_id:, vetting_token: nil, **opts)
      @client.require_params("brandId" => brand_id, "vettingProviderId" => vetting_provider_id, "vettingId" => vetting_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      body = { vettingProviderId: vetting_provider_id, vettingId: vetting_id }
      body[:vettingToken] = vetting_token unless vetting_token.nil?
      @client.request("/brand/externalvetting/import/#{safe_brand_id}", method: :post, body: body, token: token, headers: headers)
    end

    # PUT /brand/:brandId
    # For a Toll-Free brand, pass the editable Toll-Free fields under a :tollFree sub-hash in
    # brand_data (legalEntityType, businessRegistrationType, taxId, countryCode, supportPhone,
    # taxIdIssuingCountry, businessDBA, businessWebsite); supportPhone must be E.164 with an optional
    # leading "+" and no spaces, parentheses or hyphens (e.g. "17025550100"); subgroupId is immutable.
    def update_brand(brand_id:, brand_data:, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      @client.request("/brand/#{safe_brand_id}", method: :put, body: brand_data, token: token, headers: headers)
    end

    # PUT /brand/revet/:brandId
    def revet_brand(brand_id:, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      @client.request("/brand/revet/#{safe_brand_id}", method: :put, token: token, headers: headers)
    end

    # DELETE /brand/:brandId
    def delete_brand(brand_id:, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      @client.request("/brand/#{safe_brand_id}", method: :delete, token: token, headers: headers)
    end

    # GET /brand/appeal/:brandId
    def get_appeal_history(brand_id:, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      @client.request("/brand/appeal/#{safe_brand_id}", method: :get, token: token, headers: headers)
    end

    # POST /brand/appeal/:brandId (multipart)
    def submit_appeal(brand_id:, appeal_categories:, explanation:, file:, **opts)
      @client.require_params("brandId" => brand_id, "appealCategories" => appeal_categories, "explanation" => explanation, "file" => file)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)

      form_data = {}
      form_data["file"] = file
      form_data["appealCategories"] = JSON.generate(appeal_categories)
      form_data["explanation"] = explanation.to_s

      @multipart_client.request("/brand/appeal/#{safe_brand_id}", method: :post, body: form_data, token: token, headers: headers)
    end
  end
end
