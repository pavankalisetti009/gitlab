# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module StandardContext
        extend ::Gitlab::Utils::Override

        override :gitlab_team_member?
        def gitlab_team_member?(user_id)
          return unless ::Gitlab.com?
          return unless user_id

          ::Gitlab::Com.gitlab_com_group_member?(user_id)
        end

        override :realm
        def realm
          ::CloudConnector.gitlab_realm
        end

        override :instance_id
        def instance_id
          ::Gitlab::GlobalAnonymousId.instance_id
        end

        override :tracked_user_id
        def tracked_user_id
          return unless user.is_a? User

          ::Gitlab.com? ? user.id : ::Gitlab::CryptoHelper.sha256(user.id)
        end
      end
    end
  end
end
