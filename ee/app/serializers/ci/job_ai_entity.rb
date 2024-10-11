# frozen_string_literal: true

module Ci
  class JobAiEntity < ::Ci::JobEntity
    LINES_LIMIT = 1000

    expose :job_log do |job, options|
      job.trace.raw(last_lines: LINES_LIMIT)&.last(options[:content_limit])
    end
  end
end
