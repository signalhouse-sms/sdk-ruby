# frozen_string_literal: true

module SignalHouseSms
  # RCS agents under /rcs/agent. An agent links one 10DLC brand and one 10DLC campaign: the campaign's numbers are the
  # SMS fallback, and the brand and campaign supply the company identity and consent text for the carrier launch. One
  # brand or campaign can serve many agents. An agent is a registration (type RCS_AGENT, id RCSA...), so the
  # registrations methods read and edit the same record. 404 while the environment's RCS switch is off; 400 while the
  # group's rcsEnabled flag is off.
  class RcsAgents
    # Default for campaign_id, use_case and default_fallback: leaving one out omits it and nil sends null.
    UNSET = Object.new.freeze

    def initialize(client, multipart_client)
      @client = client
      @multipart_client = multipart_client
    end

    # POST /rcs/agent
    # Create an agent draft on a 10DLC brand (carrier brand ID, provisional UUID or _id), optionally with campaign_id, a
    # campaign ID or _id of that brand (required before submit). The agent's subgroup is the brand's. agent is the
    # profile { name, description, color, logoUrl, heroUrl, phone, website, email, phoneLabel, websiteLabel, emailLabel
    # (captions, max 40; submit defaults them to Call, Website and Email), privacyPolicyUrl, termsUrl }; consent is the
    # launch text, every field required before the launch request, and blank consent fields fill from the linked
    # campaign; contact is { firstName, lastName, role, email, mobile }, the individual at the brand the carrier
    # partner's reviewers may write to, required in full before the launch request. use_case
    # is OTP, TRANSACTIONAL, PROMOTIONAL or MULTI_USE (required before submit); billing_category defaults to
    # NON_CONVERSATIONAL and submit refuses CONVERSATIONAL; default_fallback is { mode, channel, from }; excluded_carriers
    # is [] or ["T_MOBILE"] (the carrier partner's carrier name); testers holds up to 200 tester numbers. Returns 201
    # with the agent (status DRAFT).
    def create(brand_id:, campaign_id: UNSET, agent: nil, consent: nil, contact: nil, use_case: UNSET, billing_category: nil,
               default_fallback: UNSET, excluded_carriers: nil, testers: nil, **opts)
      @client.require_params("brandId" => brand_id)
      payload = agent_payload(brand_id, campaign_id, agent, consent, use_case, billing_category, default_fallback,
                              excluded_carriers, testers, contact)
      @client.request("/rcs/agent", method: :post, body: payload, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /rcs/agent?...
    # List agents, newest first. status is DRAFT, PENDING_REVIEW, REJECTED, AGENT_CREATING or ARCHIVED, one or a list
    # (String or Array, sent comma-separated). brand_id / campaign_id return the agents linked to that 10DLC brand or
    # campaign. limit defaults to 25 (max 100). Response: { data: [agents], total, page, limit }.
    def list(group_id: nil, subgroup_id: nil, status: nil, brand_id: nil, campaign_id: nil, page: nil, limit: nil, **opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, status: status, brandId: brand_id, campaignId: campaign_id,
        page: page, limit: limit
      )
      @client.request("/rcs/agent#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /rcs/agent/:agentId
    # One agent with the live state of its brand and campaign links.
    def get(agent_id:, **opts)
      agent_request(agent_id, "", :get, nil, opts)
    end

    # PUT /rcs/agent/:agentId
    # Edit an agent while it may change: a draft, a Signal House rejection, a request for changes, or an agent in
    # testing (the change is pushed to the carrier partner); only the arguments passed are sent. agent, consent and
    # contact merge field by field and every other key replaces. brand_id relinks to another 10DLC brand of the same
    # subgroup (locked once the agent exists at the partner); campaign_id: nil unlinks the campaign; use_case: nil and
    # default_fallback: nil clear those fields; billing_category is locked once a launch was requested. 409 in any
    # other status. Returns the agent.
    def update(agent_id:, brand_id: nil, campaign_id: UNSET, agent: nil, consent: nil, contact: nil, use_case: UNSET,
               billing_category: nil, default_fallback: UNSET, excluded_carriers: nil, testers: nil, **opts)
      payload = agent_payload(brand_id, campaign_id, agent, consent, use_case, billing_category, default_fallback,
                              excluded_carriers, testers, contact)
      agent_request(agent_id, "", :put, payload, opts)
    end

    # POST /rcs/agent/:agentId/validate
    # Check an agent against every submit requirement without writing.
    # Returns { valid, errors: [{ field, reason }], warnings: [{ field, reason }] }.
    def validate(agent_id:, **opts)
      agent_request(agent_id, "/validate", :post, nil, opts)
    end

    # POST /rcs/agent/:agentId/submit
    # Submit a draft: create the agent at the carrier partner, with no review first. It needs the full profile, a use
    # case and NON_CONVERSATIONAL billing; otherwise a 400 whose details carry { code: "REGISTRATION_INCOMPLETE",
    # errors, warnings }. Returns the agent (status AGENT_CREATING, then IN_TESTING once the partner reports it ready).
    def submit(agent_id:, **opts)
      agent_request(agent_id, "/submit", :post, nil, opts)
    end

    # POST /registration/:agentId/launch (the agent is a registration)
    # Request the agent's launch: the launch requirements are checked and the agent goes to Signal House review (status
    # PENDING_REVIEW), whose approval files the launch with the carrier partner. Allowed from IN_TESTING, REJECTED and
    # CARRIER_REJECTED (409 otherwise); a failed requirement is a 400 whose details carry
    # { code: "REGISTRATION_INCOMPLETE", errors, warnings }. Returns the agent (status PENDING_REVIEW).
    def launch(agent_id:, **opts)
      @client.require_params("agentId" => agent_id)
      safe_id = CGI.escape(agent_id.to_s)
      @client.request("/registration/#{safe_id}/launch", method: :post, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /rcs/agent/:agentId/archive
    # Archive an agent. Returns the agent (status ARCHIVED).
    def archive(agent_id:, **opts)
      agent_request(agent_id, "/archive", :post, nil, opts)
    end

    # POST /rcs/agent/:agentId/testers/:phoneNumber/resend
    # Resend a tester's expired invitation, which starts a new 24 hours for the tester to accept it. phone_number is a US
    # number, with or without the +. The number must be a tester on the agent (404) and its invitation must be EXPIRED
    # (409); up to 20 invitations go out a day (429). Returns the agent.
    def resend_tester_invite(agent_id:, phone_number:, **opts)
      @client.require_params("phoneNumber" => phone_number)
      agent_request(agent_id, "/testers/#{CGI.escape(phone_number.to_s)}/resend", :post, nil, opts)
    end

    # POST /rcs/agent/:agentId/asset (multipart: kind, file)
    # Host the agent's logo (224 x 224 px, 50 KB max) or hero image (1440 x 448 px, 200 KB max), PNG or JPEG, and set
    # it on the draft; images of any other size are refused. kind is "logo" or "hero". file is an IO or a
    # { filename:, io:, content_type: } hash; file_name names an IO part. Returns the agent with the new URL.
    def upload_asset(agent_id:, kind:, file:, file_name: nil, **opts)
      @client.require_params("agentId" => agent_id, "kind" => kind, "file" => file)
      safe_id = CGI.escape(agent_id.to_s)
      @multipart_client.request("/rcs/agent/#{safe_id}/asset", method: :post, body: asset_form(kind, file, file_name),
                                                               token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    private

    # Send a JSON request to /rcs/agent/:agentId plus suffix after checking agent_id.
    def agent_request(agent_id, suffix, method, body, opts)
      @client.require_params("agentId" => agent_id)
      safe_id = CGI.escape(agent_id.to_s)
      @client.request("/rcs/agent/#{safe_id}#{suffix}", method: method, body: body, token: opts[:token],
                                                         headers: HttpClient.headers_for(opts))
    end

    # Agent create/update body: nil omits a field, except campaign_id, use_case and default_fallback, where UNSET omits
    # it and nil sends null.
    def agent_payload(brand_id, campaign_id, agent, consent, use_case, billing_category, default_fallback,
                      excluded_carriers, testers, contact = nil)
      payload = { brandId: brand_id, agent: agent, consent: consent, contact: contact, billingCategory: billing_category,
                  excludedCarriers: excluded_carriers, testers: testers }.compact
      { campaignId: campaign_id, useCase: use_case, defaultFallback: default_fallback }.each do |key, value|
        payload[key] = value unless value.equal?(UNSET)
      end
      payload
    end

    # Multipart fields kind and file; an IO part is named file_name, its path's basename, or "upload".
    def asset_form(kind, file, file_name)
      part = if file.is_a?(Hash)
               file_name.nil? ? file : file.merge(filename: file_name)
             else
               { filename: file_name || (file.respond_to?(:path) ? File.basename(file.path) : "upload"), io: file }
             end
      { "kind" => kind.to_s, "file" => part }
    end
  end

  # RCS (Google RBM) resources, accessed via `client.rcs`. Templates for RCS live under `client.templates`.
  #   * client.rcs.agents — RCS agents linked to a 10DLC brand and campaign
  class Rcs
    attr_reader :agents

    def initialize(client, multipart_client)
      @agents = RcsAgents.new(client, multipart_client)
    end
  end
end
