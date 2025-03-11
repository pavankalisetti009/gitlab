# frozen_string_literal: true

module SecretsManagement
  class ProjectSecret
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    attribute :project

    attribute :name, :string
    attribute :description, :string
    attribute :branch, :string
    attribute :environment, :string

    validates :project, presence: true
    validates :name, presence: true
    validates :branch, presence: true
    validates :environment, presence: true
    validate :ensure_active_secrets_manager

    delegate :secrets_manager, to: :project

    def ==(other)
      other.is_a?(self.class) && attributes == other.attributes
    end

    private

    def ensure_active_secrets_manager
      errors.add(:base, 'Project secrets manager is not active.') unless project.secrets_manager&.active?
    end
  end
end
