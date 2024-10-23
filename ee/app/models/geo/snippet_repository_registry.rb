# frozen_string_literal: true

class Geo::SnippetRepositoryRegistry < Geo::BaseRegistry
  include ::Geo::ReplicableRegistry
  include ::Geo::VerifiableRegistry

  MODEL_CLASS = ::SnippetRepository
  MODEL_FOREIGN_KEY = :snippet_repository_id

  ignore_column :force_to_redownload, remove_with: '16.11', remove_after: '2024-03-21'

  belongs_to :snippet_repository, class_name: 'SnippetRepository'
end
