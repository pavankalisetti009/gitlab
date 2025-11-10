# frozen_string_literal: true

module EE
  module Ci
    module DeployablePolicy
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        condition(:protected_environment) do
          @subject.persisted_environment.try(:protected_from?, user)
        end

        rule { reporter_has_access_to_protected_environment }.policy do
          enable :cancel_build
          enable(*all_job_update_abilities)
        end

        rule { ~reporter_has_access_to_protected_environment & protected_environment }.policy do
          prevent(*all_job_write_abilities)
        end
      end

      private

      override :reporter_has_access_to_protected_environment?
      def reporter_has_access_to_protected_environment?
        subject.persisted_environment.try(:protected_by?, user) && can?(:reporter_access, subject.project)
      end
    end
  end
end
