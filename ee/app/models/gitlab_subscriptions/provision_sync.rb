# frozen_string_literal: true

module GitlabSubscriptions
  class ProvisionSync < ApplicationRecord
    belongs_to :namespace, optional: false

    validates :attrs, :sync_requested_at, presence: true
    validates :namespace_id, uniqueness: { scope: :sync_requested_at }
  end
end
