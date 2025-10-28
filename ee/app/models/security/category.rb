# frozen_string_literal: true

module Security
  class Category < ::SecApplicationRecord
    self.table_name = 'security_categories'
    MAX_ATTRIBUTES = 50

    def self.declarative_policy_class
      'Security::AttributePolicy'
    end

    belongs_to :namespace, optional: false
    has_many :security_attributes, class_name: 'Security::Attribute', inverse_of: :security_category

    enum :editable_state, Enums::Security.editable_states

    enum :template_type, Enums::Security.categories_template_types

    before_validation :strip_whitespaces
    validates :name, presence: true
    validates :editable_state, presence: true
    validates :multiple_selection, inclusion: { in: [true, false] }
    validates :name, uniqueness: { scope: :namespace_id }, length: { maximum: 255 }
    validates :description, length: { maximum: 255 }, allow_blank: true
    validate :valid_namespace
    validate :attributes_limit

    scope :by_namespace, ->(namespace) { where(namespace: namespace) }
    scope :by_namespace_and_template_type, ->(namespace, template_type) {
      where(namespace_id: namespace.id, template_type: template_type)
    }
    scope :preload_attributes, -> { preload(:security_attributes) }

    def editable?
      editable_state != "locked"
    end

    private

    def valid_namespace
      return if namespace&.root? && namespace.group_namespace?

      errors.add(:namespace, 'must be a root group.')
    end

    def attributes_limit
      return unless security_attributes.size > MAX_ATTRIBUTES

      errors.add(:security_attributes, "cannot have more than #{MAX_ATTRIBUTES} attributes per category")
    end

    def strip_whitespaces
      self.name = name&.strip
      self.description = description&.strip
    end
  end
end
