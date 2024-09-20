# frozen_string_literal: true

module LoopWithRuntimeLimit # rubocop:disable Gitlab/BoundedContexts -- it's a general purpose module
  private

  def loop_with_runtime_limit(limit)
    status = :processed
    total_inserted_rows = 0

    runtime_limiter = Gitlab::Metrics::RuntimeLimiter.new(limit)

    loop do
      if runtime_limiter.over_time?
        status = :over_time
        break
      end

      inserted_rows = yield
      total_inserted_rows += inserted_rows

      break if inserted_rows == 0
    end

    [status, total_inserted_rows]
  end
end
