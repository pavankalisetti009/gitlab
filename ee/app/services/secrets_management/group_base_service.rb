# frozen_string_literal: true

module SecretsManagement
  class GroupBaseService < BaseService
    include Gitlab::Utils::StrongMemoize
    include Helpers::ExclusiveLeaseHelper
    include ErrorResponseHelper

    def initialize(group, user = nil)
      @group = group
      @current_user = user
    end

    private

    attr_reader :group

    def global_secrets_manager_client
      jwt = GroupSecretsManagerJwt.new(
        current_user: current_user,
        group: group
      ).encoded

      SecretsManagerClient.new(jwt: jwt)
    end
    strong_memoize_attr :global_secrets_manager_client

    def namespace_secrets_manager_client
      global_secrets_manager_client.with_namespace(group.secrets_manager.root_namespace_path)
    end
    strong_memoize_attr :namespace_secrets_manager_client

    def group_secrets_manager_client
      global_secrets_manager_client.with_namespace(group.secrets_manager.full_group_namespace_path)
    end
    strong_memoize_attr :group_secrets_manager_client
  end
end
