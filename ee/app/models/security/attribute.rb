# frozen_string_literal: true

module Security
  class Attribute < ::SecApplicationRecord
    include StripAttribute

    self.table_name = 'security_attributes'

    belongs_to :namespace, optional: false
    belongs_to :security_category, class_name: 'Security::Category', optional: false
    has_many :projects, through: :project_to_security_attributes
    has_many :project_to_security_attributes, class_name: 'Security::ProjectToSecurityAttribute',
      foreign_key: :security_attribute_id, inverse_of: :security_attribute

    strip_attributes! :name, :description

    enum :editable_state, Enums::Security.editable_states
    enum :template_type, Enums::Security.attributes_template_types
    attribute :color, ::Gitlab::Database::Type::Color.new

    validates :name, presence: true, length: { maximum: 255 }, uniqueness: { scope: :security_category_id }
    validates :description, presence: true, length: { maximum: 255 }
    validates :editable_state, presence: true
    validates :color, color: true, presence: true

    scope :include_category, -> { includes(:security_category) }
    scope :by_category, ->(category) { where(security_category: category) }
    scope :pluck_id, -> { limit(MAX_PLUCK).pluck(:id) }

    def editable?
      !locked?
    end
  end
end
