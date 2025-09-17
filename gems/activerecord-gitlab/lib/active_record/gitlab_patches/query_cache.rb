# frozen_string_literal: true

# Fixes https://github.com/rails/rails/issues/55689 in Rails 7.2+
# See https://github.com/rails/rails/pull/55696
return if ActiveRecord.version < Gem::Version.new('7.2')
raise 'Update this patch when upgrading Rails.' if ActiveRecord.version >= Gem::Version.new("7.3")

# rubocop:disable Layout/LineLength -- better to match formatting from upstream code
# rubocop:disable Gitlab/ModuleWithInstanceVariables -- needed for patch
module ActiveRecord
  module ConnectionAdapters
    module QueryCache
      module ConnectionPoolConfiguration
        def checkout_and_verify(...) # rubocop:disable Lint/UselessMethodDefinition -- clears the existing override
          super
          # Instead of setting the cache store on checkout, we lookup the cache store
          # from the pool so that we can fetch the correct cache store for the execution context
        end
      end

      def query_cache
        @query_cache || pool.try(:query_cache)
      end

      def query_cache_enabled
        query_cache&.enabled?
      end

      def select_all(arel, name = nil, binds = [], preparable: nil, async: false, allow_retry: false)
        arel = arel_from_relation(arel)

        # If arel is locked this is a SELECT ... FOR UPDATE or somesuch.
        # Such queries should not be cached.
        # @query_cache&.enabled? was changed to query_cache_enabled
        if query_cache_enabled && !(arel.respond_to?(:locked) && arel.locked)
          sql, binds, preparable, allow_retry = to_sql_and_binds(arel, binds, preparable, allow_retry)

          if async
            result = lookup_sql_cache(sql, name, binds) || super(sql, name, binds, preparable: preparable, async: async, allow_retry: allow_retry)
            FutureResult.wrap(result)
          else
            cache_sql(sql, name, binds) { super(sql, name, binds, preparable: preparable, async: async, allow_retry: allow_retry) }
          end
        else
          super
        end
      end

      private

      def lookup_sql_cache(sql, name, binds)
        key = binds.empty? ? sql : [sql, binds]

        result = nil
        @lock.synchronize do
          # @query_cache was changed to query_cache
          result = query_cache[key]
        end

        if result
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            cache_notification_info(sql, name, binds)
          )
        end

        result
      end

      def cache_sql(sql, name, binds)
        key = binds.empty? ? sql : [sql, binds]
        result = nil
        hit = true

        @lock.synchronize do
          # @query_cache was changed to query_cache
          result = query_cache.compute_if_absent(key) do
            hit = false
            yield
          end
        end

        if hit
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            cache_notification_info(sql, name, binds)
          )
        end

        result.dup
      end
    end
  end
end
# rubocop:enable Layout/LineLength
# rubocop:enable Gitlab/ModuleWithInstanceVariables
