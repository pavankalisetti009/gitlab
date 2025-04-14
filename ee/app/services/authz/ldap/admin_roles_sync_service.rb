# frozen_string_literal: true

module Authz
  module Ldap
    class AdminRolesSyncService
      def self.enqueue_sync
        ::Authz::LdapAdminRoleWorker.perform_async
      end
    end
  end
end
