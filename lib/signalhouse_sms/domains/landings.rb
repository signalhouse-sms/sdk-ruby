# frozen_string_literal: true

module SignalHouseSms
  class Landings
    def initialize(client, multipart_client, _enable_admin)
      @client = client
      @multipart_client = multipart_client
    end

    # GET /landing/:landingId
    def get_landings(landing_id:, **opts)
      @client.require_params("landingId" => landing_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_landing_id = CGI.escape(landing_id.to_s)
      @client.request("/landing/#{safe_landing_id}", method: :get, token: token, headers: headers)
    end

    # GET /landing/public/:landingId
    def get_public_landing(landing_id:, **opts)
      @client.require_params("landingId" => landing_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_landing_id = CGI.escape(landing_id.to_s)
      @client.request("/landing/public/#{safe_landing_id}", method: :get, token: token, headers: headers)
    end

    # POST /landing (multipart)
    # Optionally set registrationType to "TOLL_FREE" and supply tollFree
    # {useCases, channels, consentDisclosure, consentBoxes[{useCase, channel, text}]} to build a
    # Toll-Free page, which renders one consent checkbox per use case per channel. Set
    # useBrandTemplate: true (Toll-Free only) to build the page from the brand's landing page
    # template, taking its colours, logo and webhook URL from there; no logo file is then required.
    def create_landing(landing_data:, file: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)

      form_data = {}
      form_data["file"] = file if file
      landing_data.each do |key, value|
        next if value.nil?
        form_data[key.to_s] = value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value.to_s
      end

      @multipart_client.request("/landing", method: :post, body: form_data, token: token, headers: headers)
    end

    # PUT /landing/:landingId (multipart)
    # Set useBrandTemplate: true (Toll-Free only) to re-copy the brand's landing page template into
    # this page rather than creating a second one.
    def update_landing(landing_id:, landing_data:, file: nil, **opts)
      @client.require_params("landingId" => landing_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_landing_id = CGI.escape(landing_id.to_s)

      form_data = {}
      form_data["file"] = file if file
      landing_data.each do |key, value|
        next if value.nil?
        form_data[key.to_s] = value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value.to_s
      end

      @multipart_client.request("/landing/#{safe_landing_id}", method: :put, body: form_data, token: token, headers: headers)
    end

    # GET /landing/brand/:brandId
    def get_landing_by_brand_id(brand_id:, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      @client.request("/landing/brand/#{safe_brand_id}", method: :get, token: token, headers: headers)
    end

    # GET /landing/template/:brandId
    # The brand's Toll-Free landing page template: the reusable look every page it generates snapshots.
    def get_landing_template(brand_id:, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)
      @client.request("/landing/template/#{safe_brand_id}", method: :get, token: token, headers: headers)
    end

    # PUT /landing/template/:brandId (multipart)
    # template_data: userDescription (the customer's own sentence, not the finished About paragraph --
    # the services clause is added per campaign), the four colours, webhookUrl. The logo file is
    # required the first time only; omit it on a later save to keep the stored one.
    def upsert_landing_template(brand_id:, template_data:, file: nil, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_brand_id = CGI.escape(brand_id.to_s)

      form_data = {}
      form_data["file"] = file if file
      template_data.each do |key, value|
        next if value.nil?
        form_data[key.to_s] = value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value.to_s
      end

      @multipart_client.request("/landing/template/#{safe_brand_id}", method: :put, body: form_data, token: token, headers: headers)
    end

    # DELETE /landing/:landingId
    def delete_landing(landing_id:, **opts)
      @client.require_params("landingId" => landing_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_landing_id = CGI.escape(landing_id.to_s)
      @client.request("/landing/#{safe_landing_id}", method: :delete, token: token, headers: headers)
    end
  end
end
