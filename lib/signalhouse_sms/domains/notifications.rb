# frozen_string_literal: true

module SignalHouseSms
  class Notifications
    def initialize(client, _enable_admin)
      @client = client
    end

    # GET /notification?...
    def get_notifications(id: nil, group_id: nil, page: nil, limit: nil, status: nil, event_types: nil, **opts)
      @client.require_params("id or groupId" => (id || group_id))
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      qs = @client.get_query_string(id: id, groupId: group_id, page: page, limit: limit, status: status, eventTypes: event_types)
      @client.request("/notification#{qs}", method: :get, token: token, headers: headers)
    end

    # PUT /notification/status
    def update_notification_status(ids:, status:, **opts)
      @client.require_params("ids" => ids, "status" => status)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      @client.request("/notification/status", method: :put, body: { ids: ids, status: status }, token: token, headers: headers)
    end

    # DELETE /notification/:id
    def delete_notification(id:, **opts)
      @client.require_params("id" => id)
      token = opts[:token]
      headers = HttpClient.headers_for(opts)
      safe_id = CGI.escape(id.to_s)
      @client.request("/notification/#{safe_id}", method: :delete, token: token, headers: headers)
    end
  end
end
