# frozen_string_literal: true

module Authz
  class LdapAdminRoleWorker
    include ApplicationWorker

    idempotent!

    worker_has_external_dependencies!

    data_consistency :sticky

    feature_category :permissions

    def perform
      ldap_sync_class.execute_all_providers
    end

    def ldap_sync_class
      ::Gitlab::Authz::Ldap::Sync::AdminRole
    end
  end
end
