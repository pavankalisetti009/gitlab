# frozen_string_literal: true

class AddSchemaVersionToNote < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = Note

  private

  def new_mappings
    {
      schema_version: {
        type: 'integer'
      }
    }
  end
end

AddSchemaVersionToNote.prepend ::Elastic::MigrationObsolete
