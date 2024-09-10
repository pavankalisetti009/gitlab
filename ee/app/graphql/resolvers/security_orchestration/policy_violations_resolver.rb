# frozen_string_literal: true

module Resolvers
  module SecurityOrchestration
    class PolicyViolationsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type ::Types::SecurityOrchestration::PolicyViolationDetailsType, null: true

      authorizes_object!
      authorize :read_security_resource

      description 'Approval policy violations detected for the merge request.'

      def resolve(**_args)
        raise_resource_not_available_error! '`save_policy_violation_data` feature flag is disabled.' \
          if Feature.disabled?(:save_policy_violation_data, object.project)

        ::Security::ScanResultPolicies::PolicyViolationDetails.new(object)
      end
    end
  end
end
