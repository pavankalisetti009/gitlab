# frozen_string_literal: true

class Geo::GroupWikiRepositoryRegistry < Geo::BaseRegistry
  include ::Geo::ReplicableRegistry
  include ::Geo::VerifiableRegistry

  MODEL_CLASS = ::GroupWikiRepository
  MODEL_FOREIGN_KEY = :group_wiki_repository_id

  ignore_column :force_to_redownload, remove_with: '16.11', remove_after: '2024-03-21'

  belongs_to :group_wiki_repository, class_name: 'GroupWikiRepository'
end
