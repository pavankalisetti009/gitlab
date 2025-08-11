# frozen_string_literal: true

module EE
  module Types
    module Projects
      module ProjectInterface
        extend ActiveSupport::Concern

        prepended do
          orphan_types ::Types::Projects::ProjectMinimalAccessType

          field :code_coverage_summary,
            ::Types::Ci::CodeCoverageSummaryType,
            null: true,
            description: 'Code coverage summary associated with the project.',
            resolver: ::Resolvers::Ci::CodeCoverageSummaryResolver

          field :component_usages, ::Types::Ci::Catalog::Resources::Components::UsageType.connection_type,
            null: true,
            description: 'Component(s) used by the project.',
            resolver: ::Resolvers::Ci::Catalog::Resources::Components::ProjectUsageResolver

          field :ai_xray_reports, ::Types::Ai::XrayReportType.connection_type,
            null: true,
            experiment: { milestone: '17.8' },
            description: 'X-ray reports of the project.',
            method: :xray_reports

          field :compliance_frameworks, ::Types::ComplianceManagement::ComplianceFrameworkType.connection_type,
            description: 'Compliance frameworks associated with the project.',
            null: true do
              argument :sort, ::Types::ComplianceManagement::ComplianceFrameworkSortEnum,
                required: false,
                description: 'Sort compliance frameworks by the criteria.'
            end

          field :security_dashboard_path, GraphQL::Types::String,
            description: "Path to project's security dashboard.",
            null: true

          field :repository_size_excess,
            GraphQL::Types::Float,
            null: true,
            description: 'Size of repository that exceeds the limit in bytes.'

          field :actual_repository_size_limit,
            GraphQL::Types::Float,
            null: true,
            description: 'Size limit for the repository in bytes.'

          field :only_allow_merge_if_all_status_checks_passed, GraphQL::Types::Boolean,
            null: true,
            description: 'Indicates that merges of merge requests should be blocked ' \
              'unless all status checks have passed.'

          field :duo_features_enabled, GraphQL::Types::Boolean,
            null: true,
            experiment: { milestone: '16.9' },
            description: 'Indicates whether GitLab Duo features are enabled for the project.'

          field :tracking_key, GraphQL::Types::String,
            null: true,
            description: 'Tracking key assigned to the project.',
            experiment: { milestone: '16.0' },
            authorize: :developer_access

          field :product_analytics_instrumentation_key, GraphQL::Types::String,
            null: true,
            description: 'Product Analytics instrumentation key assigned to the project.',
            experiment: { milestone: '16.0' },
            authorize: :developer_access

          field :merge_requests_disable_committers_approval, GraphQL::Types::Boolean,
            null: true,
            description: 'Indicates that committers of the given merge request cannot approve.'

          field :has_jira_vulnerability_issue_creation_enabled, GraphQL::Types::Boolean,
            null: true,
            method: :configured_to_create_issues_from_vulnerabilities?,
            description: 'Indicates whether Jira issue creation from vulnerabilities is enabled.'

          field :pre_receive_secret_detection_enabled, GraphQL::Types::Boolean,
            null: true,
            description: 'Indicates whether Secret Push Protection is on or not for the project.',
            method: :secret_push_protection_enabled,
            authorize: :read_secret_push_protection_info

          field :secret_push_protection_enabled, GraphQL::Types::Boolean,
            null: true,
            description: 'Indicates whether Secret Push Protection is on or not for the project.',
            authorize: :read_secret_push_protection_info

          field :container_scanning_for_registry_enabled, GraphQL::Types::Boolean,
            null: true,
            description: 'Indicates whether Container Scanning for Registry is enabled or not for the project. ' \
              'Returns `null` if unauthorized.',
            authorize: :read_security_configuration

          field :prevent_merge_without_jira_issue_enabled, GraphQL::Types::Boolean,
            null: true,
            method: :prevent_merge_without_jira_issue?,
            description: 'Indicates if an associated issue from Jira is required.'

          field :duo_agentic_chat_available, ::GraphQL::Types::Boolean,
            null: true,
            resolver: ::Resolvers::Ai::ProjectAgenticChatAccessResolver,
            experiment: { milestone: '18.1' },
            description: 'User access to Duo agentic Chat feature.'
        end

        class_methods do
          extend ::Gitlab::Utils::Override

          override :resolve_type
          def resolve_type(object, context)
            user = context[:current_user]

            return ::Types::ProjectType if user.can?(:read_project, object)
            return ::Types::Projects::ProjectMinimalAccessType if user.can?(:read_project_metadata, object)

            ::Types::ProjectType
          end
        end
      end
    end
  end
end
