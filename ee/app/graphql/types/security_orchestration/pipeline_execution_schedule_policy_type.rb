# frozen_string_literal: true

module Types
  module SecurityOrchestration
    # rubocop: disable Graphql/AuthorizeTypes -- authorization
    # this represents a hash, from the orchestration policy configuration
    # the authorization happens for that configuration
    class PipelineExecutionSchedulePolicyType < BaseObject
      graphql_name 'PipelineExecutionSchedulePolicy'
      description 'Represents the pipeline execution schedule policy'

      implements OrchestrationPolicyType

      field :source, Types::SecurityOrchestration::SecurityPolicySourceType,
        null: false,
        description: 'Source of the policy. Its fields depend on the source type.'

      field :policy_blob_file_path, GraphQL::Types::String,
        null: false,
        description: 'Path to the policy file in the project.'

      field :warnings, [String],
        null: false,
        description: 'Warnings associated with the policy.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
