# frozen_string_literal: true

require 'socket'

module CloudConnector
  module StatusChecks
    module Probes
      class HostProbe < BaseProbe
        extend ::Gitlab::Utils::Override

        attr_reader :host, :port

        validate :validate_connection

        def initialize(service_url)
          uri = URI.parse(service_url)
          @host = uri.host
          @port = uri.port
        end

        private

        override :success_message
        def success_message
          format(_('%{host} reachable.'), host: @host)
        end

        def validate_connection
          conn = ::TCPSocket.new(host, port, connect_timeout: 5)
        rescue Errno::ENETUNREACH, Errno::EHOSTUNREACH
          errors.add(:base, host_unreachable_text)
        rescue StandardError => e
          errors.add(:base, connection_failed_text(e))
        ensure
          conn&.close
        end

        # Keeping this as a separate translation key since we want to eventually link this
        # to user/gitlab_duo/turn_on_off.html
        def networking_cta
          _('If you use firewalls or proxy servers, they must allow traffic to this host.')
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
