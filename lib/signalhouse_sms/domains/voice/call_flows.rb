# frozen_string_literal: true

require "cgi"

module SignalHouseSms
  # Call Flows — customer-built call trees (greeting, menu, forward, voicemail,
  # hang up) that run when a number's route, or its Programmable Voice Profile,
  # names them with routeAction CALL_FLOW.
  #
  # Each flow has one working draft, edited with save_draft, and published
  # versions: publish validates the draft and makes it the version calls run,
  # while the draft stays editable without affecting calls.
  #
  # Routes mounted under /voice/api/v1/call-flows on the Voice service.
  # Accessed via client.voice.call_flows.
  class VoiceCallFlows
    # Sent where an endpoint takes no input. The client always declares JSON,
    # and the Voice service rejects a JSON request with no body.
    EMPTY_BODY = {}.freeze

    def initialize(client, enable_admin)
      @client = client
      @enable_admin = enable_admin
    end

    # GET /voice/api/v1/call-flows
    #
    # List the account's call flows, newest first by default. Optional filters:
    # page, limit, q, subgroupId, includeDeleted (boolean), sortBy
    # (createdAt|updatedAt|name), sortOrder (asc|desc).
    # Returns { data: [...], meta: { total, page, limit, totalPages } }.
    def list(filters: {}, **opts)
      qs = @client.get_query_string(filters || {})
      @client.request("/voice/api/v1/call-flows#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/api/v1/call-flows/catalog
    #
    # List the step types this service can run, with the outcomes each one offers.
    # Returns { data: { nodeTypes: [{ type, ports, configurable }] } }.
    def catalog(**opts)
      @client.request("/voice/api/v1/call-flows/catalog", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /voice/api/v1/call-flows/:id
    #
    # Get a call flow with its working draft and the issues that stop it being
    # published. Returns { data: { ...flow, draft: { versionId, nodes, edges, issues } } }.
    def get(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/call-flows/#{safe_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/api/v1/call-flows
    #
    # Create a call flow, with its working draft and the Inbound Call step every
    # flow starts from. Required: name (unique within the subgroup) and
    # subgroupId. The subgroup is fixed once created; only numbers and
    # Programmable Voice Profiles in it can run the flow.
    # Returns { data: { ...flow, draft } }.
    def create(flow_data:, **opts)
      @client.require_params("flowData" => flow_data)
      @client.request("/voice/api/v1/call-flows", method: :post, body: flow_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PATCH /voice/api/v1/call-flows/:id
    #
    # Rename a call flow, or enable or disable it (partial update). Fields: name,
    # status (ACTIVE|DISABLED). A disabled flow does not run; numbers routed to
    # it fall through to their next routing layer.
    # Returns { data: { ...flow, draft } }.
    def update(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/call-flows/#{safe_id}", method: :patch, body: update_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # DELETE /voice/api/v1/call-flows/:id
    #
    # Delete a call flow. Reversible with restore: while deleted, numbers and
    # profiles routed to it fall through to their next routing layer.
    # Returns { data: { ...flow } }.
    def delete(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/call-flows/#{safe_id}", method: :delete, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/api/v1/call-flows/:id/restore
    #
    # Restore a deleted call flow. Returns { data: { ...flow, draft } }.
    def restore(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/call-flows/#{safe_id}/restore", method: :post, body: EMPTY_BODY, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/api/v1/call-flows/:id/duplicate
    #
    # Copy a call flow and its working draft into a new flow in the same
    # subgroup. The copy is not published. name defaults to "<name> (copy)".
    # Returns { data: { ...flow, draft } }.
    def duplicate(id:, name: nil, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      body = name.nil? || name.to_s.empty? ? EMPTY_BODY : { "name" => name }
      @client.request("/voice/api/v1/call-flows/#{safe_id}/duplicate", method: :post, body: body, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PUT /voice/api/v1/call-flows/:id/draft
    #
    # Replace the working draft: { nodes: [...], edges: [...] }. Each node is
    # { id, type, name, config, positionX, positionY } and each edge
    # { id, fromNodeId, toNodeId, port }; ids are UUIDs you generate and are kept
    # across saves. The whole draft is saved even when it is not finished; the
    # issues that would stop it being published come back in the response.
    # Returns { data: { nodes, edges, issues } }.
    def save_draft(id:, draft:, **opts)
      @client.require_params("id" => id, "draft" => draft)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/call-flows/#{safe_id}/draft", method: :put, body: draft, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /voice/api/v1/call-flows/:id/publish
    #
    # Publish the working draft, making it the version calls run. A draft that
    # is not ready returns 400 with error.issues listing each step that needs
    # attention. Returns { data: { id, versionNumber, status, publishedAt } }.
    def publish(id:, **opts)
      @client.require_params("id" => id)
      safe_id = CGI.escape(id.to_s)
      @client.request("/voice/api/v1/call-flows/#{safe_id}/publish", method: :post, body: EMPTY_BODY, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
