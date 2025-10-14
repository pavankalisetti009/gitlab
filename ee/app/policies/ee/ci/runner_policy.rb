# frozen_string_literal: true

module EE
  module Ci
    module RunnerPolicy
      extend ActiveSupport::Concern

      prepended do
        rule { auditor }.policy do
          enable :read_runner
          enable :read_builds
        end

        condition(:custom_role_enables_read_runners, score: 32) do
          ::Authz::CustomAbility.allowed?(@user, :read_runners, @subject)
        end

        rule { custom_role_enables_read_runners }.enable(:read_runner)

        condition(:admin_custom_role_enables_read_admin_cicd, scope: :user) do
          ::Authz::CustomAbility.allowed?(@user, :read_admin_cicd)
        end

        rule { admin_custom_role_enables_read_admin_cicd }.policy do
          enable :read_runner
          enable :read_builds
        end
      end
    end
  end
end
