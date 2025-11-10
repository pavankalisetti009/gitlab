# frozen_string_literal: true

module Ai
  class FlowTrigger < ApplicationRecord
    self.table_name = :ai_flow_triggers

    # Values match FLOW_TRIGGER_TYPES in ee/app/assets/javascripts/ai/duo_agents_platform/constants.js:
    # https://gitlab.com/gitlab-org/gitlab/-/blob/9271ef8def87566d81f1e7047d8495c99b18ede7/ee/app/assets/javascripts/ai/duo_agents_platform/constants.js#L50
    EVENT_TYPES = {
      mention: 0,
      assign: 1,
      assign_reviewer: 2
    }.freeze

    belongs_to :project, optional: false
    belongs_to :user
    belongs_to :ai_catalog_item_consumer, class_name: 'Ai::Catalog::ItemConsumer'

    scope :triggered_on, ->(event_type) { where("event_types @> ('{?}')", EVENT_TYPES[event_type]) }
    scope :by_users, ->(users) { where(user: users) }
    scope :by_item_consumer_ids, ->(item_ids) { where(ai_catalog_item_consumer_id: item_ids) }

    validates :project, presence: true
    validates :user, presence: true
    validates :event_types, presence: true

    validates :description, length: { maximum: 255 }, presence: true
    validates :config_path, length: { maximum: 255 }, presence: true, unless: -> { ai_catalog_item_consumer.present? }

    validates :ai_catalog_item_consumer, presence: true, unless: :config_path?

    validate :event_types_are_valid
    validate :user_is_service_account, if: :user
    validate :exactly_one_config_source
    validate :catalog_item_valid, if: -> { ai_catalog_item_consumer.present? }

    scope :with_ids, ->(ids) { where(id: ids) }

    private

    def event_types_are_valid
      return if event_types.blank?

      invalid_types = event_types - EVENT_TYPES.values
      return if invalid_types.empty?

      errors.add(:event_types, "contains invalid event types: #{invalid_types.join(', ')}")
    end

    def user_is_service_account
      return if user.service_account?

      errors.add(:user, 'user must be a service account')
    end

    def exactly_one_config_source
      return if [config_path.presence, ai_catalog_item_consumer].compact.one?

      errors.add(:base, 'must have only one config_path or ai_catalog_item_consumer')
    end

    def catalog_item_valid
      if ai_catalog_item_consumer.project != project
        errors.add(:base, 'ai_catalog_item_consumer project does not match project')
      end

      return if ai_catalog_item_consumer.item.flow? || ai_catalog_item_consumer.item.third_party_flow?

      errors.add(:base, 'ai_catalog_item_consumer is not a flow')
    end
  end
end
