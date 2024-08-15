# frozen_string_literal: true

module Elastic
  module Latest
    class MilestoneClassProxy < ApplicationClassProxy
      def elastic_search(query, options: {})
        query_hash = if ::Feature.enabled?(:search_milestone_query_builder, options[:current_user])
                       ::Search::Elastic::MilestoneQueryBuilder.build(query: query, options: options)
                     else
                       options[:in] = %w[title^2 description]
                       options[:no_join_project] = true
                       basic_query_hash(options[:in], query, options).tap do |temp_query_hash|
                         type_filter = [{ terms: { _name: context.name(:doc, :is_a, es_type), type: [es_type] } }]
                         context.name(:milestone) do
                           temp_query_hash = context.name(:related) { project_ids_filter(temp_query_hash, options) }

                           if archived_filter_applicable?(options)
                             temp_query_hash = context.name(:archived) { archived_filter(temp_query_hash) }
                           end
                         end

                         temp_query_hash[:query][:bool][:filter] ||= []
                         temp_query_hash[:query][:bool][:filter] += type_filter
                       end
                     end

        search(query_hash, options)
      end

      def preload_indexing_data(relation)
        relation.preload_for_indexing
      end

      private

      def archived_filter_applicable?(options)
        !(options[:include_archived] || options[:search_scope] == 'project')
      end
    end
  end
end
