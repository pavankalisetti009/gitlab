# frozen_string_literal: true

module EE
  module Ci
    module RunnerProjectPolicy
      extend ActiveSupport::Concern

      prepended do
        condition(:custom_role_enables_admin_runners) do
          ::Authz::CustomAbility.allowed?(@user, :admin_runners, @subject.runner)
        end

        rule { custom_role_enables_admin_runners }.policy do
          enable :unassign_runner
        end
      end
    end
  end
end
