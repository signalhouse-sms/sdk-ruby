# frozen_string_literal: true

module SignalHouseSms
  # Request bodies for Templates.
  module TemplatePayloads
    module_function

    # Create body without unset optionals.
    def create_payload(group_id, name, body, tag)
      payload = { groupId: group_id, name: name, body: body }
      payload[:tag] = tag unless tag.nil?
      payload
    end

    # Update body without unset optionals; tag nil clears, UNSET keeps.
    def update_payload(group_id, name, tag, body)
      payload = { groupId: group_id }
      payload[:name] = name unless name.nil?
      payload[:tag] = tag unless tag.equal?(Templates::UNSET)
      payload[:body] = body unless body.nil?
      payload
    end

    # Validate body from exactly one of body or version; raises SignalHouseSms::Error otherwise.
    def validate_payload(group_id, body, version)
      raise SignalHouseSms::Error.new("Pass exactly one of body or version", status: 400) if body.nil? == version.nil?

      body.nil? ? { groupId: group_id, version: version } : { groupId: group_id, body: body }
    end

    # Multipart fields file and groupId; an IO part is named file_name, its path's basename, or "upload".
    def media_form(group_id, file, file_name)
      part = if file.is_a?(Hash)
               file_name.nil? ? file : file.merge(filename: file_name)
             else
               { filename: file_name || (file.respond_to?(:path) ? File.basename(file.path) : "upload"), io: file }
             end
      { "file" => part, "groupId" => group_id.to_s }
    end
  end

  # Versioned message templates: drafts, publication, archiving, validation and template media.
  # Every call carries group_id; per-template calls escape template_id into the path.
  class Templates
    include TemplatePayloads

    # Default for tag: on update, leaving it out keeps the tag and nil clears it.
    UNSET = Object.new.freeze

    def initialize(client, multipart_client, _enable_admin)
      @client = client
      @multipart_client = multipart_client
    end

    # POST /template
    # Create a template whose first draft (version 1) holds body, the raw template body (e.g. an RcsTemplateBody
    # { channel, contentFormat, content, variables, defaults, fallback }).
    # Returns 201 with { head, version }.
    def create(group_id:, name:, body:, tag: nil, **opts)
      @client.require_params("groupId" => group_id, "name" => name, "body" => body)
      payload = create_payload(group_id, name, body, tag)
      @client.request("/template", method: :post, body: payload, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /template?groupId=...
    # state is DRAFT, PUBLISHED or ARCHIVED; channel is "rcs"; sort_by is name, createdAt or updatedAt; sort_order is
    # asc or desc; limit defaults to 25 (max 100). Response: { data: [TemplateSummary], total, page, limit }.
    def list(group_id:, state: nil, channel: nil, tag: nil, search: nil, sort_by: nil,
             sort_order: nil, page: nil, limit: nil, **opts)
      @client.require_params("groupId" => group_id)
      qs = @client.get_query_string(
        groupId: group_id, state: state, channel: channel, tag: tag, search: search,
        sortBy: sort_by, sortOrder: sort_order, page: page, limit: limit
      )
      @client.request("/template#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /template/:templateId?groupId=...&version=...
    # version is a number, "draft" or "published"; omitted reads the published version, else the draft.
    # Returns { head, version }.
    def get(template_id:, group_id:, version: nil, **opts)
      @client.require_params("templateId" => template_id, "groupId" => group_id)
      safe_id = CGI.escape(template_id.to_s)
      qs = @client.get_query_string(groupId: group_id, version: version)
      @client.request("/template/#{safe_id}#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PUT /template/:templateId
    # Save the draft; writes apply directly (last write wins). tag: nil clears the tag and leaving it out
    # keeps it. body is a full replacement. An archived template answers 409 TEMPLATE_ARCHIVED and a
    # name already in use 409 TEMPLATE_NAME_TAKEN. Returns { head, version }.
    def update(template_id:, group_id:, name: nil, tag: UNSET, body: nil, **opts)
      @client.require_params("templateId" => template_id, "groupId" => group_id)
      safe_id = CGI.escape(template_id.to_s)
      payload = update_payload(group_id, name, tag, body)
      @client.request("/template/#{safe_id}", method: :put, body: payload, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /template/:templateId/publish
    # Publish the current draft; no draft answers 409 NO_DRAFT, a draft that changed while it was being published
    # 409 DRAFT_CHANGED (publish again), and an incomplete draft 400 TEMPLATE_INVALID. Returns { head, version }.
    def publish(template_id:, group_id:, **opts)
      @client.require_params("templateId" => template_id, "groupId" => group_id)
      safe_id = CGI.escape(template_id.to_s)
      payload = { groupId: group_id }
      @client.request("/template/#{safe_id}/publish", method: :post, body: payload, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /template/:templateId/archive
    # Returns the template head.
    def archive(template_id:, group_id:, **opts)
      @client.require_params("templateId" => template_id, "groupId" => group_id)
      safe_id = CGI.escape(template_id.to_s)
      payload = { groupId: group_id }
      @client.request("/template/#{safe_id}/archive", method: :post, body: payload, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /template/:templateId/versions?groupId=...
    # Response: { data: [VersionSummary], total, page, limit } (versions without their bodies).
    def versions(template_id:, group_id:, page: nil, limit: nil, **opts)
      @client.require_params("templateId" => template_id, "groupId" => group_id)
      safe_id = CGI.escape(template_id.to_s)
      qs = @client.get_query_string(groupId: group_id, page: page, limit: limit)
      @client.request("/template/#{safe_id}/versions#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /template/:templateId/validate
    # Validate exactly one of body (a candidate body) or version (a stored version selector) without saving.
    # Returns { valid, contentHash, validatorVersion, errors, warnings }.
    def validate(template_id:, group_id:, body: nil, version: nil, **opts)
      @client.require_params("templateId" => template_id, "groupId" => group_id)
      payload = validate_payload(group_id, body, version)
      safe_id = CGI.escape(template_id.to_s)
      @client.request("/template/#{safe_id}/validate", method: :post, body: payload, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /template/capabilities?groupId=...
    # channel is "rcs" (the default); provider is infobip or sinch and adds that provider's limits and unsupported
    # features. Returns the capabilities document.
    def capabilities(group_id:, channel: nil, provider: nil, **opts)
      @client.require_params("groupId" => group_id)
      qs = @client.get_query_string(groupId: group_id, channel: channel, provider: provider)
      @client.request("/template/capabilities#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /template/media (multipart: file, groupId)
    # file is an IO or a { filename:, io:, content_type: } hash; file_name names an IO part. Returns 201 with
    # { mediaId, groupId, url, bytes, mimeType, kind, width, height, createdAt }.
    def upload_media(group_id:, file:, file_name: nil, **opts)
      @client.require_params("groupId" => group_id, "file" => file)
      form_data = media_form(group_id, file, file_name)
      @multipart_client.request("/template/media", method: :post, body: form_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
