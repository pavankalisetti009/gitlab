# frozen_string_literal: true

module EE
  module PersonalAccessTokenPolicy # rubocop:disable Gitlab/BoundedContexts -- Existing policy with EE extension.
    extend ActiveSupport::Concern

    prepended do
      condition(:is_enterprise_user_manager) { user && subject.user.managed_by_user?(user) }

      rule { is_enterprise_user_manager }.policy do
        enable :revoke_token
      end
    end
  end
end
