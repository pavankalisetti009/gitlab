# frozen_string_literal: true

module Notifications
  class TargetedMessage < ApplicationRecord
    validates :target_type, presence: true
    validate :must_have_targeted_message_namespaces

    has_many :targeted_message_namespaces
    has_many :targeted_message_dismissals
    has_many :namespaces, through: :targeted_message_namespaces

    # these should map to wording/placement in the pajamas design doc: https://design.gitlab.com/
    enum :target_type, {
      banner_page_level: 0
    }

    private

    def must_have_targeted_message_namespaces
      return unless targeted_message_namespaces.empty?

      errors.add(:base,
        s_('TargetedMessages|Must have at least one targeted namespace'))
    end
  end
end
