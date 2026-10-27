# frozen_string_literal: true

require_relative "signalhouse_sms/version"
require_relative "signalhouse_sms/errors"
require_relative "signalhouse_sms/http_client"

# Domain modules
require_relative "signalhouse_sms/domains/agents"
require_relative "signalhouse_sms/domains/auth"
require_relative "signalhouse_sms/domains/billing"
require_relative "signalhouse_sms/domains/brands"
require_relative "signalhouse_sms/domains/campaigns"
require_relative "signalhouse_sms/domains/groups"
require_relative "signalhouse_sms/domains/landings"
require_relative "signalhouse_sms/domains/messages"
require_relative "signalhouse_sms/domains/notifications"
require_relative "signalhouse_sms/domains/numbers"
require_relative "signalhouse_sms/domains/registrations"
require_relative "signalhouse_sms/domains/onboarding"
require_relative "signalhouse_sms/domains/shortlinks"
require_relative "signalhouse_sms/domains/subgroups"
require_relative "signalhouse_sms/domains/subscriptions"
require_relative "signalhouse_sms/domains/templates"
require_relative "signalhouse_sms/domains/tickets"
require_relative "signalhouse_sms/domains/users"
require_relative "signalhouse_sms/domains/voice"
require_relative "signalhouse_sms/domains/webhooks"

# Client (must be last — depends on all domains)
require_relative "signalhouse_sms/client"
