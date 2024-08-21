# frozen_string_literal: true

module AppSec
  module Dast
    module Sites
      class FindOrCreateService < BaseService
        PermissionsError = Class.new(StandardError)

        def execute!(url:)
          raise PermissionsError, 'Insufficient permissions' unless allowed?

          Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification.temporary_ignore_tables_in_transaction(
            %w[dast_sites projects], url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/478563'
          ) do
            DastSite.find_or_create_by!(project: project, url: url) # rubocop:disable CodeReuse/ActiveRecord
          end
        end

        private

        def allowed?
          Ability.allowed?(current_user, :create_on_demand_dast_scan, project)
        end
      end
    end
  end
end
