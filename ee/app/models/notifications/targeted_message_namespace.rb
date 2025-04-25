# frozen_string_literal: true

module Notifications
  class TargetedMessageNamespace < ApplicationRecord
    belongs_to :targeted_message, optional: false
    belongs_to :namespace, optional: false

    validates_uniqueness_of :namespace_id, scope: :targeted_message_id

    scope :by_namespace, ->(namespace) { where(namespace: namespace) }
  end
end
