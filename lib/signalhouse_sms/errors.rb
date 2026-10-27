# frozen_string_literal: true

module SignalHouseSms
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      super(message)
      @status = status
    end
  end

  class ValidationError < Error
    def initialize(param_name)
      super("Missing required parameter: #{param_name}", status: 400)
    end
  end
end
