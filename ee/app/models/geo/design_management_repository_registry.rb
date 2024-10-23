# frozen_string_literal: true

module Geo
  class DesignManagementRepositoryRegistry < Geo::BaseRegistry
    include ::Geo::ReplicableRegistry
    include ::Geo::VerifiableRegistry

    MODEL_CLASS = ::DesignManagement::Repository
    MODEL_FOREIGN_KEY = :design_management_repository_id

    ignore_column :force_to_redownload, remove_with: '16.11', remove_after: '2024-03-21'

    belongs_to :design_management_repository, class_name: 'DesignManagement::Repository'
  end
end
