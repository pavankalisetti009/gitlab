# frozen_string_literal: true

module Search
  module Elastic
    module References
      class WorkItem < Reference
        include Search::Elastic::Concerns::DatabaseReference

        SCHEMA_VERSION = 25_21
        DEFAULT_INDEX_ATTRIBUTES = %i[
          id
          iid
          created_at
          updated_at
          title
          description
          author_id
          due_date
          confidential
          project_id
          state
        ].freeze

        override :serialize
        def self.serialize(record)
          new(record.id, record.es_parent).serialize
        end

        override :instantiate
        def self.instantiate(string)
          _, id, routing = delimit(string)

          # this puts the record in the work items index
          new(id, routing)
        end

        override :preload_indexing_data
        def self.preload_indexing_data(refs)
          ids = refs.map(&:identifier)

          records = ::WorkItem.id_in(ids).preload_indexing_data
          records_by_id = records.index_by(&:id)

          refs.each do |ref|
            ref.database_record = records_by_id[ref.identifier.to_i]
          end

          refs
        end

        def self.index
          environment_specific_index_name('work_items')
        end

        attr_reader :identifier, :routing

        def initialize(identifier, routing)
          @identifier = identifier.to_i
          @routing = routing
        end

        override :serialize
        def serialize
          self.class.join_delimited([klass, identifier, routing].compact)
        end

        override :as_indexed_json
        def as_indexed_json
          build_indexed_json(database_record)
        end

        override :index_name
        def index_name
          self.class.index
        end

        def model_klass
          ::WorkItem
        end

        private

        def build_indexed_json(target)
          data = {}

          DEFAULT_INDEX_ATTRIBUTES.each do |attribute|
            data[attribute.to_s] = safely_read_attribute_for_elasticsearch(target, attribute)
          end

          data.merge!(build_extra_data(target))
          data.merge!(build_namespace_data(target))
          data.merge!(build_project_data(target))
          data.merge!(build_milestone_data(target))

          data.stringify_keys
        end

        def build_extra_data(target)
          {
            label_ids: target.label_ids.map(&:to_s),
            hidden: target.hidden?,
            root_namespace_id: target.namespace.root_ancestor.id,
            traversal_ids: target.namespace.elastic_namespace_ancestry,
            hashed_root_namespace_id: target.namespace.hashed_root_namespace_id,
            work_item_type_id: target.work_item_type_id,
            assignee_id: safely_read_attribute_for_elasticsearch(target, :issue_assignee_user_ids),
            upvotes: target.upvotes_count,
            # Schema version. The format is Date.today.strftime('%y_%w')
            # Please update if you're changing the schema of the document
            schema_version: SCHEMA_VERSION,
            type: model_klass.es_type
          }
        end

        def build_namespace_data(target)
          return {} unless target.namespace.group_namespace?

          {
            namespace_visibility_level: target.namespace.visibility_level,
            namespace_id: target.namespace_id
          }
        end

        def build_project_data(target)
          return {} unless target.project.present?

          {
            archived: target.project.archived?,
            project_visibility_level: target.project.visibility_level,
            issues_access_level: target.project.issues_access_level
          }
        end

        def build_milestone_data(target)
          return {} unless target.milestone.present? &&
            ::Elastic::DataMigrationService.migration_has_finished?(:add_work_item_milestone_data)

          {
            milestone_title: target.milestone&.title,
            milestone_id: target.milestone_id
          }
        end
      end
    end
  end
end
