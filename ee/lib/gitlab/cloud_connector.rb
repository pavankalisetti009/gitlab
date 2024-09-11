# frozen_string_literal: true

module Gitlab
  module CloudConnector
    extend self

    GITLAB_REALM_SAAS = 'saas'
    GITLAB_REALM_SELF_MANAGED = 'self-managed'

    def gitlab_realm
      Gitlab.org_or_com? ? GITLAB_REALM_SAAS : GITLAB_REALM_SELF_MANAGED # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- Will be addressed in https://gitlab.com/gitlab-org/gitlab/-/issues/437725
    end

    def headers(user)
      {
        'X-Gitlab-Host-Name' => Gitlab.config.gitlab.host,
        'X-Gitlab-Instance-Id' => Gitlab::GlobalAnonymousId.instance_id,
        'X-Gitlab-Realm' => Gitlab::CloudConnector.gitlab_realm,
        'X-Gitlab-Version' => Gitlab.version_info.to_s
      }.tap do |result|
        result['X-Gitlab-Global-User-Id'] = Gitlab::GlobalAnonymousId.user_id(user) if user
      end
    end

    def ai_headers(user)
      headers(user).merge(
        'X-Gitlab-Duo-Seat-Count' => GitlabSubscriptions::AddOnPurchase.maximum_duo_seat_count.to_s
      )
    end
  end
end
