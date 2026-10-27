# frozen_string_literal: true

module SignalHouseSms
  class Campaigns
    attr_reader :admin

    def initialize(client, multipart_client, enable_admin)
      @client = client
      @multipart_client = multipart_client
      @admin = Admin.new(client) if enable_admin
    end

    # GET /campaign?...
    # registration_type optionally filters by "TEN_DLC", "TOLL_FREE", or "SHORT_CODE".
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
    def get_campaigns(id: nil, brand_id: nil, subgroup_id: nil, group_id: nil, page: nil, limit: nil, status: nil, registration_type: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(id: id, brandId: brand_id, subgroupId: subgroup_id, groupId: group_id, page: page, limit: limit, status: status, registrationType: registration_type)
      @client.request("/campaign#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /campaign/health?campaignId=...&includeNumbers=...
    def get_campaign_health(campaign_id:, include_numbers: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(campaignId: campaign_id, includeNumbers: include_numbers)
      @client.request("/campaign/health#{qs}", method: :get, token: token, headers: headers)
    end

    # The carrier throughput ceilings a campaign is currently sending under: the AT&T per-minute limit (per
    # campaign, held 10% under the published ceiling) and the T-Mobile daily cap (per brand), each with its
    # current tier and the next rung on the ladder, plus today's T-Mobile usage. Resolved from the same brand
    # status / brand score rules the send path enforces with.
    #
    # Returns campaignId, brandId, usecase, brand {status, brandScore, entityType}, att {tier, scope, unit,
    # sms {limit}, mms {limit}, marginPercent, nextTier}, tmobile {tier, scope, unit, dailyLimit, thresholds,
    # nextTier, usedToday {date, segments, resetsAt} | nil}. A nil tier/limit means the carrier ladder does not
    # apply (unverified brand, GOVERNMENT entity, PUBLIC_SAFETY_RESTRICTED usecase); a nil nextTier means the
    # top rung or a usecase-capped (LOW_VOLUME) campaign.
    #
    # GET /campaign/throughput-limits?campaignId=...
    def get_campaign_throughput_limits(campaign_id:, **opts)
      @client.require_params("campaignId" => campaign_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(campaignId: campaign_id)
      @client.request("/campaign/throughput-limits#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /campaign
    # Optional campaign_data[:sampleMediaIds] (10DLC only): up to 5 mediaId strings from
    # upload_sample_media, attached to the TCR campaign as sample MMS media for carrier review.
    def create_campaign(campaign_data:, **opts)
      @client.require_params("campaignData" => campaign_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/campaign", method: :post, body: campaign_data, token: token, headers: headers)
    end

    # POST /campaign/toll-free — create a Toll-Free (TFN) campaign and submit it for Signal House review.
    #
    # registrationType is forced to TOLL_FREE server-side; TFN-specific fields live under
    # campaign_data[:tollFree] (useCase, messageVolume, programSummary, exampleMessage,
    # customerCareEmail, optInImageURLs, optional optIns / multiNumberReason / useCases / channels / landingId). phoneNumbers must
    # list 1 up to the brand's tollFree.maxNumbersPerCampaign Toll-Free numbers (at most 5), on the brand's toll-free
    # carrier, or the campaign is refused. They are locked to the campaign once assigned.
    def create_toll_free_campaign(campaign_data:, **opts)
      @client.require_params("campaignData" => campaign_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/campaign/toll-free", method: :post, body: campaign_data, token: token, headers: headers)
    end

    # POST /campaign/short-code (multipart) — create a Short Code campaign and submit it for
    # Signal House review. Requires an approved (VERIFIED) Short Code brand.
    #
    # Upload the opt-in proof screenshot first with upload_opt_in_image and pass the returned URL as
    # campaign_data[:shortCode][:screenshotUrl] (required; external URLs are rejected).
    # campaign_data[:shortCode][:optInUrl] (required) is the public HTTPS link to the live opt-in experience. Request or
    # register the campaign's Short Code separately through numbers.request_short_code_acquisition after creation.
    def create_short_code_campaign(campaign_data:, **opts)
      @client.require_params("campaignData" => campaign_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      form_data = { "campaignData" => campaign_data.to_json }
      @multipart_client.request("/campaign/short-code", method: :post, body: form_data, token: token, headers: headers)
    end

    # PUT /campaign/short-code/:campaignId — update a Short Code campaign's editable fields.
    # Only permitted while the campaign is in Signal House Review or Signal House
    # Rejected status; the number source cannot be changed once submitted.
    def update_short_code_campaign(campaign_id:, update_data:, **opts)
      @client.require_params("campaignId" => campaign_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_campaign_id = CGI.escape(campaign_id.to_s)
      @client.request("/campaign/short-code/#{safe_campaign_id}", method: :put, body: update_data, token: token, headers: headers)
    end

    # Issued customer leases return PENDING_DELETE until Signal House confirms Registry offboarding;
    # safe-to-dispose and staff cancellations return EXPIRED immediately.
    def cancel_short_code_campaign(campaign_id:, **opts)
      @client.require_params("campaignId" => campaign_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_campaign_id = CGI.escape(campaign_id.to_s)
      @client.request("/campaign/short-code/#{safe_campaign_id}/cancel", method: :post, token: token, headers: headers)
    end

    # GET /campaign/short-code/artifact/:artifactId — download a private Short Code external lease
    # receipt. Opt-in screenshots are public at the shortCode.screenshotUrl returned on the campaign.
    def read_campaign_artifact(artifact_id:, **opts)
      @client.require_params("artifactId" => artifact_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_artifact_id = CGI.escape(artifact_id.to_s)
      @client.request("/campaign/short-code/artifact/#{safe_artifact_id}", method: :get, token: token, headers: headers)
    end

    # POST /campaign/opt-in-image (multipart) — upload an opt-in proof image, returning the hosted
    # image's id and url suitable for a Toll-Free campaign's optInImageURLs.
    #
    # file may be a file hash ({ filename:, io:, content_type: }) or any value the multipart client
    # accepts for the "file" field.
    def upload_opt_in_image(file:, **opts)
      @client.require_params("file" => file)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      form_data = { "file" => file }
      @multipart_client.request("/campaign/opt-in-image", method: :post, body: form_data, token: token, headers: headers)
    end

    # POST /campaign/sample-media (multipart) — upload a sample media file (JPEG, PNG, GIF, MP4 or MP3,
    # up to 5MB) for a 10DLC campaign. Reference the returned mediaId in sampleMediaIds on campaign
    # create or update; it is attached to the TCR campaign for carrier review.
    # Returns { mediaId, fileName, mimeType, size }.
    #
    # file may be a file hash ({ filename:, io:, content_type: }) or any value the multipart client
    # accepts for the "file" field. group_id is the group the file belongs to: required with a staff
    # (signalhouse_*) key, which has no active group; otherwise optional and must be your own group.
    def upload_sample_media(file:, group_id: nil, **opts)
      @client.require_params("file" => file)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      form_data = {}
      form_data["groupId"] = group_id.to_s unless group_id.nil? || group_id.to_s.empty?
      form_data["file"] = file
      @multipart_client.request("/campaign/sample-media", method: :post, body: form_data, token: token, headers: headers)
    end

    # GET /campaign/sample-media/:mediaId — download a campaign sample media file your group owns.
    def read_sample_media(media_id:, **opts)
      @client.require_params("mediaId" => media_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_media_id = CGI.escape(media_id.to_s)
      @client.request("/campaign/sample-media/#{safe_media_id}", method: :get, token: token, headers: headers)
    end

    # POST /campaign/opt-in-image/from-landing — auto-capture an opt-in proof image from a brand's
    # generated landing page, returning the hosted image's id and url.
    # landing_id: the specific page to capture. Required for Toll-Free brands, which have one page per
    # campaign -- omitted, the request is refused rather than guessing. A 10DLC brand has a single page.
    def capture_opt_in_image_from_landing(brand_id:, landing_id: nil, **opts)
      @client.require_params("brandId" => brand_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = { brandId: brand_id }
      body[:landingId] = landing_id if landing_id
      @client.request("/campaign/opt-in-image/from-landing", method: :post, body: body, token: token, headers: headers)
    end

    # PUT /campaign/:campaignId
    # For a Toll-Free campaign, pass the editable Toll-Free fields under a :tollFree sub-hash in
    # campaign_data (useCase, messageVolume, programSummary, exampleMessage, customerCareEmail,
    # optInImageURLs, optIns, multiNumberReason, useCases, channels, landingId); phoneNumbers cannot be changed — Toll-Free numbers
    # are locked to their campaign. For a 10DLC campaign, an optional :sampleMediaIds list (up to 5
    # mediaId strings from upload_sample_media) sets the sample MMS media for carrier review.
    def update_campaign(campaign_id:, campaign_data:, **opts)
      @client.require_params("campaignId" => campaign_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_campaign_id = CGI.escape(campaign_id.to_s)
      @client.request("/campaign/#{safe_campaign_id}", method: :put, body: campaign_data, token: token, headers: headers)
    end

    # DELETE /campaign/:campaignId
    def delete_campaign(campaign_id:, **opts)
      @client.require_params("campaignId" => campaign_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_campaign_id = CGI.escape(campaign_id.to_s)
      @client.request("/campaign/#{safe_campaign_id}", method: :delete, token: token, headers: headers)
    end

    # POST /campaign/appealDcaRejection/:campaignId
    def appeal_dca_rejection(campaign_id:, **opts)
      @client.require_params("campaignId" => campaign_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = opts[:body]
      safe_campaign_id = CGI.escape(campaign_id.to_s)
      @client.request("/campaign/appealDcaRejection/#{safe_campaign_id}", method: :post, token: token, headers: headers, body: body)
    end

    # POST /campaign/nudge/:campaignId
    def nudge_dca_for_campaign(campaign_id:, **opts)
      @client.require_params("campaignId" => campaign_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_campaign_id = CGI.escape(campaign_id.to_s)
      @client.request("/campaign/nudge/#{safe_campaign_id}", method: :post, token: token, headers: headers)
    end

    class Admin
      def initialize(client)
        @client = client
      end

      # POST /campaign/approve/:campaignId
      def approve_campaign(campaign_id:, **opts)
        @client.require_params("campaignId" => campaign_id)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_campaign_id = CGI.escape(campaign_id.to_s)
        @client.request("/campaign/approve/#{safe_campaign_id}", method: :post, token: token, headers: headers)
      end

      # POST /campaign/reject/:campaignId
      # Optional body: { rejectionReason: "..." } (10-256 characters)
      def reject_campaign(campaign_id:, **opts)
        @client.require_params("campaignId" => campaign_id)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        body = opts[:body]
        safe_campaign_id = CGI.escape(campaign_id.to_s)
        @client.request("/campaign/reject/#{safe_campaign_id}", method: :post, token: token, headers: headers, body: body)
      end

      # PUT /campaign/short-code/:campaignId/status — transition a Short Code campaign's review
      # status. A customer-visible reason is required for both rejection states.
      # Selecting PENDING_DCA_APPROVAL runs the guarded carrier-review transition; fulfillment remains separate.
      def update_short_code_campaign_status(campaign_id:, status:, rejection_reason: nil, **opts)
        @client.require_params("campaignId" => campaign_id, "status" => status)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_campaign_id = CGI.escape(campaign_id.to_s)
        body = { status: status, rejectionReason: rejection_reason }
        @client.request("/campaign/short-code/#{safe_campaign_id}/status", method: :put, body: body, token: token, headers: headers)
      end

      # POST /campaign/short-code/:campaignId/fulfill — record the issued campaign-bound Short Code.
      # A YYYY-MM-DD lease end date expires at 23:59:59 UTC.
      def fulfill_short_code_campaign(campaign_id:, actual_code:, lease_end_date:, internal_notes: nil, **opts)
        @client.require_params("campaignId" => campaign_id, "actualCode" => actual_code, "leaseEndDate" => lease_end_date)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_campaign_id = CGI.escape(campaign_id.to_s)
        @client.request("/campaign/short-code/#{safe_campaign_id}/fulfill", method: :post, body: { actualCode: actual_code, leaseEndDate: lease_end_date, internalNotes: internal_notes }, token: token, headers: headers)
      end

      # POST /campaign/short-code/:campaignId/submit-to-carrier — submit prepared campaign to carrier review.
      def submit_short_code_campaign_to_carrier(campaign_id:, **opts)
        @client.require_params("campaignId" => campaign_id)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        safe_campaign_id = CGI.escape(campaign_id.to_s)
        @client.request("/campaign/short-code/#{safe_campaign_id}/submit-to-carrier", method: :post, token: token, headers: headers)
      end

      # Confirm Registry offboarding and complete a pending Short Code cancellation.
      def complete_short_code_cancellation(campaign_id:, request_id:, note: nil, **opts)
        @client.require_params("campaignId" => campaign_id, "requestId" => request_id)
        safe_campaign_id = CGI.escape(campaign_id.to_s)
        @client.request("/campaign/short-code/#{safe_campaign_id}/cancellation/complete", method: :post, body: { requestId: request_id, note: note }, token: opts[:token], headers: HttpClient.headers_for(opts))
      end

      # Dismiss a pending Short Code cancellation and restore its prior lifecycle state.
      def dismiss_short_code_cancellation(campaign_id:, request_id:, note: nil, **opts)
        @client.require_params("campaignId" => campaign_id, "requestId" => request_id)
        safe_campaign_id = CGI.escape(campaign_id.to_s)
        @client.request("/campaign/short-code/#{safe_campaign_id}/cancellation/dismiss", method: :post, body: { requestId: request_id, note: note }, token: opts[:token], headers: HttpClient.headers_for(opts))
      end

      # GET expired Short Code leases awaiting manual Registry offboarding.
      def get_expired_short_code_leases(page: nil, limit: nil, **opts)
        qs = @client.get_query_string(page: page, limit: limit)
        @client.request("/campaign/short-code/expired-leases#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
      end

      # Confirm Registry offboarding and mark an expired Short Code released.
      def release_expired_short_code_lease(campaign_id:, note: nil, **opts)
        @client.require_params("campaignId" => campaign_id)
        safe_campaign_id = CGI.escape(campaign_id.to_s)
        @client.request("/campaign/short-code/#{safe_campaign_id}/expired-lease/release", method: :post, body: { note: note }, token: opts[:token], headers: HttpClient.headers_for(opts))
      end
    end
  end
end
