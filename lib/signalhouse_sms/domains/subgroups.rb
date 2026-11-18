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

    # GET /subgroup/ghl-location-lookup?groupId=...&ghlLocationId=...&subgroupId=...
    # Resolves the mapping between a GoHighLevel location and a Signal House subgroup, in either
    # direction. Provide exactly one of ghl_location_id or subgroup_id. group_id is optional -
    # customer roles default to their own accessible group(s) and are rejected if they name a group
    # they don't belong to; a subgroup_id/ghl_location_id that belongs to a different group than the
    # caller's returns a 404, identical to a nonexistent one.
    def lookup_ghl_location(group_id: nil, ghl_location_id: nil, subgroup_id: nil, **opts)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(groupId: group_id, ghlLocationId: ghl_location_id, subgroupId: subgroup_id)
      @client.request("/subgroup/ghl-location-lookup#{qs}", method: :get, token: token, headers: headers)
    end

    # PUT /subgroup/ghl-location-link
    # Links (or, with ghl_location_id: nil, unlinks) a GoHighLevel location to a subgroup. Requires
    # signalhouse_api or signalhouse_admin role. At most one subgroup may hold a given
    # ghl_location_id; linking it here steals it from any other subgroup that currently holds it.
    # ghl_location_name omitted leaves the subgroup's currently stored name untouched (only when
    # ghl_location_id is unchanged - otherwise it is cleared); always cleared when unlinking.
    # claimed_at (a Time/DateTime or ISO 8601 string) is required when linking - when this link was
    # locally claimed by the caller, used to detect and reject a delayed/out-of-order push whose claim
    # has since been superseded by a newer one recorded elsewhere. Ignored when unlinking.
    def link_ghl_location(subgroup_id:, ghl_location_id:, ghl_location_name: :__omit__, claimed_at: nil, **opts)
      @client.require_params("subgroupId" => subgroup_id)
      @client.require_params("claimedAt" => claimed_at) unless ghl_location_id.nil?
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      body = { "subgroupId" => subgroup_id, "ghlLocationId" => ghl_location_id }
      body["ghlLocationName"] = ghl_location_name unless ghl_location_name == :__omit__
      body["claimedAt"] = claimed_at.respond_to?(:iso8601) ? claimed_at.iso8601 : claimed_at unless claimed_at.nil?
      @client.request("/subgroup/ghl-location-link", method: :put, body: body, token: token, headers: headers)
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
