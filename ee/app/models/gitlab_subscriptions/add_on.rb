# frozen_string_literal: true

module GitlabSubscriptions
  class AddOn < ApplicationRecord
    has_many :add_on_purchases, foreign_key: :subscription_add_on_id, inverse_of: :add_on

    validates :name,
      presence: true,
      uniqueness: true
    validates :description,
      presence: true,
      length: { maximum: 512 }

    enum name: {
      code_suggestions: 1,
      product_analytics: 2,
      duo_enterprise: 3,
      duo_amazon_q: 4,
      duo_nano: 5
    }

    DUO_ADD_ONS = %i[code_suggestions duo_enterprise duo_amazon_q duo_nano].freeze

    DUO_ADD_ONS_WITH_SEAT_ASSIGNMENTS = %w[code_suggestions duo_enterprise].freeze

    scope :duo_add_ons, -> { where(name: DUO_ADD_ONS) }

    # Note: If a new enum is added, make sure to update this method to reflect that as well.
    def self.descriptions
      {
        code_suggestions: 'Add-on for GitLab Duo Pro.',
        product_analytics: 'Add-on for product analytics. Quantity suggests multiple of available stored event.',
        duo_enterprise: 'Add-on for GitLab Duo Enterprise.',
        duo_amazon_q: 'Add-on for GitLab Duo with Amazon Q.',
        duo_nano: 'Add-on for Gitlab Duo Nano.'
      }
    end

    def self.find_or_create_by_name(add_on_name, namespace = nil)
      check_add_on_availability!(add_on_name, namespace)

      create_with(description: GitlabSubscriptions::AddOn.descriptions[add_on_name.to_sym])
        .find_or_create_by!(name: add_on_name)
    end

    def self.check_add_on_availability!(add_on_name, namespace)
      raise ::ArgumentError if
        add_on_name.eql?("product_analytics") &&
          ::Feature.disabled?(:product_analytics_billing, namespace, type: :development)
    end

    def self.seat_assignable?(add_on_name)
      DUO_ADD_ONS_WITH_SEAT_ASSIGNMENTS.include?(add_on_name)
    end
  end
end
