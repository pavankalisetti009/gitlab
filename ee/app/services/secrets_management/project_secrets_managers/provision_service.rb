# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class ProvisionService < BaseService
      include SecretsManagerClientHelpers
      include Helpers::ExclusiveLeaseHelper

      SECRETS_ENGINE_TYPE = 'kv-v2'
      OWNER_PRINCIPAL_ID = Gitlab::Access.sym_options_with_owner[:owner]
      OWNER_PRINCIPAL_TYPE = "Role"
      OWNER_PERMISSIONS = %w[create update delete read list scan].freeze

      def initialize(secrets_manager, current_user)
        super(secrets_manager.project, current_user)

        @secrets_manager = secrets_manager
      end

      def execute
        with_exclusive_lease_for(project, lease_timeout: 120.seconds.to_i) do
          execute_provision
        end
      end

      private

      def execute_provision
        update_gitlab_rails_jwt_role
        enable_namespaces
        enable_secret_store
        enable_auth
        create_owner_policy

        activate_secrets_manager
        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      end

      def enable_namespaces
        # This namespaces may already exist if there's another project in
        # this namespace.
        global_secrets_manager_client.enable_namespace(secrets_manager.namespace_path)

        # This namespace should not exist if we're being enabled, but OpenBao
        # does not differentiate between first creation and subsequent
        # namespace creation.
        namespace_secrets_manager_client.enable_namespace(secrets_manager.project_path)
      end

      def enable_secret_store
        project_secrets_manager_client.enable_secrets_engine(secrets_manager.ci_secrets_mount_path, SECRETS_ENGINE_TYPE)
      rescue SecretsManagerClient::ApiError => e
        raise e unless e.message.include?('path is already in use')

        # This scenario may happen in a rare event that the API call to enable the engine succeeds
        # but the actual column update failed due to unexpected reasons (e.g. network hiccups) that
        # will also fail the job. So on job retry, we want to ignore this message and continue
        # with the column update.
      end

      def enable_auth
        # configure pipeline auth
        pipeline_jwt_exists = enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
        configure_jwt(secrets_manager.ci_auth_mount) unless pipeline_jwt_exists
        configure_pipeline_auth

        # configure user auth
        user_jwt_exists = enable_auth_engine(secrets_manager.user_auth_mount, secrets_manager.user_auth_type)
        configure_jwt(secrets_manager.user_auth_mount) unless user_jwt_exists
        configure_user_auth_cel
      end

      def enable_auth_engine(auth_mount, auth_type)
        project_secrets_manager_client.enable_auth_engine(
          auth_mount,
          auth_type,
          allow_existing: true
        )
      end

      def configure_jwt(auth_mount)
        # We use the OIDC discovery URL to configure this JWT mount so that
        # OpenBao can automatically update its copy of the issuer. However,
        # if we're running under a spec, we'll use a hard-coded JKS instead
        # so that we don't need a full Puma instance running.

        issuer_base_url = ProjectSecretsManager.jwt_issuer
        issuer_key = Gitlab::CurrentSettings.ci_jwt_signing_key
        project_secrets_manager_client.configure_jwt(auth_mount, issuer_base_url, issuer_key)
      end

      def configure_user_auth_cel
        project_secrets_manager_client.update_jwt_cel_role(
          secrets_manager.user_auth_mount,
          secrets_manager.user_auth_role,
          cel_program: secrets_manager.user_auth_cel_program(secrets_manager.project.id),
          bound_audiences: bound_audiences
        )
      end

      def configure_pipeline_auth
        project_secrets_manager_client.update_jwt_role(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role,
          role_type: 'jwt',
          token_policies_template_claims: true,
          token_policies: secrets_manager.ci_auth_literal_policies,
          bound_claims: {
            project_id: secrets_manager.project.id.to_s,
            secrets_manager_scope: 'pipeline'
          },
          claim_mappings: {
            correlation_id: 'correlation_id',
            user_id: 'user_id',
            project_id: 'project_id',
            namespace_id: 'namespace_id'
          },
          bound_audiences: bound_audiences,
          user_claim: "project_id",
          token_type: "service"
        )
      end

      def create_owner_policy
        policy_name = secrets_manager.generate_policy_name(
          principal_type: OWNER_PRINCIPAL_TYPE,
          principal_id: OWNER_PRINCIPAL_ID
        )

        policy = SecretsManagement::AclPolicy.new(policy_name)
        update_policy_paths(policy, OWNER_PERMISSIONS)
        project_secrets_manager_client.set_policy(policy)
      rescue SecretsManagement::SecretsManagerClient::ApiError => e
        Gitlab::AppLogger.error("Failed to create owner policy for project #{secrets_manager.project.id}: #{e.message}")
        raise e
      end

      def update_policy_paths(policy, permissions)
        data_path = secrets_manager.ci_full_path('*')
        metadata_path = secrets_manager.ci_metadata_full_path('*')
        detailed_metadata_path = secrets_manager.detailed_metadata_path('*')

        # Add new capabilities
        permissions.each do |permission|
          policy.add_capability(data_path, permission) if permission != 'read'
          policy.add_capability(metadata_path, permission)
        end
        policy.add_capability(detailed_metadata_path, 'list')
      end

      def update_gitlab_rails_jwt_role
        # A new test environment is created everytime we run rspec which has the server url
        # as bound_audience based on openbao_test_setup file.
        # I have added specs to make sure the bound_audiences include the expected server_url in provision_service_spec.
        return if Rails.env.test?

        begin
          global_secrets_manager_client.read_jwt_role('gitlab_rails_jwt', 'app')
        rescue SecretsManagement::SecretsManagerClient::ConnectionError
          # This is a temporary code to update the JWT bound_audiences in Staging and Production.
          jwt = SecretsManagement::SecretsManagerJwt.new(
            current_user: current_user,
            project: project,
            old_aud: 'openbao'
          ).encoded

          client = SecretsManagement::SecretsManagerClient.new(jwt: jwt)

          client.update_gitlab_rails_jwt_role(openbao_url: SecretsManagement::ProjectSecretsManager.server_url)
        end
      end

      def activate_secrets_manager
        return if secrets_manager.active?

        secrets_manager.activate!
      end

      def bound_audiences
        [SecretsManagement::ProjectSecretsManager.server_url]
      end

      attr_reader :secrets_manager
    end
  end
end
