# frozen_string_literal: true

require_relative "lib/signalhouse_sms/version"

Gem::Specification.new do |spec|
  spec.name          = "signalhouse-sms"
  spec.version       = SignalHouseSms::VERSION
  spec.authors       = ["SignalHouse LLC"]
  spec.email         = ["support@signalhouse.io"]

  spec.summary       = "Ruby SDK for the SignalHouse SMS/MMS messaging API"
  spec.description   = "Official Ruby SDK for the SignalHouse API. Provides a simple interface for sending SMS/MMS messages, managing phone numbers, 10DLC brand/campaign registration, billing, and more."
  spec.homepage      = "https://github.com/signalhouse-sms/sdk-ruby"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.files         = Dir["lib/**/*.rb"] + ["signalhouse-sms.gemspec", "Gemfile", "README.md"]
  spec.require_paths = ["lib"]

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
end
