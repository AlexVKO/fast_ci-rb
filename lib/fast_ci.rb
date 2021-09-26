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
      puts "\n\e[36mDEBUG: \e[0m #{msg}\n" if ENV["FAST_CI_DEBUG"]
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
      connection.flush
    end

    def await
      before_start_connection
      Async do |task|
        Async::WebSocket::Client.connect(endpoint) do |connection|
          after_start_connection
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
                result = @on[:deq].call(tests)
                task.async do
                  send_msg(connection, "deq", result)
                end
              else
                break
              end
            when "error"
              raise(response.inspect)
            else
              puts response
            end
          end
        ensure
          send_msg(connection, "leave")
          connection.close
        end
      end
    end

    private

    # https://github.com/bblimke/webmock/blob/b709ba22a2949dc3bfac662f3f4da88a21679c2e/lib/webmock/http_lib_adapters/async_http_client_adapter.rb#L8
    def before_start_connection
      WebMock::HttpLibAdapters::AsyncHttpClientAdapter.disable! if defined?(WebMock::HttpLibAdapters::AsyncHttpClientAdapter)
    end

    # https://github.com/bblimke/webmock/blob/b709ba22a2949dc3bfac662f3f4da88a21679c2e/lib/webmock/http_lib_adapters/async_http_client_adapter.rb#L8
    def after_start_connection
      WebMock::HttpLibAdapters::AsyncHttpClientAdapter.enable! if defined?(WebMock::HttpLibAdapters::AsyncHttpClientAdapter)
    end

    def handle_join(connection, response)
      @node_index = response[:node_index]

      FastCI.debug("NODE_INDEX: #{@node_index}")

      if node_index == 0
        send_msg(connection, "enq", { tests: @on[:enq_request].call })
      end

      if response[:state] == "running"
        send_msg(connection, "deq")
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
