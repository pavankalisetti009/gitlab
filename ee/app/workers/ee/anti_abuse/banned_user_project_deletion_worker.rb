# frozen_string_literal: true

module EE
  module AntiAbuse
    module BannedUserProjectDeletionWorker
      private

      def verify_project!
        super

        abort!('project is paid') if paid?
      end

      def paid?
        # Part of a paid namespace
        return true if project.root_namespace.paid?

        # Has paid CI minutes
        ci_usage = project.root_namespace.ci_minutes_usage
        ci_usage.quota_enabled? && ci_usage.quota.any_purchased?
      end
    end
  end
end
