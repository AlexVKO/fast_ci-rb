# frozen_string_literal: true

require_relative "fast_ci/version"
require_relative "fast_ci/configuration"
require_relative "fast_ci/exceptions"

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'

module FastCI
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= FastCI::Configuration.new
    end

    def configure
      yield(configuration)
    end

    def ws
      @ws ||= WebSocket.new
    end

    def await
      ws.await
    end

    def debug(msg)
      puts "\e[36mDEBUG: \e[0m #{msg}" if ENV["DEBUG"]
    end
  end

  class WebSocket
    attr_reader :node_index

    SUPPORTED_EVENTS=%i[enq_request deq].freeze

    def initialize
      @on = {}
      @ref = 0
    end

    def on(event, &block)
      raise(EventNotSupportedError.new(event)) unless SUPPORTED_EVENTS.include?(event)
      raise(EventAlreadyDefinedError.new(event)) if @on[event]

      @on[event] = block
    end

    def send_msg(connection, event, payload = {})
      FastCI.debug("ws#send_msg: #{event} -> #{payload.inspect}")
      connection.write({"topic": topic, "event": event, "payload":payload, "ref": ref})
    end

    def await
      Async do |task|
        Async::WebSocket::Client.connect(endpoint) do |connection|
          send_msg(connection, "phx_join")

          while message = connection.read
            FastCI.debug("ws#msg_received: #{message.inspect}")

            response = message.dig(:payload, :response)

            case response&.dig(:event) || message.dig(:event)
            when 'join'
              handle_join(connection, response)
            when 'deq_request'
              handle_deq_request(connection, response)
            when 'deq'
              if (tests = response[:tests]).any?
                @on[:deq].call(tests)
                send_msg(connection, "deq")
              else
                connection.close
              end
            when "error"
              raise(response.inspect)
            else
              puts response
            end
          end
        end
      end
    end

    private

    def handle_join(connection, response)
      @node_index = response[:node_index]

      FastCI.debug("NODE_INDEX: #{@node_index}")

      if node_index == 0
        send_msg(connection, "enq", { tests: @on[:enq_request].call })
      end
    end

    def handle_deq_request(connection, response)
      send_msg(connection, "deq")
    end

    def ref
      @ref += 1
    end

    def topic
      "test_orchestrator:#{FastCI.configuration.run_key}-#{FastCI.configuration.build_id}"
    end

    def endpoint
      params = URI.encode_www_form({
        build_id: FastCI.configuration.build_id,
        run_key: FastCI.configuration.run_key,
        secret_key: FastCI.configuration.secret_key,
        commit: FastCI.configuration.commit,
        branch: FastCI.configuration.branch,
      })

      url = "ws://#{FastCI.configuration.api_url}/test_orchestrators/socket/websocket?#{params}"

      Async::HTTP::Endpoint.parse(url)
    end
  end
end
