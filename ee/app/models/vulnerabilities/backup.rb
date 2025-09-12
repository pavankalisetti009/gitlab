# frozen_string_literal: true

module Vulnerabilities
  class Backup < SecApplicationRecord
    include PartitionedTable
    include BulkInsertSafe

    class << self
      attr_reader :column_mapping, :original_model

      def backup_of(original_model, column_mapping: {})
        @original_model = original_model
        @column_mapping = column_mapping
      end

      def column_mappings
        @column_mappings ||= @column_mapping.merge(project_id: :project_id)
      end
    end

    self.abstract_class = true
    self.table_name_prefix = 'backup_'

    belongs_to :project, optional: false

    attribute :data, Gitlab::Database::Type::JsonPgSafe.new(replace_with: '\\\\\u0000')

    validates :original_record_identifier, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :data, presence: true, json_schema: { filename: 'vulnerability_backup_data' } # rubocop:disable Database/JsonbSizeLimit -- We can't add a limit for this attribute

    def original_data
      @original_data ||= data.each_with_object({}) do |(key, value), memo|
        memo[key] = deserialize_attribute_to_original(key, value)
      end
    end

    private

    delegate :original_model, to: :'self.class', private: true

    def deserialize_attribute_to_original(attribute, value)
      type_caster_for(attribute).deserialize(value)
    end

    def type_caster_for(attribute)
      column = original_model.columns_hash[attribute]

      connection.lookup_cast_type_from_column(column)
    end
  end
end
