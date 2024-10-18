# frozen_string_literal: true

module Types
  module Ci
    class RunnerCloudProvisioningType < BaseUnion
      graphql_name 'CiRunnerCloudProvisioning'
      description 'Information used in runner cloud provisioning.'

      include Gitlab::Graphql::Authorize::AuthorizeResource

      UnexpectedProviderType = Class.new(StandardError)

      possible_types ::Types::Ci::RunnerGoogleCloudProvisioningType, ::Types::Ci::RunnerGkeProvisioningType

      def self.resolve_type(object, _context)
        case object[:provider]
        when :google_cloud
          ::Types::Ci::RunnerGoogleCloudProvisioningType
        when :gke
          raise_resource_not_available_error! '`gke_runners_ff` feature flag is disabled.' \
            if Feature.disabled?(:gke_runners_ff, object[:container]) && object[:container].is_a?(::Project)

          raise_resource_not_available_error! '`gke_runners_ff_group` feature flag is disabled.' \
            if Feature.disabled?(:gke_runners_ff_group, object[:container]) && object[:container].is_a?(::Group)

          ::Types::Ci::RunnerGkeProvisioningType
        else
          raise UnexpectedProviderType, 'Unsupported CI runner cloud provider'
        end
      end
    end
  end
end
