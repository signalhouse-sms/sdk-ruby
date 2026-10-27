# frozen_string_literal: true

module SignalHouseSms
  class Tickets
    attr_reader :admin

    def initialize(client, enable_admin)
      @client = client
      @admin = Admin.new(client) if enable_admin
    end

    class Admin
      def initialize(client)
        @client = client
      end

      # GET /admin/ticket/jira/metadata — staff-only
      def get_jira_metadata(**opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        @client.request("/admin/ticket/jira/metadata", method: :get, token: token, headers: headers)
      end

      # GET /admin/ticket/jira/epics — staff-only
      def search_jira_epics(query: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(query: query)
        @client.request("/admin/ticket/jira/epics#{qs}", method: :get, token: token, headers: headers)
      end

      # GET /admin/ticket/jira/parent-issues — staff-only
      def search_jira_parent_issues(query: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(query: query)
        @client.request("/admin/ticket/jira/parent-issues#{qs}", method: :get, token: token, headers: headers)
      end

      # GET /admin/ticket/jira/assignees — staff-only
      def search_jira_assignees(query: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(query: query)
        @client.request("/admin/ticket/jira/assignees#{qs}", method: :get, token: token, headers: headers)
      end

      # GET /admin/ticket/jira/labels — staff-only
      def search_jira_labels(query: nil, **opts)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        qs = @client.get_query_string(query: query)
        @client.request("/admin/ticket/jira/labels#{qs}", method: :get, token: token, headers: headers)
      end

      # POST /admin/ticket/jira — staff-only
      def create_jira_ticket(data:, **opts)
        @client.require_params("data" => data)
        token = opts[:token]
        headers = HttpClient.headers_for(opts)
        @client.request("/admin/ticket/jira", method: :post, body: data, token: token, headers: headers)
      end
    end
  end
end
