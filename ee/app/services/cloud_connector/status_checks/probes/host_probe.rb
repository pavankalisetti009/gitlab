# frozen_string_literal: true

require 'socket'

module CloudConnector
  module StatusChecks
    module Probes
      class HostProbe < BaseProbe
        attr_reader :host, :port

        def initialize(service_url)
          uri = URI.parse(service_url)
          @host = uri.host
          @port = uri.port
        end

        def execute(*)
          succeeded, message = *connection_succeeded?
          return failure(message) unless succeeded

          success(message)
        end

        private

        def connection_succeeded?
          conn = TCPSocket.new(@host, @port, connect_timeout: 5)
          [true, host_reachable_text]
        rescue Errno::ENETUNREACH, Errno::EHOSTUNREACH
          [false, host_unreachable_text]
        rescue StandardError => e
          [false, connection_failed_text(e)]
        ensure
          conn&.close
        end

        # Keeping this as a separate translation key since we want to eventually link this
        # to user/gitlab_duo/turn_on_off.html
        def networking_cta
          _('If you use firewalls or proxy servers, they must allow traffic to this host.')
        end

        def host_reachable_text
          format(_('%{host} reachable.'), host: @host)
        end

        def host_unreachable_text
          format(_('%{host} could not be reached. %{cta}'), host: @host, cta: networking_cta)
        end

        def connection_failed_text(error)
          format(_('%{host} connection failed: %{error}.'), host: @host, error: error.message)
        end
      end
    end
  end
end
