# frozen_string_literal: true

module EE
  module Dashboard
    module ProjectsController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        before_action :check_adjourned_deletion_listing_availability, only: [:removed]
        before_action do
          push_licensed_feature(:adjourned_deletion_for_projects_and_groups)
        end

        urgency :low, [:removed]
      end

      def removed
        # Move redirect to `ee/config/routes/dashboard.rb` in https://gitlab.com/gitlab-org/gitlab/-/issues/523698
        return redirect_to inactive_dashboard_projects_path
      end

      private

      def check_adjourned_deletion_listing_availability
        return render_404 unless can?(current_user, :list_removable_projects)
      end
    end
  end
end
