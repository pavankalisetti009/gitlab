# frozen_string_literal: true

# rubocop:disable Gitlab/EeOnlyClass -- This is only used in GitLab dedicated that comes under ultimate tier only.
module EE
  module Types
    module Ci
      module Minutes
        class DedicatedRunnerFiltersType < ::Types::BaseObject
          graphql_name 'CiDedicatedHostedRunnerFilters'
          description 'Filter options available for GitLab Dedicated runner usage data.'

          include ::Gitlab::Graphql::Authorize::AuthorizeResource

          field :runners, ::Types::Ci::RunnerType.connection_type, null: true,
            description: 'List of unique runners with usage data.'
          field :years, [GraphQL::Types::Int], null: true,
            description: 'List of years with available usage data.'

          def runners
            raise_resource_not_available_error! unless allowed?

            runner_ids = ::Ci::Minutes::GitlabHostedRunnerMonthlyUsage.distinct_runner_ids

            ::Ci::RunnersFinder
              .new(current_user: context[:current_user], params: { id_in: runner_ids })
              .execute
          end

          def years
            raise_resource_not_available_error! unless allowed?

            ::Ci::Minutes::GitlabHostedRunnerMonthlyUsage.distinct_years
          end

          def allowed?
            current_user.can?(:read_dedicated_hosted_runner_usage)
          end
        end
      end
    end
  end
end
# rubocop:enable Gitlab/EeOnlyClass
