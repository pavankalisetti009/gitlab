# frozen_string_literal: true

module Geo
  class SnippetRepositoryRegistry < Geo::BaseRegistry
    include ::Geo::ReplicableRegistry
    include ::Geo::VerifiableRegistry

    belongs_to :snippet_repository, class_name: 'SnippetRepository'

    def self.model_class
      ::SnippetRepository
    end

    def self.model_foreign_key
      :snippet_repository_id
    end
  end
end
