# frozen_string_literal: true

module Security
  class PurgeScansService
    include Gitlab::Utils::StrongMemoize

    MAX_STALE_SCANS_SIZE = 200_000
    SCAN_BATCH_SIZE = 100

    # To optimise purging against rereading dead tuples on progressive purge executions
    # we cache the last purged tuple so that the next job can start where the prior finished.
    # The TTL for this is in hours so that we'll start from the beginning the following weekend.
    LAST_PURGED_SCAN_TUPLE = 'Security::PurgeScansService::LAST_PURGED_SCAN_TUPLE'
    LAST_PURGED_SCAN_TUPLE_TTL = 24.hours.to_i

    class << self
      def purge_stale_records
        execute(Security::Scan.stale.ordered_by_created_at_and_id, last_purged_tuple)
      end

      def purge_by_build_ids(build_ids)
        Security::Scan.by_build_ids(build_ids).then { |relation| execute(relation) }
      end

      def execute(security_scans, cursor = {})
        new(security_scans, cursor).execute
      end

      private

      # returns {} if no last tuple was set
      # we exclude `ex` because it's the expiry timer for the tuple used by redis
      def last_purged_tuple
        Gitlab::Redis::SharedState.with do |redis|
          redis.hgetall(LAST_PURGED_SCAN_TUPLE)
        end.except('ex')
      end
    end

    def initialize(security_scans, cursor = {})
      @iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: security_scans, cursor: cursor)
      @updated_count = 0
    end

    def execute
      iterator.each_batch(of: SCAN_BATCH_SIZE) do |batch|
        last_updated_record = batch.last

        @updated_count += purge(batch)

        store_last_purged_tuple(last_updated_record.created_at, last_updated_record.id) if last_updated_record

        break if @updated_count >= MAX_STALE_SCANS_SIZE
      end
    end

    private

    attr_reader :iterator

    def purge(scan_batch)
      scan_batch.update_all(status: :purged)
    end

    # Normal to string methods for dates don't include the split seconds that rails usually includes in queries.
    # Without them, it's possible to still match on the last processed record instead of the one after it.
    def store_last_purged_tuple(created_at, id)
      Gitlab::Redis::SharedState.with do |redis|
        redis.hset(LAST_PURGED_SCAN_TUPLE, {
          "created_at" => created_at.strftime("%Y-%m-%d %H:%M:%S.%6N"),
          "id" => id
        }, ex: LAST_PURGED_SCAN_TUPLE_TTL)
      end
    end
  end
end
