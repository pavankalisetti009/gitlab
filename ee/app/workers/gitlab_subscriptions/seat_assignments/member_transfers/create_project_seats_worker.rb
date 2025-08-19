# frozen_string_literal: true

module GitlabSubscriptions
  module SeatAssignments
    module MemberTransfers
      class CreateProjectSeatsWorker < BaseCreateSeatsWorker
        include ApplicationWorker

        feature_category :seat_cost_management
        data_consistency :delayed
        urgency :low

        defer_on_database_health_signal :gitlab_main,
          [:subscription_seat_assignments, :members], 10.minutes

        idempotent!

        private

        def find_source_by_id(project_id)
          Project.find_by_id(project_id)
        end

        def collect_user_ids(project)
          project.project_members
        end
      end
    end
  end
end
