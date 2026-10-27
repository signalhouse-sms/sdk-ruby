# frozen_string_literal: true

module SignalHouseSms
  # Billing domain.
  #
  # Date-range parameters (start_date, end_date) on list and history methods
  # accept ISO-8601 date or timestamp strings. The server normalizes them to
  # full UTC-day boundaries: start_date -> start-of-UTC-day, end_date -> end-of-
  # UTC-day. The end day is always included; hourly resolution is not supported.
  class Billing
    def initialize(client, _enable_admin)
      @client = client
    end

    # GET /billing/wallet/transactionHistory?...
    def get_transaction_history(group_id: nil, subgroup_id: nil, brand_id: nil, campaign_id: nil, entry_type: nil, transaction_type: nil, start_date: nil, end_date: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, brandId: brand_id, campaignId: campaign_id, entryType: entry_type, transactionType: transaction_type, startDate: start_date, endDate: end_date)
      @client.request("/billing/wallet/transactionHistory#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /billing/wallet/paymentHistory?...
    def get_payment_history(group_id:, start_date:, end_date:, page: nil, limit: nil, timezone: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, startDate: start_date, endDate: end_date, page: page, limit: limit, timezone: timezone)
      @client.request("/billing/wallet/paymentHistory#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /billing/wallet/:groupId
    def get_wallet(group_id:, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      @client.request("/billing/wallet/#{safe_group_id}", method: :get, token: token, headers: headers)
    end

    # PUT /billing/wallet/:groupId
    def update_wallet(group_id:, auto_recharge_enabled: nil, auto_recharge_threshold: nil, auto_recharge_to_amount: nil, primary_payment_method_id: nil, secondary_payment_method_id: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      body = {
        autoRechargeEnabled: auto_recharge_enabled,
        autoRechargeThreshold: auto_recharge_threshold,
        autoRechargeToAmount: auto_recharge_to_amount,
        primaryPaymentMethodId: primary_payment_method_id,
        secondaryPaymentMethodId: secondary_payment_method_id
      }
      @client.request("/billing/wallet/#{safe_group_id}", method: :put, body: body, token: token, headers: headers)
    end

    # GET /billing/wallet/paymentMethods/:groupId
    def get_payment_methods(group_id:, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      @client.request("/billing/wallet/paymentMethods/#{safe_group_id}", method: :get, token: token, headers: headers)
    end

    # POST /billing/wallet/addfunds/:groupId
    def add_funds(group_id:, amount:, payment_method_id: nil, **opts)
      @client.require_params("groupId" => group_id, "amount" => amount)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      @client.request("/billing/wallet/addfunds/#{safe_group_id}", method: :post, body: { amount: amount, paymentMethodId: payment_method_id }, token: token, headers: headers)
    end

    # POST /billing/wallet/paymentMethod/:groupId
    def add_payment_method(group_id:, payment_method_id:, **opts)
      @client.require_params("groupId" => group_id, "paymentMethodId" => payment_method_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      @client.request("/billing/wallet/paymentMethod/#{safe_group_id}", method: :post, body: { paymentMethodId: payment_method_id }, token: token, headers: headers)
    end

    # DELETE /billing/wallet/paymentMethod/:groupId/:paymentMethodId
    def remove_payment_method(group_id:, payment_method_id:, **opts)
      @client.require_params("groupId" => group_id, "paymentMethodId" => payment_method_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      safe_payment_method_id = CGI.escape(payment_method_id.to_s)
      @client.request("/billing/wallet/paymentMethod/#{safe_group_id}/#{safe_payment_method_id}", method: :delete, token: token, headers: headers)
    end

    # GET /billing/invoiceDetails?...
    def get_invoice_details(group_id: nil, subgroup_id: nil, start_date: nil, end_date: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, startDate: start_date, endDate: end_date)
      @client.request("/billing/invoiceDetails#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /billing/fees/:groupId
    # When the group is on a custom volume-tiered plan, the response also includes volumePricing: tiers, the current period's dates, count and minimum, ramp, and current rate (rates in microdollars per segment).
    def get_fees(group_id:, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_group_id = CGI.escape(group_id.to_s)
      @client.request("/billing/fees/#{safe_group_id}", method: :get, token: token, headers: headers)
    end
  end
end
