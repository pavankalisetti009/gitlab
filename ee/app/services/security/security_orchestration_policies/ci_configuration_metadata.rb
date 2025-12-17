# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module CiConfigurationMetadata
      def merge_configuration_metadata!(config, metadata)
        return config if metadata.nil?

        # Store the policy project ID and SHA as a metadata in the job configuration, removed then in processor
        config[:_metadata] = metadata
      end
    end
  end
end
