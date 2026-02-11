# frozen_string_literal: true

module SecretsManagement
  module GroupSecrets
    class UpdateService < GroupBaseService
      include Secrets::UpdateServiceHelpers
      include GroupSecrets::SecretRefresherHelper

      def execute(
        name:,
        metadata_cas:,
        value: nil,
        description: nil,
        environment: nil,
        protected: nil
      )
        with_exclusive_lease_for(group) do
          read_result = read_secret(name)
          break read_result unless read_result.success?

          group_secret = read_result.payload[:secret]
          group_secret.description = description unless description.nil?
          group_secret.environment = environment unless environment.nil?
          group_secret.protected = protected unless protected.nil?

          execute_secret_update(
            secret: group_secret,
            custom_metadata: {
              environment: group_secret.environment,
              protected: group_secret.protected.to_s
            },
            value: value,
            metadata_cas: metadata_cas
          )
        end
      end

      private

      delegate :secrets_manager, to: :group

      def read_secret(name)
        GroupSecrets::ReadMetadataService.new(group, current_user).execute(name)
      end

      def refresh_policies_before_update(group_secret)
        # Refresh policies BEFORE updating metadata so that the old metadata is still in OpenBao
        # This allows the refresher to correctly count secrets for the old policy
        refresh_secret_ci_policies(group_secret)
      end
    end
  end
end
