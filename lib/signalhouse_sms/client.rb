# frozen_string_literal: true

require "securerandom"

module SignalHouseSms
  class Client
    attr_reader :agents, :auth, :billing, :brands, :campaigns, :groups, :landings,
                :messages, :notifications, :numbers, :registrations, :onboarding,
                :shortlinks, :subgroups, :subscriptions, :templates, :tickets, :users, :voice, :webhooks

    # Initialize a new SignalHouse client.
    #
    # @param api_key [String] Your SignalHouse API key (Bearer token)
    # @param base_url [String] The base URL of the SignalHouse API
    # @param enable_admin [Boolean] Whether to enable admin-only methods
    def initialize(api_key:, base_url:, enable_admin: false)
      raise SignalHouseSms::ValidationError.new("api_key") if api_key.nil? || api_key.to_s.strip.empty?
      raise SignalHouseSms::ValidationError.new("base_url") if base_url.nil? || base_url.to_s.strip.empty?

      json_client = HttpClient.new(base_url: base_url, api_key: api_key, multipart: false)
      multipart_client = HttpClient.new(base_url: base_url, api_key: api_key, multipart: true)

      @agents         = Agents.new(json_client, enable_admin)
      @auth           = Auth.new(json_client, enable_admin)
      @billing        = Billing.new(json_client, enable_admin)
      @brands         = Brands.new(json_client, multipart_client, enable_admin)
      @campaigns      = Campaigns.new(json_client, multipart_client, enable_admin)
      @groups         = Groups.new(json_client, enable_admin)
      @landings       = Landings.new(json_client, multipart_client, enable_admin)
      @messages       = Messages.new(json_client, multipart_client, enable_admin)
      @notifications  = Notifications.new(json_client, enable_admin)
      @numbers        = Numbers.new(json_client, multipart_client, enable_admin)
      @registrations = Registrations.new(json_client, enable_admin)
      @onboarding     = Onboarding.new(json_client, enable_admin)
      @shortlinks     = Shortlinks.new(json_client, enable_admin)
      @subgroups      = Subgroups.new(json_client, enable_admin)
      @subscriptions  = Subscriptions.new(json_client, enable_admin)
      @templates      = Templates.new(json_client, multipart_client, enable_admin)
      @tickets        = Tickets.new(json_client, enable_admin)
      @users          = Users.new(json_client, enable_admin)
      @voice          = Voice.new(json_client, enable_admin)
      @webhooks       = Webhooks.new(json_client, enable_admin)
    end
  end
end
