# frozen_string_literal: true

module FastCI
  class EventAlreadyDefinedError < StandardError
    def initialize(event)
      super("Event '#{event}' is already defined")
    end
  end

  class EventNotSupportedError < StandardError
    def initialize(event)
      msg = "Event '#{event}' not supported. \n" +
        "Supported events are #{FastCI::SUPPORTED_EVENTS.inspect}}"
      super(msg)
    end
  end
end
