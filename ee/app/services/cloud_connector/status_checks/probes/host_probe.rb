# frozen_string_literal: true

require 'socket'

module CloudConnector
  module StatusChecks
    module Probes
      class HostProbe < BaseProbe
        attr_reader :host, :port

        def initialize(host, port)
          @host = host
          @port = port
        end

        def execute(*)
          return success("#{@host} reachable") if reachable?

          failure("#{@host} unreachable")
        end

        private

        def reachable?
          conn = TCPSocket.new(@host, @port, connect_timeout: 5)
          true
        rescue Errno::ENETUNREACH, Errno::EHOSTUNREACH
          false
        ensure
          conn&.close
        end
      end
    end
  end
end
