# frozen_string_literal: true

module EE
  module Organizations
    module GroupsFinder
      extend ::Gitlab::Utils::Override

      private

      override :filter_groups
      def filter_groups(groups)
        groups = super(groups)
        by_saml_sso_session(groups)
      end

      def by_saml_sso_session(groups)
        return groups if current_user.nil? || current_user.can_read_all_resources?
        return groups unless filter_expired_saml_session_groups?

        groups.by_not_in_root_id(current_user.expired_sso_session_saml_providers.select(:group_id))
      end

      def filter_expired_saml_session_groups?
        params.fetch(:filter_expired_saml_session_groups, true)
      end
    end
  end
end
