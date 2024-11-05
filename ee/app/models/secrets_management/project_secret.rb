# frozen_string_literal: true

module SecretsManagement
  class ProjectSecret
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :project
    attribute :name, :string
    attribute :description, :string
  end
end
