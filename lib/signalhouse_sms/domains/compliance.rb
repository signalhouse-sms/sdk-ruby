# frozen_string_literal: true

module SignalHouseSms
  # Compliance cases under /compliance. Signal House opens a case when a carrier suspends one of your objects, a carrier
  # escalates a message, or Signal House needs something from you. You read your cases, answer their requirements and
  # upload files; only Signal House opens, works and closes them.
  class Compliance
    def initialize(client, multipart_client, _enable_admin)
      @client = client
      @multipart_client = multipart_client
    end

    # GET /compliance/cases — the compliance cases you can see, newest first. counts.waitingOnYou is the open cases
    # with requirements still to answer. Roles: api, admin, developer, billing, user.
    #
    # @param group_id [String, nil] A group you can view; nil uses your active group
    # @param status [String, nil] OPEN, LIFT_REQUESTED or CLOSED
    # @param stage [String, nil] new, customer, ready, lift_requested or closed
    # @param object_type [String, nil] CAMPAIGN, BRAND, NUMBER, RCS_AGENT or SUBGROUP
    # @param object_id [String, nil] The object's id
    # @param subgroup_id [String, nil] Only cases in this subgroup
    # @param suspended [Boolean, nil] true for cases with an open suspension or hold, false for the rest
    # @param from [String, nil] Opened on or after this ISO 8601 time
    # @param to [String, nil] Opened on or before this ISO 8601 time
    # @param sort [String, nil] createdAt (the API default), fixBy or severity
    # @param page [Integer, nil] Page number, from 1
    # @param limit [Integer, nil] Cases per page, 1-200
    # @return [Hash] {data, total, page, limit, totalPages, counts: {open, waitingOnYou}}
    def get_cases(group_id: nil, status: nil, stage: nil, object_type: nil, object_id: nil, subgroup_id: nil, suspended: nil,
                  from: nil, to: nil, sort: nil, page: nil, limit: nil, **opts)
      qs = @client.get_query_string(groupId: group_id, status: status, stage: stage, objectType: object_type, objectId: object_id,
                                    subgroupId: subgroup_id, suspended: suspended, from: from, to: to, sort: sort, page: page, limit: limit)
      @client.request("/compliance/cases#{qs}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /compliance/cases/:caseId — one compliance case: its stage, suspensions, tickets and requirements.
    # Roles: api, admin, developer, billing, user.
    #
    # @param case_id [String] The case (e.g. "CASE-12")
    # @return [Hash] The case
    # @raise [SignalHouseSms::ValidationError] If case_id is missing
    def get_case(case_id:, **opts)
      @client.require_params("caseId" => case_id)
      safe_case_id = CGI.escape(case_id.to_s)
      @client.request("/compliance/cases/#{safe_case_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # PUT /compliance/cases/:caseId/requirements/:requirementId — answer one requirement with a note, files, or both.
    # A RECORDS requirement needs a file or a note. Roles: api, admin, developer, user.
    #
    # @param case_id [String] The case (e.g. "CASE-12")
    # @param requirement_id [String] The requirement (e.g. "CASE-12-1")
    # @param answer [String, nil] What you did, up to 2,000 characters
    # @param file_ids [Array<String>, nil] Up to 10 fileIds from upload_file, on this case
    # @return [Hash] The case
    # @raise [SignalHouseSms::ValidationError] If case_id or requirement_id is missing
    def answer_requirement(case_id:, requirement_id:, answer: nil, file_ids: nil, **opts)
      @client.require_params("caseId" => case_id, "requirementId" => requirement_id)
      safe_case_id = CGI.escape(case_id.to_s)
      safe_requirement_id = CGI.escape(requirement_id.to_s)
      body = { answer: answer, fileIds: file_ids }.compact
      @client.request("/compliance/cases/#{safe_case_id}/requirements/#{safe_requirement_id}", method: :put, body: body, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # POST /compliance/files (multipart) — upload a file to a compliance case (CSV, XLSX, PDF, PNG, JPG or TXT, up to
    # 10 MB). Pass the returned fileId in file_ids when you answer the requirement. Roles: api, admin, developer, user.
    #
    # file may be a file hash ({ filename:, io:, content_type: }) or any value the multipart client accepts for the
    # "file" field.
    #
    # @param case_id [String] The case the file answers
    # @param file [Hash, Object] The file
    # @param requirement_id [String, nil] The requirement the file answers
    # @return [Hash] {fileId, fileName, mimeType, size}
    # @raise [SignalHouseSms::ValidationError] If case_id or file is missing
    def upload_file(case_id:, file:, requirement_id: nil, **opts)
      @client.require_params("caseId" => case_id, "file" => file)
      form_data = { "caseId" => case_id.to_s }
      form_data["requirementId"] = requirement_id.to_s unless requirement_id.nil? || requirement_id.to_s.empty?
      form_data["file"] = file
      @multipart_client.request("/compliance/files", method: :post, body: form_data, token: opts[:token], headers: HttpClient.headers_for(opts))
    end

    # GET /compliance/files/:fileId — download a compliance file. Roles: api, admin, developer, billing, user.
    #
    # @param file_id [String] The fileId upload_file returned
    # @return [Hash] The download; a body that is not JSON comes back as data["rawBody"], the file bytes
    # @raise [SignalHouseSms::ValidationError] If file_id is missing
    def get_file(file_id:, **opts)
      @client.require_params("fileId" => file_id)
      safe_file_id = CGI.escape(file_id.to_s)
      @client.request("/compliance/files/#{safe_file_id}", method: :get, token: opts[:token], headers: HttpClient.headers_for(opts))
    end
  end
end
