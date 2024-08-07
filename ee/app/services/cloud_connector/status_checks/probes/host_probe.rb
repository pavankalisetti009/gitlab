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
          return success(host_reachable_text) if reachable?

          failure(host_unreachable_text)
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
      end
    end
  end
end
