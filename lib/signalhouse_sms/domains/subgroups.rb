# frozen_string_literal: true

module SignalHouseSms
  class Subgroups
    def initialize(client, _enable_admin)
      @client = client
    end

    # GET /subgroup?...
    def get_subgroups(id: nil, group_id: nil, page: nil, limit: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(id: id, groupId: group_id, page: page, limit: limit)
      @client.request("/subgroup#{qs}", method: :get, token: token, headers: headers)
    end

    # GET /subgroup/counts?groupId=...&subgroupId=...&limit=...&offset=... Only signalhouse_admin
    # can query all groups; every other allowed role is restricted to its JWT group scope.
    def get_subgroup_counts(group_id: nil, subgroup_id: nil, limit: nil, offset: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, subgroupId: subgroup_id, limit: limit, offset: offset)
      @client.request("/subgroup/counts#{qs}", method: :get, token: token, headers: headers)
    end

    # POST /subgroup
    # subgroup_data may include optional carrierIdFamily and carrierIdRegion.
    # Setting those fields requires signalhouse_api, signalhouse_admin, signalhouse_user,
    # api, admin, developer, or billing role.
    def create_subgroup(subgroup_data:, **opts)
      @client.require_params("subgroupData" => subgroup_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/subgroup", method: :post, body: subgroup_data, token: token, headers: headers)
    end

    # PUT /subgroup/:id
    # update_data may include optional carrierIdFamily and carrierIdRegion.
    # Setting those fields requires signalhouse_api, signalhouse_admin, signalhouse_user,
    # api, admin, developer, or billing role.
    # update_data may also include cnamAutoApply (boolean; turns caller name auto-apply on or off, so
    # eligible numbers get their brand's registered name on outbound calls) and cnamBrandId (string or
    # nil; default caller-ID brand for numbers with no campaign, must be a verified brand in this
    # subgroup, required when turning auto-apply on in a subgroup with more than one verified brand).
    # Setting those fields requires signalhouse_api, signalhouse_admin, signalhouse_user, api, admin,
    # or developer role.
    def update_subgroup(id:, update_data:, **opts)
      @client.require_params("id" => id, "updateData" => update_data)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/subgroup/#{safe_id}", method: :put, body: update_data, token: token, headers: headers)
    end

    # DELETE /subgroup/:id
    def delete_subgroup(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/subgroup/#{safe_id}", method: :delete, token: token, headers: headers)
    end
  end
end
