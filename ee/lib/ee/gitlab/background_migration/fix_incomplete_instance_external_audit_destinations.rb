# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module FixIncompleteInstanceExternalAuditDestinations
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        def perform
          # No-op: This module has been replaced by FixIncompleteInstanceExternalAuditDestinationsV2
          # due to an issue with nil verification tokens: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/186866
        end
      end
    end
  end
end
