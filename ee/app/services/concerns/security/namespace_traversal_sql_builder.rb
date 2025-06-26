# frozen_string_literal: true

module Security
  module NamespaceTraversalSqlBuilder
    private

    def namespaces_and_traversal_ids_query_values(namespaces_and_traversal_ids)
      values = namespaces_and_traversal_ids.map do |namespace_id, traversal_ids|
        validated_ids = traversal_ids.map { |id| Integer(id) }
        validated_namespace_id = Integer(namespace_id)

        [
          validated_namespace_id,
          Arel.sql("ARRAY#{validated_ids}::bigint[]")
        ]
      end

      Arel::Nodes::ValuesList.new(values).to_sql
    end
  end
end
