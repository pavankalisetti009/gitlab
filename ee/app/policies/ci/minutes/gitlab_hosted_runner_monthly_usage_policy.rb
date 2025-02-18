# frozen_string_literal: true

module Ci
  module Minutes
    class GitlabHostedRunnerMonthlyUsagePolicy < BasePolicy
      desc "User is an admin on GitLab Dedicated"

      condition :gitlab_dedicated do
        Gitlab::CurrentSettings.gitlab_dedicated_instance?
      end

      rule { gitlab_dedicated & admin }.policy do
        enable :read_dedicated_hosted_runner_usage
      end
    end
  end
end
