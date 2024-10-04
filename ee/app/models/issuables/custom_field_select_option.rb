# frozen_string_literal: true

module Issuables
  class CustomFieldSelectOption < ApplicationRecord
    belongs_to :namespace
    belongs_to :custom_field

    validates :namespace, :custom_field, presence: true
    validates :value, presence: true, length: { maximum: 255 },
      uniqueness: { scope: [:custom_field_id], case_sensitive: false }
  end
end
