# frozen_string_literal: true

module Authz
  module Ldap
    class AdminRolesSyncService
      def self.enqueue_sync
        ::Authz::LdapAdminRoleLink.not_running.mark_syncs_as_queued

        ::Authz::LdapAdminRoleWorker.perform_async
      end
    end
  end
end
