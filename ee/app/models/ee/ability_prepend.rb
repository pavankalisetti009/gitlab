# frozen_string_literal: true

module EE
  module AbilityPrepend
    extend ActiveSupport::Concern

    class_methods do
      def users_that_can_read_project(users, project)
        ActiveRecord::Associations::Preloader.new(records: users, associations: :namespace_bans).call
        super
      end

      def composite_id_service_account_outside_origin_group?(user, subject)
        return false unless ::Gitlab::Saas.feature_available?(:service_accounts_invite_restrictions)
        return false unless ::Feature.enabled?(:restrict_invites_for_comp_id_service_accounts, :instance)

        return false unless user&.composite_identity_enforced? # Allow non-composite-id SAs.
        return false unless user.provisioned_by_group_id # Allow instance-level SAs
        return false unless subject.is_a?(Group)
        return false if subject.self_and_ancestor_ids.include?(user.provisioned_by_group_id)

        true
      end
    end
  end
end
