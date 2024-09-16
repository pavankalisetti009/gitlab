# frozen_string_literal: true

# In Rails 7.0, whenever `ConnectionPool#disconnect!` is called, each
# connection in the `@available` queue is acquired by the thread and
# verified with a SQL `;` query. If the verification fails, then Rails
# will attempt a reconnect for all those connections in the pool. This
# reconnection can cause unnecessary database connection saturation and
# result in a flood of SET statements on a PostgreSQL host.
#
# Rails 7.1 has fixed this in https://github.com/rails/rails/pull/44576, but
# until we upgrade this patch disables this verification step.
module Gitlab
  module Patch
    # rubocop:disable Gitlab/ModuleWithInstanceVariables -- This patches an upstream class
    module ActiveRecordConnectionPool
      def disconnect_without_verify!
        with_connection_verify_disabled { disconnect! }
      end

      def with_connection_verify_disabled
        synchronize do
          @disable_verify = true

          yield
        ensure
          @disable_verify = false
        end
      end

      def checkout_and_verify(c) # rubocop:disable Naming/MethodParameterName -- This is an upstream method
        c._run_checkout_callbacks do
          c.verify! unless @disable_verify
        end
        c
      rescue # rubocop:disable Style/RescueStandardError -- This is in the upstream code
        remove c
        c.disconnect!
        raise
      end
    end
    # rubocop:enable Gitlab/ModuleWithInstanceVariables
  end
end
