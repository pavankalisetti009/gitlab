# frozen_string_literal: true

module Abuse
  class NewAbuseReportWorker
    include ApplicationWorker

    feature_category :instance_resiliency

    data_consistency :delayed
    urgency :low

    idempotent!

    def perform(abuse_report_id)
      AntiAbuse::NewAbuseReportWorker.new.perform(abuse_report_id)
    end
  end
end
