# frozen_string_literal: true

module EE
  module AwardEmoji # rubocop:disable Gitlab/BoundedContexts -- Overrides an existing class. If nothing else is added it can be deleted after epic to work items migration.
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include FromUnion

      validate :uniqueness_between_epic_and_work_item, on: :create, unless: -> { ghost_user? || importing? }

      def uniqueness_between_epic_and_work_item
        # Do not check for feature flag because
        # toggling it on/off could create duplicated records.
        return unless awardable.try(:sync_object)

        sync_emoji =
          awardable.sync_object.own_award_emoji.awarded_by(user).find_by_name(name)

        errors.add(:awardable, _('Emoji already assigned')) if sync_emoji.present?
      end
    end

    private

    override :ensure_sharding_key
    def ensure_sharding_key
      return if [namespace, organization].any?(&:present?)

      case awardable
      when Epic
        self.namespace_id = awardable.group_id
        self.organization_id = nil
      else
        super
      end
    end
  end
end
