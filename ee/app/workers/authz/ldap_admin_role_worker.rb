# frozen_string_literal: true

module Authz
  class LdapAdminRoleWorker
    include ApplicationWorker

    idempotent!

    worker_has_external_dependencies!

    data_consistency :sticky

    feature_category :permissions
    def perform(provider = nil)
      # TO BE IMPLEMENTED: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/187526
    end
  end
end
