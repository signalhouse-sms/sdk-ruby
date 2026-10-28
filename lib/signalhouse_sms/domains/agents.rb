# frozen_string_literal: true

module SignalHouseSms
  # AI Agents domain — customer-facing agent config under /agent.
  class Agents
    def initialize(client, _enable_admin)
      @client = client
    end

    # GET /agent/voices
    # List the voices an agent can be configured to speak with. The catalog is platform-wide, not per-account, so this takes no scope. voiceId is the value to set on a spoken channel's setting.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_voices(**opts)
      @client.request("/agent/voices", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /agent/profiles?groupId=...&page=...&limit=...
    # List the agent profiles under a group. groupId is required.
    # subgroup_id: Narrow to the agents this subgroup can use — its own, plus the group-level agents shared with every subgroup.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_profiles(group_id:, subgroup_id: nil, page: nil, limit: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, page: page, limit: limit)
      @client.request("/agent/profiles#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /agent/profiles/:agentProfileId
    # Get a single agent profile by id.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_profile(agent_profile_id:, **opts)
      @client.require_params("agentProfileId" => agent_profile_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      @client.request("/agent/profiles/#{safe_id}", method: :get, token: token, headers: headers)
    end

    # POST /agent/profiles
    # Create a new agent profile. profile_data is the JSON body and must include the
    # required fields groupId (starts with 'G') and name. Optional fields: subgroupId
    # (starts with 'S', nullable), status ("active"|"inactive"), systemPrompt, greeting,
    # guardrails, sendAuthority ("review"|"autopilot", defaults to "review"; deployments
    # may override it per subgroup). publishStatus and publishedAt are read-only and change
    # only through publish_agent_profile and unpublish_agent_profile. Model, voice and
    # sampling settings are per-channel and live on the channel setting, not here.
    # Allowed roles: api, admin, developer.
    def create_agent_profile(profile_data:, **opts)
      @client.require_params("profileData" => profile_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/agent/profiles", method: :post, body: profile_data, token: token, headers: headers)
    end

    # PUT /agent/profiles/:id
    # Update an existing agent profile. update_data is the JSON body; all fields are
    # optional. groupId and subgroupId are NOT updatable (agent scope is immutable).
    # sendAuthority ("review"|"autopilot") is updatable; publishStatus and publishedAt are
    # read-only and change only through publish_agent_profile and unpublish_agent_profile.
    # Allowed roles: api, admin, developer.
    def update_agent_profile(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/agent/profiles/#{safe_id}", method: :put, body: update_data, token: token, headers: headers)
    end

    # DELETE /agent/profiles/:id
    # Permanently delete an agent profile by its id.
    # Permanently deletes the agent, its channel settings, and any tools and knowledge scoped to it, plus their provider-side counterparts. Tools and knowledge shared across the account are untouched. Conversation records survive — a transcript outlives the agent that produced it.
    # Allowed roles: api, admin, developer.
    def delete_agent_profile(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/agent/profiles/#{safe_id}", method: :delete, token: token, headers: headers)
    end

    # POST /agent/messages
    # Send a message to an agent and get its reply — the app-native conversation
    # endpoint (webchat / SMS). Omit conversation_id to start a new conversation, or
    # pass one to continue an existing one. The agent's LLM tool loop runs server-side
    # and the response carries conversationId, conversationSessionId, reply,
    # toolInvocations, and ok. agent_profile_id, channel, and message are required.
    # Allowed roles: api, admin, developer, billing, user.
    def send_agent_message(agent_profile_id:, channel:, message:, conversation_id: nil, contact_identifier: nil, **opts)
      @client.require_params("agentProfileId" => agent_profile_id, "channel" => channel, "message" => message)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = { "agentProfileId" => agent_profile_id, "channel" => channel, "message" => message }
      body["conversationId"] = conversation_id unless conversation_id.nil?
      body["contactIdentifier"] = contact_identifier unless contact_identifier.nil?
      @client.request("/agent/messages", method: :post, body: body, token: token, headers: headers)
    end

    # POST /agent/conversations
    # Start a conversation without sending a message. The counterpart to
    # send_agent_message for callers that run the model themselves — a voice runtime, or
    # your own LLM. Those record what was said; send_agent_message decides it. Both write
    # the same conversation records.
    # Allowed roles: api, admin, developer, billing, user.
    def start_conversation(agent_profile_id:, channel:, contact_identifier: nil, call_id: nil, metadata: nil, **opts)
      @client.require_params("agentProfileId" => agent_profile_id, "channel" => channel)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = { "agentProfileId" => agent_profile_id, "channel" => channel }
      body["contactIdentifier"] = contact_identifier unless contact_identifier.nil?
      body["callId"] = call_id unless call_id.nil?
      body["metadata"] = metadata unless metadata.nil?
      @client.request("/agent/conversations", method: :post, body: body, token: token, headers: headers)
    end

    # GET /agent/conversations/:conversationId
    # Read one conversation with a page of its messages, in order. Paged rather than whole:
    # a transcript has no natural ceiling. Omitting limit gives 100 messages, not all of them.
    # page defaults to 1; limit defaults to 100 and is capped at 500.
    # Allowed roles: api, admin, developer, billing, user.
    def get_conversation(conversation_id:, page: nil, limit: nil, **opts)
      @client.require_params("conversationId" => conversation_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(conversation_id.to_s)
      qs = @client.get_query_string(page: page, limit: limit)
      @client.request("/agent/conversations/#{safe_id}#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /agent/conversations/:conversationId/messages
    # Append one message to a conversation. Records a turn rather than generating one, so
    # role is explicit — an assistant turn your own runtime produced is the normal case
    # here. content is optional so a tool-only turn needs no prose.
    # Allowed roles: api, admin, developer, billing, user.
    def append_conversation_message(conversation_id:, role:, content: nil, tool_calls: nil, tool_results: nil,
                                    ttfb_ms: nil, latency_ms: nil, barge_in_occurred: nil, **opts)
      @client.require_params("conversationId" => conversation_id, "role" => role)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(conversation_id.to_s)
      body = { "role" => role }
      body["content"] = content unless content.nil?
      body["toolCalls"] = tool_calls unless tool_calls.nil?
      body["toolResults"] = tool_results unless tool_results.nil?
      body["ttfbMs"] = ttfb_ms unless ttfb_ms.nil?
      body["latencyMs"] = latency_ms unless latency_ms.nil?
      body["bargeInOccurred"] = barge_in_occurred unless barge_in_occurred.nil?
      @client.request("/agent/conversations/#{safe_id}/messages", method: :post, body: body, token: token, headers: headers)
    end

    # PUT /agent/conversations/:conversationId
    # End a conversation, closing its open session. status records HOW it ended and cannot
    # be recovered afterwards, so pass the one that actually happened. Ending an
    # already-ended conversation is a no-op, so a retry after a dropped connection cannot
    # overwrite it.
    # Allowed roles: api, admin, developer, billing, user.
    def end_conversation(conversation_id:, status: nil, metadata: nil, **opts)
      @client.require_params("conversationId" => conversation_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(conversation_id.to_s)
      body = {}
      body["status"] = status unless status.nil?
      body["metadata"] = metadata unless metadata.nil?
      @client.request("/agent/conversations/#{safe_id}", method: :put, body: body, token: token, headers: headers)
    end

    # GET /agent/profiles/:agentProfileId/channels
    # List an agent's per-channel settings.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_channel_settings(agent_profile_id:, **opts)
      @client.require_params("agentProfileId" => agent_profile_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      @client.request("/agent/profiles/#{safe_id}/channels", method: :get, token: token, headers: headers)
    end

    # GET /agent/profiles/:agentProfileId/channels/:channel
    # Get a single per-channel setting for an agent.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_channel_setting(agent_profile_id:, channel:, **opts)
      @client.require_params("agentProfileId" => agent_profile_id, "channel" => channel)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      safe_channel = CGI.escape(channel.to_s)
      @client.request("/agent/profiles/#{safe_id}/channels/#{safe_channel}", method: :get, token: token, headers: headers)
    end

    # PUT /agent/profiles/:agentProfileId/channels/:channel
    # Create or update (upsert) an agent's per-channel setting. One row per (agent, channel);
    # the channel is taken from the path. setting_data accepts allowedTools (Array<String>),
    # enabled (Boolean), channelPrompt (String), greeting (String|nil), llmProvider
    # ("bedrock"|"openai"|"anthropic"|"groq"), llmModel (String|nil), temperature (0-2),
    # voiceId (String|nil). Model settings are per-channel because each channel is
    # served by a different runtime. Spoken channels also accept: speed (0.7-1.2),
    # stability (0-1), similarityBoost (0-1), speechModel (String — how the agent is
    # voiced, chosen independently of llmModel), turnEagerness
    # ("patient"|"normal"|"eager"), turnTimeoutSeconds and initialWaitSeconds (1-300,
    # or -1 for no timeout), silenceEndCallSeconds (10-7200), maxCallDurationSeconds
    # (60-7200), allowGreetingInterruption (Boolean), keyterms (Array<String> the
    # transcriber is biased toward), backgroundSound ({preset:, volume:}|nil), workflow
    # (the conversation workflow graph: "nodes" and "edges" keyed hashes, plus optional
    # "subgraphs" and "prevent_subagent_loops"; node bodies are defined by the voice runtime
    # and passed through as-is). workflow is accepted on the voice channel only — sending one
    # on webchat or sms is a 400; nil clears it.
    # Allowed roles: api, admin, developer.
    def upsert_agent_channel_setting(agent_profile_id:, channel:, setting_data: {}, **opts)
      @client.require_params("agentProfileId" => agent_profile_id, "channel" => channel)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      safe_channel = CGI.escape(channel.to_s)
      @client.request("/agent/profiles/#{safe_id}/channels/#{safe_channel}", method: :put, body: setting_data, token: token, headers: headers)
    end

    # DELETE /agent/profiles/:agentProfileId/channels/:channel
    # Delete an agent's per-channel setting.
    # Allowed roles: api, admin, developer.
    def delete_agent_channel_setting(agent_profile_id:, channel:, **opts)
      @client.require_params("agentProfileId" => agent_profile_id, "channel" => channel)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      safe_channel = CGI.escape(channel.to_s)
      @client.request("/agent/profiles/#{safe_id}/channels/#{safe_channel}", method: :delete, token: token, headers: headers)
    end

    # GET /agent/profiles/:agentProfileId/deployments
    # List a group-level agent's deployments to subgroups. Each deployment carries
    # agentDeploymentId, groupId, subgroupId, agentProfileId, sendAuthorityOverride,
    # sendAuthorityChangedBy, sendAuthorityChangedAt, enabled, createdAt, updatedAt.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_deployments(agent_profile_id:, **opts)
      @client.require_params("agentProfileId" => agent_profile_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      @client.request("/agent/profiles/#{safe_id}/deployments", method: :get, token: token, headers: headers)
    end

    # PUT /agent/profiles/:agentProfileId/deployments/:subgroupId
    # Deploy a group-level agent to a subgroup, or change that deployment (upsert). One row
    # per (agent, subgroup); the subgroup is taken from the path. deployment_data accepts
    # sendAuthorityOverride ("review"|"autopilot"|nil; nil clears the override so the
    # deployment inherits the profile default) and enabled (Boolean, defaults to true).
    # Allowed roles: api, admin, developer.
    def upsert_agent_deployment(agent_profile_id:, subgroup_id:, deployment_data: {}, **opts)
      @client.require_params("agentProfileId" => agent_profile_id, "subgroupId" => subgroup_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      safe_subgroup_id = CGI.escape(subgroup_id.to_s)
      @client.request("/agent/profiles/#{safe_id}/deployments/#{safe_subgroup_id}", method: :put, body: deployment_data, token: token, headers: headers)
    end

    # DELETE /agent/profiles/:agentProfileId/deployments/:subgroupId
    # Remove an agent's deployment from a subgroup. Returns the removed deployment.
    # Allowed roles: api, admin, developer.
    def delete_agent_deployment(agent_profile_id:, subgroup_id:, **opts)
      @client.require_params("agentProfileId" => agent_profile_id, "subgroupId" => subgroup_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      safe_subgroup_id = CGI.escape(subgroup_id.to_s)
      @client.request("/agent/profiles/#{safe_id}/deployments/#{safe_subgroup_id}", method: :delete, token: token, headers: headers)
    end

    # GET /agent/endpoints?groupId=...&subgroupId=...&agentProfileId=...&channel=...
    # List the endpoint bindings (which agent answers which number) in a group, ordered by
    # number. groupId is required; subgroup_id, agent_profile_id and channel ("sms") narrow
    # the list. Each binding carries agentEndpointId, groupId, subgroupId, channel,
    # endpointType, endpointValue, agentProfileId, answerMode, overrides, enabled,
    # createdAt, and updatedAt.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_endpoints(group_id:, subgroup_id: nil, agent_profile_id: nil, channel: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = opts[:headers]
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, agentProfileId: agent_profile_id, channel: channel)
      @client.request("/agent/endpoints#{qs}", method: :get, token: token, headers: headers)
    end

    # PUT /agent/endpoints/:channel/:endpointValue
    # Assign an agent to answer a number (upsert keyed by channel + number). Assigning again
    # replaces the previous agent, so a number has one agent per channel. Only SMS numbers can be bound:
    # channel must be "sms", and endpoint_value is the phone number as 10 to 15 digits,
    # country code included, no "+". endpoint_data accepts agentProfileId (required; the agent
    # must be active, in the number's group, and either belong to the number's subgroup or be a
    # group-level agent with an enabled deployment there) and answerMode ("all_inbound", the
    # default). Returns the created or updated binding.
    # Allowed roles: api, admin, developer.
    def upsert_agent_endpoint(channel:, endpoint_value:, endpoint_data:, **opts)
      agent_profile_id = endpoint_data[:agentProfileId] || endpoint_data["agentProfileId"]
      @client.require_params("channel" => channel, "endpointValue" => endpoint_value, "agentProfileId" => agent_profile_id)
      token = opts[:token]
      headers = opts[:headers]
      safe_channel = CGI.escape(channel.to_s)
      safe_endpoint_value = CGI.escape(endpoint_value.to_s)
      @client.request("/agent/endpoints/#{safe_channel}/#{safe_endpoint_value}", method: :put, body: endpoint_data, token: token, headers: headers)
    end

    # DELETE /agent/endpoints/:channel/:endpointValue
    # Remove the agent assigned to a number. Returns the removed binding.
    # Allowed roles: api, admin, developer.
    def delete_agent_endpoint(channel:, endpoint_value:, **opts)
      @client.require_params("channel" => channel, "endpointValue" => endpoint_value)
      token = opts[:token]
      headers = opts[:headers]
      safe_channel = CGI.escape(channel.to_s)
      safe_endpoint_value = CGI.escape(endpoint_value.to_s)
      @client.request("/agent/endpoints/#{safe_channel}/#{safe_endpoint_value}", method: :delete, token: token, headers: headers)
    end

    # GET /agent/pauses?groupId=...&subgroupId=...&channel=...&endpointValue=...&contactIdentifier=...
    # List paused agent conversations in a group, newest first. A paused conversation is one a
    # person took over; the agent stays out of it until it is resumed. groupId is required;
    # subgroup_id, channel ("sms"), endpoint_value (the agent's number) and contact_identifier
    # (the contact's number), digits only with no "+", narrow the list. Each pause carries
    # groupId, subgroupId, channel, endpointValue, contactIdentifier, reason ("human_reply", "escalation" or
    # "manual"), pausedBy, createdAt, and updatedAt.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_contact_pauses(group_id:, subgroup_id: nil, channel: nil, endpoint_value: nil, contact_identifier: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, channel: channel, endpointValue: endpoint_value, contactIdentifier: contact_identifier)
      @client.request("/agent/pauses#{qs}", method: :get, token: token, headers: headers)
    end

    # PUT /agent/pauses/:channel/:endpointValue/:contactIdentifier
    # Pause an agent on one conversation (its number + one contact). The agent stops answering
    # that contact on that number until the conversation is resumed; there is no timer. The
    # conversation's pending replies are rejected. Pausing a paused conversation keeps the
    # original pause. channel must be "sms"; endpoint_value and contact_identifier are 10 to 15
    # digits, country code included, no "+". pause_data accepts reason ("human_reply" or
    # "manual", the default). Returns the pause.
    # Allowed roles: api, admin, developer, billing, user.
    def pause_agent_conversation(channel:, endpoint_value:, contact_identifier:, pause_data: {}, **opts)
      @client.require_params("channel" => channel, "endpointValue" => endpoint_value, "contactIdentifier" => contact_identifier)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_channel = CGI.escape(channel.to_s)
      safe_endpoint_value = CGI.escape(endpoint_value.to_s)
      safe_contact_identifier = CGI.escape(contact_identifier.to_s)
      @client.request("/agent/pauses/#{safe_channel}/#{safe_endpoint_value}/#{safe_contact_identifier}", method: :put, body: pause_data || {}, token: token, headers: headers)
    end

    # DELETE /agent/pauses/:channel/:endpointValue/:contactIdentifier
    # Resume an agent on a paused conversation, so it answers the contact's next text again.
    # Returns the removed pause.
    # Allowed roles: api, admin, developer, billing, user.
    def resume_agent_conversation(channel:, endpoint_value:, contact_identifier:, **opts)
      @client.require_params("channel" => channel, "endpointValue" => endpoint_value, "contactIdentifier" => contact_identifier)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_channel = CGI.escape(channel.to_s)
      safe_endpoint_value = CGI.escape(endpoint_value.to_s)
      safe_contact_identifier = CGI.escape(contact_identifier.to_s)
      @client.request("/agent/pauses/#{safe_channel}/#{safe_endpoint_value}/#{safe_contact_identifier}", method: :delete, token: token, headers: headers)
    end

    # GET /agent/drafts?groupId=...&subgroupId=...&agentProfileId=...&status=...&page=...&limit=...
    # List held agent replies (the Pending Replies queue) in a group, newest first. groupId is
    # required; subgroup_id, agent_profile_id and status ("pending", "sending", "sent",
    # "rejected" or "failed") narrow the list; limit defaults to 25, max 500. Each draft carries
    # agentReplyDraftId, groupId, subgroupId, agentProfileId, conversationId, channel,
    # endpointValue, contactPhoneNumber, inboundText, draftText, sentText, reason, status,
    # decidedBy, decidedAt, sentMessageId, deliveredBy ("signalhouse" or "external"; nil until
    # decided), failureReason ("delivery_unconfirmed" or nil), claimId (the current claim's id;
    # nil until claimed), createdAt, and updatedAt.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_reply_drafts(group_id:, subgroup_id: nil, agent_profile_id: nil, status: nil, page: nil, limit: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = opts[:headers]
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, agentProfileId: agent_profile_id, status: status, page: page, limit: limit)
      @client.request("/agent/drafts#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /agent/drafts/:agentReplyDraftId/approve
    # Approve a held agent reply and send it from the agent's number. text (optional, 1 to
    # 10000 characters) replaces the agent's draft when a person edited it. It goes through the
    # normal SMS send path, so opt-out and billing apply; the draft comes back "failed" when the
    # send path accepted nothing. A draft that is no longer pending returns 409.
    # Allowed roles: api, admin, developer, billing, user.
    def approve_agent_reply_draft(agent_reply_draft_id:, text: nil, **opts)
      @client.require_params("agentReplyDraftId" => agent_reply_draft_id)
      token = opts[:token]
      headers = opts[:headers]
      safe_id = CGI.escape(agent_reply_draft_id.to_s)
      body = text.nil? ? {} : { text: text }
      @client.request("/agent/drafts/#{safe_id}/approve", method: :post, body: body, token: token, headers: headers)
    end

    # POST /agent/drafts/:agentReplyDraftId/reject
    # Reject a held agent reply so it is never sent. Returns the rejected draft. A draft that
    # is no longer pending returns 409.
    # Allowed roles: api, admin, developer, billing, user.
    def reject_agent_reply_draft(agent_reply_draft_id:, **opts)
      @client.require_params("agentReplyDraftId" => agent_reply_draft_id)
      token = opts[:token]
      headers = opts[:headers]
      safe_id = CGI.escape(agent_reply_draft_id.to_s)
      @client.request("/agent/drafts/#{safe_id}/reject", method: :post, token: token, headers: headers)
    end

    # POST /agent/drafts/:agentReplyDraftId/claim
    # Claim a held agent reply for delivery through your own channel instead of Signal House's
    # send path. text (optional, 1 to 10000 characters) replaces the agent's draft when a person
    # edited it. Nothing is sent: the draft becomes "sending" with deliveredBy "external",
    # sentText and a new claimId set, and you then report the outcome with
    # complete_agent_reply_draft or release_agent_reply_draft, passing that claimId back as
    # claim_id. The claim means two approvals can never both deliver. A draft
    # that is no longer pending returns 409; one whose number has left its subgroup returns 400
    # and is closed as failed.
    # Allowed roles: api, admin, developer, billing, user.
    def claim_agent_reply_draft(agent_reply_draft_id:, text: nil, **opts)
      @client.require_params("agentReplyDraftId" => agent_reply_draft_id)
      token = opts[:token]
      headers = opts[:headers]
      safe_id = CGI.escape(agent_reply_draft_id.to_s)
      body = text.nil? ? {} : { text: text }
      @client.request("/agent/drafts/#{safe_id}/claim", method: :post, body: body, token: token, headers: headers)
    end

    # POST /agent/drafts/:agentReplyDraftId/complete
    # Mark a claimed agent reply sent once your channel accepted it. claim_id (required) is the
    # claim being completed, as returned by claim_agent_reply_draft. external_message_id
    # (optional, up to 256 characters) is your channel's id for the sent message, stored as
    # sentMessageId. Only the claim named by claim_id can be completed; anything else returns
    # 409. It is also accepted after an unfinished claim was closed as "failed" with
    # failureReason "delivery_unconfirmed", which it turns into "sent".
    # Allowed roles: api, admin, developer, billing, user.
    def complete_agent_reply_draft(agent_reply_draft_id:, claim_id:, external_message_id: nil, **opts)
      @client.require_params("agentReplyDraftId" => agent_reply_draft_id, "claimId" => claim_id)
      token = opts[:token]
      headers = opts[:headers]
      safe_id = CGI.escape(agent_reply_draft_id.to_s)
      body = { claimId: claim_id }
      body[:externalMessageId] = external_message_id unless external_message_id.nil?
      @client.request("/agent/drafts/#{safe_id}/complete", method: :post, body: body, token: token, headers: headers)
    end

    # POST /agent/drafts/:agentReplyDraftId/release
    # Give back a claim whose reply certainly did not go out: the draft returns to "pending", or
    # with permanent: true is closed as "failed". If you cannot tell whether it went out, do not
    # release it; a claim left unfinished for 30 minutes is closed as failed with failureReason
    # "delivery_unconfirmed". claim_id (required) is the claim being released, as returned by
    # claim_agent_reply_draft; only that claim can be released, anything else returns 409.
    # Allowed roles: api, admin, developer, billing, user.
    def release_agent_reply_draft(agent_reply_draft_id:, claim_id:, permanent: nil, **opts)
      @client.require_params("agentReplyDraftId" => agent_reply_draft_id, "claimId" => claim_id)
      token = opts[:token]
      headers = opts[:headers]
      safe_id = CGI.escape(agent_reply_draft_id.to_s)
      body = { claimId: claim_id }
      body[:permanent] = permanent unless permanent.nil?
      @client.request("/agent/drafts/#{safe_id}/release", method: :post, body: body, token: token, headers: headers)
    end

    # POST /agent/profiles/:agentProfileId/publish
    # Publish an agent profile, setting publishStatus to "published" and stamping
    # publishedAt. The server rejects the call with 400 when the agent has no enabled
    # deployment, and with 409 when the agent is inactive.
    # Allowed roles: api, admin, developer.
    def publish_agent_profile(agent_profile_id:, **opts)
      @client.require_params("agentProfileId" => agent_profile_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      @client.request("/agent/profiles/#{safe_id}/publish", method: :post, token: token, headers: headers)
    end

    # POST /agent/profiles/:agentProfileId/unpublish
    # Return an agent profile to draft (publishStatus "draft").
    # Allowed roles: api, admin, developer.
    def unpublish_agent_profile(agent_profile_id:, **opts)
      @client.require_params("agentProfileId" => agent_profile_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_profile_id.to_s)
      @client.request("/agent/profiles/#{safe_id}/unpublish", method: :post, token: token, headers: headers)
    end

    # GET /agent/tenant-settings?groupId=...&subgroupId=...
    # Read the tenant AI settings for a scope (group, or a subgroup within it). Returns the
    # scope's own row only — no group-level fallback.
    # Allowed roles: api, admin, developer, billing, user.
    def get_tenant_ai_settings(group_id:, subgroup_id: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id)
      @client.request("/agent/tenant-settings#{qs}", method: :get, token: token, headers: headers)
    end

    # PUT /agent/tenant-settings?groupId=...&subgroupId=...
    # Create or update (upsert) the tenant AI settings for a scope. The scope comes from the
    # query params; settings_data is the JSON body (brandName, tone, timezone, businessHours
    # [{day, closed, open, close}], afterHoursMessage).
    # Allowed roles: api, admin, developer.
    def upsert_tenant_ai_settings(group_id:, subgroup_id: nil, settings_data: {}, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id)
      @client.request("/agent/tenant-settings#{qs}", method: :put, body: settings_data, token: token, headers: headers)
    end

    # DELETE /agent/tenant-settings?groupId=...&subgroupId=...
    # Delete the tenant AI settings for a scope.
    # Allowed roles: api, admin, developer.
    def delete_tenant_ai_settings(group_id:, subgroup_id: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id)
      @client.request("/agent/tenant-settings#{qs}", method: :delete, token: token, headers: headers)
    end

    # GET /agent/knowledge?groupId=...&subgroupId=...&agentProfileId=...&page=...&limit=...
    # List the knowledge-base items an agent can answer from (RAG), scoped to a group and
    # optionally narrowed to a subgroup and/or a single agent. Paginated (server default 25
    # per page, max 100).
    # Allowed roles: api, admin, developer, billing, user.
    def get_knowledge_items(group_id:, subgroup_id: nil, agent_profile_id: nil, page: nil, limit: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, agentProfileId: agent_profile_id, page: page, limit: limit)
      @client.request("/agent/knowledge#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /agent/knowledge/:knowledgeItemId
    # Get a single knowledge item by id.
    # Allowed roles: api, admin, developer, billing, user.
    def get_knowledge_item(knowledge_item_id:, **opts)
      @client.require_params("knowledgeItemId" => knowledge_item_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(knowledge_item_id.to_s)
      @client.request("/agent/knowledge/#{safe_id}", method: :get, token: token, headers: headers)
    end

    # POST /agent/knowledge
    # Create a knowledge item. item_data is the JSON body and must include the required fields
    # groupId (starts with 'G') and text. Optional: subgroupId (starts with 'S', nullable),
    # agentProfileId (nullable), title, source ("manual"|"url"|"document"|"import"), enabled,
    # metadata. The raw text is stored; Atlas Vector Search owns the embedding.
    # Allowed roles: api, admin, developer.
    def create_knowledge_item(item_data:, **opts)
      @client.require_params("itemData" => item_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/agent/knowledge", method: :post, body: item_data, token: token, headers: headers)
    end

    # PUT /agent/knowledge/:id
    # Update a knowledge item. update_data is the JSON body (title, text, source, enabled,
    # metadata); the item's scope is immutable.
    # Allowed roles: api, admin, developer.
    def update_knowledge_item(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/agent/knowledge/#{safe_id}", method: :put, body: update_data, token: token, headers: headers)
    end

    # DELETE /agent/knowledge/:id
    # Delete a knowledge item by its id.
    # Allowed roles: api, admin, developer.
    def delete_knowledge_item(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/agent/knowledge/#{safe_id}", method: :delete, token: token, headers: headers)
    end

    # GET /agent/tools?groupId=...&subgroupId=...&agentProfileId=...&type=...&page=...&limit=...
    # List the tools defined under a group (webhook, configured builtin, mcp). webhookAuth
    # secrets are redacted. Paginated (server default 25 per page, max 100).
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_tools(group_id:, subgroup_id: nil, agent_profile_id: nil, type: nil, page: nil, limit: nil, **opts)
      @client.require_params("groupId" => group_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, agentProfileId: agent_profile_id, type: type, page: page, limit: limit)
      @client.request("/agent/tools#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /agent/tools/:agentToolId
    # Get a single agent tool by id. webhookAuth secrets are redacted.
    # Allowed roles: api, admin, developer, billing, user.
    def get_agent_tool(agent_tool_id:, **opts)
      @client.require_params("agentToolId" => agent_tool_id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(agent_tool_id.to_s)
      @client.request("/agent/tools/#{safe_id}", method: :get, token: token, headers: headers)
    end

    # POST /agent/tools
    # Create an agent tool. tool_data is the JSON body and must include groupId (starts with 'G'),
    # name, and description. Type-specific: type ("builtin"|"webhook"|"mcp"); webhook => webhookUrl
    # (a public https URL), builtin => builtinKey, mcp => mcpServerUrl. webhookAuth MUST be
    # { "headers" => { name => value }, "signingSecret" => string } — any other shape (e.g.
    # { "header", "value" }) is rejected with a 400. headers are sent verbatim on every call
    # (reserved/framing and x-signalhouse-* names rejected); signingSecret makes us send
    # X-SignalHouse-Signature: sha256=HMAC-SHA256("#{X-SignalHouse-Timestamp}.#{rawBody}") so you can
    # verify the call and reject replays. Stored, never echoed back.
    # Allowed roles: api, admin, developer.
    def create_agent_tool(tool_data:, **opts)
      @client.require_params("toolData" => tool_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/agent/tools", method: :post, body: tool_data, token: token, headers: headers)
    end

    # PUT /agent/tools/:id
    # Update an agent tool. update_data is the JSON body; the tool's scope is immutable and a
    # supplied webhookUrl is SSRF-checked.
    # Allowed roles: api, admin, developer.
    def update_agent_tool(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/agent/tools/#{safe_id}", method: :put, body: update_data, token: token, headers: headers)
    end

    # DELETE /agent/tools/:id
    # Delete an agent tool by its id.
    # Allowed roles: api, admin, developer.
    def delete_agent_tool(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/agent/tools/#{safe_id}", method: :delete, token: token, headers: headers)
    end
  end
end
