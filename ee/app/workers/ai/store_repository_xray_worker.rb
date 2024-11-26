# frozen_string_literal: true

# TODO: Remove this Class in 17.8
# Reference: https://gitlab.com/gitlab-org/gitlab/-/issues/505676
module Ai
  class StoreRepositoryXrayWorker
    include ApplicationWorker

    data_consistency :sticky

    idempotent!

    sidekiq_options retry: true

    feature_category :code_suggestions

    # This method is a no-op to ensure that
    # we safely remove the
    # StoreRepositoryXrayWorker class
    # following a multi-step approach
    # Reference: https://docs.gitlab.com/ee/development/sidekiq/compatibility_across_updates.html#removing-worker-classes
    def perform(pipeline_id); end
  end
end
