# frozen_string_literal: true

class AddSchemaVersionToMergeRequest < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = MergeRequest

  private

  def new_mappings
    {
      schema_version: {
        type: 'integer'
      }
    }
  end
end

AddSchemaVersionToMergeRequest.prepend ::Elastic::MigrationObsolete
