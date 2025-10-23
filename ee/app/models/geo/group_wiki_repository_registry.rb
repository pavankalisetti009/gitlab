# frozen_string_literal: true

module Geo
  class GroupWikiRepositoryRegistry < Geo::BaseRegistry
    include ::Geo::ReplicableRegistry
    include ::Geo::VerifiableRegistry

    belongs_to :group_wiki_repository, class_name: 'GroupWikiRepository'

    def self.model_class
      ::GroupWikiRepository
    end

    def self.model_foreign_key
      :group_wiki_repository_id
    end
  end
end
