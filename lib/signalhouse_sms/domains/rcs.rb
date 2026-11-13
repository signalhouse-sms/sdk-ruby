# frozen_string_literal: true

module SignalHouseSms
  # RCS agents under /rcs/agent. An agent links one brand and one campaign, of any registration type: the campaign's
  # numbers are the SMS fallback, and the brand and campaign supply the company identity and consent text for the
  # carrier launch. One brand or campaign can serve many agents. An agent is a registration (type RCS_AGENT, id
  # RCSA...), so the registrations methods read and edit the same record. 404 while the environment's RCS switch is
  # off; 400 while the group's rcsEnabled flag is off.
  class RcsAgents
    # Default for campaign_id, use_case and default_fallback: leaving one out omits it and nil sends null.
    UNSET = Object.new.freeze

    def initialize(client, multipart_client)
      @client = client
      @multipart_client = multipart_client
    end

    # POST /rcs/agent
    # Create an agent draft on a brand (carrier brand ID, provisional UUID or _id), optionally with campaign_id, a
    # campaign ID or _id of that brand (required before submit). The agent's subgroup is the brand's. agent is the
    # profile { name, description, color, logoUrl, heroUrl, phone, website, email, phoneLabel, websiteLabel, emailLabel
    # (captions, max 40; submit defaults them to Call, Website and Email), privacyPolicyUrl, termsUrl }; consent is the
    # launch text, every field required before the launch request, and blank consent fields fill from the linked
    # campaign; contact is { firstName, lastName, role, email, mobile }, the individual at the brand the carrier
    # partner's reviewers may write to, required in full before the launch request. use_case
    # is OTP, TRANSACTIONAL, PROMOTIONAL or MULTI_USE (required before submit); billing_category is
    # NON_CONVERSATIONAL (default, per message) or CONVERSATIONAL (per interactive session); default_fallback is { mode, channel, from }; excluded_carriers
    # is [] or ["T_MOBILE"] (the carrier partner's carrier name); testers holds up to 200 tester numbers. Returns 201
    # with the agent (status DRAFT).
    # autofill says where the fields you prefilled came from, by path ("consent.optInDetails" => { source (brand,
    # campaign or landing), sourceId, at, edited }); the API adds its own for the fields it fills.
    def create(brand_id:, campaign_id: UNSET, agent: nil, consent: nil, contact: nil, use_case: UNSET, billing_category: nil,
               default_fallback: UNSET, excluded_carriers: nil, testers: nil, autofill: nil, **opts)
      @client.require_params("brandId" => brand_id)
      payload = agent_payload(brand_id, campaign_id, agent, consent, use_case, billing_category, default_fallback,
                              excluded_carriers, testers, contact, autofill)
      @client.request("/rcs/agent", method: :post, body: payload, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /rcs/agent?...
    # List agents, newest first. status is DRAFT, PENDING_REVIEW, REJECTED, AGENT_CREATING, ARCHIVE_PENDING or ARCHIVED, one or a list
    # (String or Array, sent comma-separated). brand_id / campaign_id return the agents linked to that brand or
    # campaign. limit defaults to 25 (max 100). Response: { data: [agents], total, page, limit }.
    def list(group_id: nil, subgroup_id: nil, status: nil, brand_id: nil, campaign_id: nil, page: nil, limit: nil, **opts)
      qs = @client.get_query_string(
        groupId: group_id, subgroupId: subgroup_id, status: status, brandId: brand_id, campaignId: campaign_id,
        page: page, limit: limit
      )
      @client.request("/rcs/agent#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /rcs/agent/:agentId
    # One agent with the live state of its brand and campaign links. googleAgentId is Google's id for the agent, nil until
    # Google has created it.
    def get(agent_id:, **opts)
      agent_request(agent_id, "", :get, nil, opts)
    end

    # PUT /rcs/agent/:agentId
    # Edit an agent while it may change: a draft, a Signal House rejection, a request for changes, or an agent in
    # testing (the change is pushed to the carrier partner); only the arguments passed are sent. agent, consent and
    # contact merge field by field and every other key replaces. brand_id relinks to another brand of the same
    # subgroup (locked once the agent exists at the partner); campaign_id: nil unlinks the campaign; use_case: nil and
    # default_fallback: nil clear those fields; billing_category is locked once a launch was requested. 409 in any
    # other status. After a carrier rejected a launch other carriers took (PARTIALLY_LAUNCHED with a REJECTED carrier),
    # only consent and contact may change, and nothing is pushed: send them with request_carrier_update. autofill
    # replaces the prefill markers; omitted, the stored ones are kept and a changed field's marker turns edited.
    # Returns the agent.
    def update(agent_id:, brand_id: nil, campaign_id: UNSET, agent: nil, consent: nil, contact: nil, use_case: UNSET,
               billing_category: nil, default_fallback: UNSET, excluded_carriers: nil, testers: nil, autofill: nil, **opts)
      payload = agent_payload(brand_id, campaign_id, agent, consent, use_case, billing_category, default_fallback,
                              excluded_carriers, testers, contact, autofill)
      agent_request(agent_id, "", :put, payload, opts)
    end

    # POST /rcs/agent/:agentId/validate
    # Check an agent against every submit requirement without writing.
    # Returns { valid, errors: [{ field, reason, code? }], warnings: [{ field, reason }] }; a copy-rule error at the
    # launch gate carries the carrier partner's key as code (for example OPT_IN_MSG_RATE_DISCL_MISSING).
    def validate(agent_id:, **opts)
      agent_request(agent_id, "/validate", :post, nil, opts)
    end

    # POST /rcs/agent/:agentId/submit
    # Submit a draft: create the agent at the carrier partner, with no review first. It needs the full profile, a use
    # case and a billing category; otherwise a 400 whose details carry { code: "REGISTRATION_INCOMPLETE",
    # errors, warnings }. Returns the agent (status AGENT_CREATING, then IN_TESTING once the partner reports it ready).
    # A group that has not finished account verification gets a 403 with code GROUP_UNVERIFIED, and a rejected one a
    # 403 with code GROUP_REJECTED; a pending verification passes.
    def submit(agent_id:, **opts)
      agent_request(agent_id, "/submit", :post, nil, opts)
    end

    # POST /registration/:agentId/launch (the agent is a registration)
    # Request the agent's launch: the launch requirements are checked and the agent goes to Signal House review (status
    # PENDING_REVIEW), whose approval files the launch with the carrier partner. Allowed from IN_TESTING, REJECTED and
    # CARRIER_REJECTED (409 otherwise); a failed requirement is a 400 whose details carry
    # { code: "REGISTRATION_INCOMPLETE", errors, warnings }, and a copy-rule error carries the carrier partner's key as
    # its code (for example OPT_IN_MSG_RATE_DISCL_MISSING). A group that has not finished account verification gets a 403
    # with code GROUP_UNVERIFIED, and a rejected one a 403 with code GROUP_REJECTED. Returns the agent (status PENDING_REVIEW).
    # The request charges the agent's launch fees: a wallet that cannot cover them gets a 402, and the agent stays where it is. When any fee is due the request must set acknowledge_fees: true, or it gets a 400 with code FEE_ACKNOWLEDGEMENT_REQUIRED and nothing is held; a launch with nothing due needs no acknowledgement. The agent's launchFees quotes what the next request charges.
    # When the agent's brand vertical is healthcare or insurance, the launch needs the protected health information (PHI) disclosure acknowledged: send acknowledge_phi: true, or the request gets a 400 REGISTRATION_INCOMPLETE whose errors name consent.phiAcknowledgement. The API records the acknowledgement as consent.phiAcknowledgement { acknowledgedAt, acknowledgedBy } from the caller; the client sends only the boolean, and an agent update cannot set it. Once recorded, a later launch request needs no new acknowledgement.
    def launch(agent_id:, acknowledge_fees: nil, acknowledge_phi: nil, **opts)
      @client.require_params("agentId" => agent_id)
      safe_id = CGI.escape(agent_id.to_s)
      body = { acknowledgeFees: acknowledge_fees, acknowledgePhi: acknowledge_phi }.compact
      @client.request("/registration/#{safe_id}/launch", method: :post, body: body.empty? ? nil : body, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /registration/:agentId/carrier-update (the agent is a registration)
    # Send Signal House the corrected launch answers after a carrier rejected a launch other carriers took. The carrier
    # partner takes no change through its API once a carrier launched, so Signal House emails it the update; edit
    # consent and contact first. The agent's carrierUpdate reads REQUESTED for the rejected carriers, then SENT once
    # Signal House sent it. 409 when no carrier is REJECTED after a partial launch, or an update already waits.
    # Returns the agent's registration, with data.carrierUpdate.
    def request_carrier_update(agent_id:, **opts)
      @client.require_params("agentId" => agent_id)
      safe_id = CGI.escape(agent_id.to_s)
      @client.request("/registration/#{safe_id}/carrier-update", method: :post, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /rcs/agent/:agentId/archive
    # Archive an agent. Returns the agent (status ARCHIVE_PENDING or ARCHIVED). One the carrier partner created stops
    # sending at once and stays ARCHIVE_PENDING until Signal House confirms the partner cancelled it, then ARCHIVED.
    # Archiving cannot be undone; an agent already ARCHIVE_PENDING answers 409.
    def archive(agent_id:, **opts)
      agent_request(agent_id, "/archive", :post, nil, opts)
    end

    # POST /rcs/agent/:agentId/entry-points
    # Make the links that start a chat with the agent: an sms: deep link in Google's format, and a short link that
    # redirects to it, to print as a QR code. With the agent's defaultFallback.from, the deep link names that number, so a
    # handset that cannot reach the agent texts it instead. body (max 1,000 characters) is the message the chat opens
    # with, prefilled on the handset. The same request returns the same short link. The links work for approved testers
    # until a carrier launches the agent; before Google has created the agent the request answers 409 with code
    # GOOGLE_AGENT_PENDING. Returns { googleAgentId, deepLink, shortLink }.
    def create_entry_points(agent_id:, body: nil, **opts)
      agent_request(agent_id, "/entry-points", :post, body.nil? ? nil : { body: body }, opts)
    end

    # POST /rcs/agent/:agentId/testers/:phoneNumber/resend
    # Resend a tester's expired invitation, which starts a new 24 hours for the tester to accept it. phone_number is a US
    # number, with or without the +. The number must be a tester on the agent (404) and its invitation must be EXPIRED
    # (409); up to 20 invitations go out a day (429). Returns the agent.
    def resend_tester_invite(agent_id:, phone_number:, **opts)
      @client.require_params("phoneNumber" => phone_number)
      agent_request(agent_id, "/testers/#{CGI.escape(phone_number.to_s)}/resend", :post, nil, opts)
    end

    # DELETE /rcs/agent/:agentId/testers/:phoneNumber
    # Remove a tester at once, at any point before the agent is archived. phone_number is a US number, with or without
    # the +. The number must be a tester on the agent (404); an archived agent answers 409. Returns the agent.
    def remove_tester(agent_id:, phone_number:, **opts)
      @client.require_params("phoneNumber" => phone_number)
      agent_request(agent_id, "/testers/#{CGI.escape(phone_number.to_s)}", :delete, nil, opts)
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
                      excluded_carriers, testers, contact = nil, autofill = nil)
      payload = { brandId: brand_id, agent: agent, consent: consent, contact: contact, billingCategory: billing_category,
                  excludedCarriers: excluded_carriers, testers: testers, autofill: autofill }.compact
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

  # RCS messages. Sends go through an agent to POST /message/rcs. A message is a Message record (messageType RCS), so the
  # messages methods read the same record. 404 while the environment's RCS switch is off; 403 while the group's rcsEnabled
  # flag is off; 409 while the agent cannot send yet.
  class RcsMessages
    def initialize(client)
      @client = client
    end

    # POST /message/rcs
    # Send to up to 100 recipients, each { phoneNumber, variables, clientMessageId, metadata }. A check that blocks one
    # recipient writes a BLOCKED message for it and the rest still send. Exactly one of template_id or content;
    # template_version needs template_id; at most one of ttl_seconds or expire_time. content_format is content.v1 (default)
    # or google.rcs. traffic_type is AUTHENTICATION, TRANSACTION, SERVICEREQUEST, ACKNOWLEDGEMENT or PROMOTION, required on
    # a MULTI_USE agent when the template sets none. fallback is { mode (auto, rcs_only, sms_only), channel (auto, sms,
    # mms), from, content: { text, mediaUrls }, validitySeconds }; from is a Ready number on the agent's linked Active
    # campaign, and if content is omitted the template's fallback, else a generated one, is used. simulate is not_capable,
    # ttl_expired, delivered or read; is_test and simulate reach approved testers only. Returns 201 with
    # { requested, enqueued, failed, bulkId, messages }. A blocked row carries blockReason, reason and issues; an archived template answers 409 TEMPLATE_ARCHIVED.
    # A recipient from 19999990000 to 19999990359 makes the whole request a simulation, as on SMS: it returns
    # { simulated: true, webhooks } and nothing is stored, sent or charged.
    def send(agent_id:, recipients:, template_id: nil, template_version: nil, content: nil, content_format: nil, traffic_type: nil,
             ttl_seconds: nil, expire_time: nil, fallback: nil, status_callback_url: nil, enable_shortlink: nil, is_test: nil,
             simulate: nil, **opts)
      @client.require_params("agentId" => agent_id, "recipients" => recipients)
      post("/message/rcs", { agentId: agent_id, recipients: recipients, templateId: template_id, templateVersion: template_version,
                             content: content, contentFormat: content_format, trafficType: traffic_type, ttlSeconds: ttl_seconds,
                             expireTime: expire_time, fallback: fallback, statusCallbackUrl: status_callback_url,
                             enableShortlink: enable_shortlink, isTest: is_test, simulate: simulate }, opts)
    end

    # POST /message/rcs/batch
    # Send to up to 10,000 recipients in the background. Takes the same arguments as send. The request runs the send's
    # request checks, splits the recipients into chunks of 100, queues each chunk and answers 202. Every message carries
    # the shared bulkId; track progress with the messages list filtered by bulkId (GET /message?bulkId=) and per-message
    # webhooks. A chunk the wallet cannot cover, or that is refused after acceptance, gets BLOCKED messages with
    # blockReason INSUFFICIENT_FUNDS or SEND_REFUSED; a chunk that keeps failing gets SEND_FAILED. template_version is
    # pinned when the batch is accepted; ttl_seconds counts from when each chunk is sent. Pass idempotency_key: to make a
    # retry safe (same bulkId, no duplicate sends); a retry without one may send duplicates. Returns 202 with
    # { bulkId, status: "ACCEPTED", recipientCount }. A recipient from 19999990000 to 19999990359 makes the whole request
    # a simulation, as on send.
    def send_batch(agent_id:, recipients:, template_id: nil, template_version: nil, content: nil, content_format: nil, traffic_type: nil,
                   ttl_seconds: nil, expire_time: nil, fallback: nil, status_callback_url: nil, enable_shortlink: nil, is_test: nil,
                   simulate: nil, **opts)
      @client.require_params("agentId" => agent_id, "recipients" => recipients)
      post("/message/rcs/batch", { agentId: agent_id, recipients: recipients, templateId: template_id, templateVersion: template_version,
                                   content: content, contentFormat: content_format, trafficType: traffic_type, ttlSeconds: ttl_seconds,
                                   expireTime: expire_time, fallback: fallback, statusCallbackUrl: status_callback_url,
                                   enableShortlink: enable_shortlink, isTest: is_test, simulate: simulate }, opts)
    end

    # POST /message/rcs/validate
    # Run a send's checks without writing anything or holding funds. Takes the same arguments as send. Returns { valid, errors,
    # warnings, billingClass, segments, estimatedCostMicros, unsupportedFiles, recipients }. valid is true only with no errors;
    # each blocked recipient adds an error and carries blockReason, reason and issues.
    def validate(agent_id:, recipients:, template_id: nil, template_version: nil, content: nil, content_format: nil, traffic_type: nil,
                 ttl_seconds: nil, expire_time: nil, fallback: nil, status_callback_url: nil, enable_shortlink: nil, is_test: nil,
                 simulate: nil, **opts)
      @client.require_params("agentId" => agent_id, "recipients" => recipients)
      post("/message/rcs/validate", { agentId: agent_id, recipients: recipients, templateId: template_id, templateVersion: template_version,
                                      content: content, contentFormat: content_format, trafficType: traffic_type, ttlSeconds: ttl_seconds,
                                      expireTime: expire_time, fallback: fallback, statusCallbackUrl: status_callback_url,
                                      enableShortlink: enable_shortlink, isTest: is_test, simulate: simulate }, opts)
    end

    # POST /message/estimate (with channel "rcs")
    # Price an RCS draft in microdollars; no charge or send. Exactly one of recipients or recipient_count; with a count,
    # carriers are unknown and the default fees apply. The other arguments are as on send, but the fallback's from is
    # optional for an estimate; with none, the fallback leg is priced on the channel of the agent's linked campaign.
    # Returns { billingClass, segments, recipientCount, rcsLeg, fallbackLeg, totals, balance, issues, warnings }.
    # rcsLeg.mediaSurcharge is the carrier's surcharge on media over 5 MB for one recipient, and rcsLeg.cost already holds it for every recipient; rcsLeg.cost is null with the fallback mode sms_only; a message over 100 MB adds a MEDIA_TOO_LARGE issue.
    def estimate(agent_id:, recipients: nil, recipient_count: nil, template_id: nil, template_version: nil, content: nil, content_format: nil,
                 traffic_type: nil, ttl_seconds: nil, expire_time: nil, fallback: nil, **opts)
      @client.require_params("agentId" => agent_id)
      post("/message/estimate", { channel: "rcs", agentId: agent_id, recipients: recipients, recipientCount: recipient_count,
                                  templateId: template_id, templateVersion: template_version, content: content,
                                  contentFormat: content_format, trafficType: traffic_type, ttlSeconds: ttl_seconds,
                                  expireTime: expire_time, fallback: fallback }, opts)
    end

    # POST /rcs/capabilities
    # Report which numbers (up to 500, 10-15 digits, with or without the +) can receive RCS from an agent. Returns
    # { results: [{ phoneNumber, capability, rcsEnabled, reason, features, carrier, checkedAt, cached }] }, capability being ENABLED, UNREACHABLE or UNKNOWN, and reason CAPABLE, NOT_CAPABLE, NOT_LAUNCHED_ON_CARRIER or UNKNOWN; rcsEnabled is true only for CAPABLE, carrier and checkedAt may be null, and features is empty today.
    def capabilities(agent_id:, phone_numbers:, **opts)
      @client.require_params("agentId" => agent_id, "phoneNumbers" => phone_numbers)
      post("/rcs/capabilities", { agentId: agent_id, phoneNumbers: phone_numbers }, opts)
    end

    # POST /message/rcs/simulate-inbound
    # Fake an inbound event from an approved tester of the agent, with no carrier involved: it runs the real inbound handlers and webhooks, as free test traffic. A simulated STOP really opts the tester out; a simulated START clears it. Anyone else gets a 403 with code NOT_TESTER. Returns 202 with { status, messageId }.
    # type: TEXT, SUGGESTION, LOCATION, FILE or UNSUBSCRIBE. text is required for TEXT; SUGGESTION needs postback_data or button_id; LOCATION needs latitude
    # and longitude. message_id is the message a tap answers, the latest message delivered to the tester by default.
    def simulate_inbound(agent_id:, from:, type:, text: nil, postback_data: nil, message_id: nil, button_id: nil, latitude: nil, longitude: nil, file_name: nil, **opts)
      @client.require_params("agentId" => agent_id, "from" => from, "type" => type)
      post("/message/rcs/simulate-inbound", { agentId: agent_id, from: from, type: type, text: text, postbackData: postback_data, messageId: message_id,
                                               buttonId: button_id, latitude: latitude, longitude: longitude, fileName: file_name }, opts)
    end

    # GET /message/:messageId
    # One message by its ID; an unknown ID is a 404. The same route as messages.get_message. A settled RCS message carries
    # carrierFeeMicros, the carrier pass-through and media surcharge it was charged.
    def get(message_id:, **opts)
      @client.require_params("messageId" => message_id)
      safe_id = CGI.escape(message_id.to_s)
      @client.request("/message/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /message?messageType=RCS&...
    # List RCS messages. group_id, from and to are required; agent_id is sent as registrationId, from as startDate and to
    # as endDate (ISO-8601 dates or timestamps). status is ENQUEUED, DEQUEUED, SENT, FAILED, DELIVERED, READ, EXPIRED,
    # FALLBACK or BLOCKED; bulk_id selects the messages of one send; fallback_reason is NOT_CAPABLE, CARRIER_NOT_LAUNCHED,
    # TTL_EXPIRED, RCS_ERROR, PROVIDER_ERROR or SMS_ONLY; billing_class is RICH or RICH_MEDIA; delivered_channel is rcs,
    # sms or mms; is_test true returns test messages only and false leaves them out. A fallback leg is an SMS or MMS
    # message: read it with messages.get_message and the parent's fallbackMessageId.
    def list(group_id:, from:, to:, agent_id: nil, status: nil, page: nil, limit: nil, template_id: nil,
             template_version: nil, bulk_id: nil, fallback_reason: nil, billing_class: nil, delivered_channel: nil, is_test: nil,
             **opts)
      @client.require_params("groupId" => group_id, "from" => from, "to" => to)
      qs = @client.get_query_string(
        registrationId: agent_id, startDate: from, endDate: to, groupId: group_id, status: status, page: page, limit: limit,
        templateId: template_id, templateVersion: template_version, bulkId: bulk_id, fallbackReason: fallback_reason,
        billingClass: billing_class, deliveredChannel: delivered_channel, isTest: is_test, messageType: "RCS", dateBounds: "exact"
      )
      @client.request("/message#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    private

    # POST a JSON body, leaving out the nil fields.
    def post(path, fields, opts)
      @client.request(path, method: :post, body: fields.compact, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end

  # RCS (Google RBM) resources, accessed via `client.rcs`. Templates for RCS live under `client.templates`.
  #   * client.rcs.agents — RCS agents linked to a brand and campaign
  #   * client.rcs.messages — RCS sends, estimates, capabilities and message reads
  class Rcs
    attr_reader :agents, :messages

    def initialize(client, multipart_client)
      @agents = RcsAgents.new(client, multipart_client)
      @messages = RcsMessages.new(client)
    end
  end
end
