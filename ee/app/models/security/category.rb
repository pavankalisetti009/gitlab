# frozen_string_literal: true

module Security
  class Category < ::SecApplicationRecord
    self.table_name = 'security_categories'
    MAX_ATTRIBUTES = 50

    belongs_to :namespace, optional: false
    has_many :security_attributes, class_name: 'Security::Attribute', inverse_of: :security_category

    enum :editable_state, Enums::Security.editable_states

    enum :template_type, {
      business_impact: 0,
      business_unit: 1,
      application: 2,
      exposure: 3
    }

    before_validation :strip_whitespaces
    validates :name, presence: true
    validates :editable_state, presence: true
    validates :multiple_selection, inclusion: { in: [true, false] }
    validates :name, uniqueness: { scope: :namespace_id }, length: { maximum: 255 }
    validates :description, length: { maximum: 255 }, allow_blank: true
    validate :valid_namespace
    validate :attributes_limit

    scope :by_namespace, ->(namespace) { where(namespace: namespace) }

    private

    def valid_namespace
      return if namespace&.root? && namespace.group_namespace?

      errors.add(:namespace, _('must be a root group.'))
    end

    def attributes_limit
      return unless security_attributes.size > MAX_ATTRIBUTES

      errors.add(:security_attributes, _('cannot have more than 50 attributes per category'))
    end

    def strip_whitespaces
      self.name = name&.strip
      self.description = description&.strip
    end
  end
end
