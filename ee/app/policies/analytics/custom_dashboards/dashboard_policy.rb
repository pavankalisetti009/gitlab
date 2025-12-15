# frozen_string_literal: true

module Analytics
  module CustomDashboards
    class DashboardPolicy < BasePolicy
      delegate { @subject.organization }
    end
  end
end
