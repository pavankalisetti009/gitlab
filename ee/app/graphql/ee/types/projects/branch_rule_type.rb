# frozen_string_literal: true

module EE
  module Types
    module Projects
      module BranchRuleType
        extend ActiveSupport::Concern

        prepended do
          field :approval_rules,
            type: ::Types::BranchRules::ApprovalProjectRuleType.connection_type,
            method: :approval_project_rules,
            null: true,
            description: 'Merge request approval rules configured for this branch rule.'

          field :external_status_checks,
            type: ::Types::BranchRules::ExternalStatusCheckType.connection_type,
            null: true,
            description: 'External status checks configured for this branch rule.'

          field :squash_option,
            type: ::Types::Projects::BranchRules::SquashOptionType,
            null: true,
            description: 'The default behavior for squashing in merge requests. ' \
              'Returns null if `branch_rule_squash_settings` feature flag is disabled.',
            experiment: { milestone: '17.7' }

          def squash_option
            return unless ::Feature.enabled?(:branch_rule_squash_settings, object.project)
            return unless object.project.licensed_feature_available?(:branch_rule_squash_options)

            object.squash_option
          end
        end
      end
    end
  end
end
