# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::WorkItem, :elastic_helpers, feature_category: :global_search do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user_project) { create(:project, namespace: create(:namespace)) }
  let_it_be(:work_item) do
    create(:work_item, :opened, labels: [label], namespace: group, milestone: create(:milestone, group: group))
  end

  let_it_be_with_reload(:user_work_item) do
    milestone = create(:milestone, project: user_project)
    create(:work_item, :opened, labels: [label], milestone: milestone,
      project: user_project)
  end

  let_it_be(:project_work_item) do
    create(:work_item, :opened, labels: [label], project: project, milestone: create(:milestone, project: project))
  end

  before do
    allow(Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
  end

  describe '#as_indexed_json' do
    let(:base_work_item_hash) do
      {
        project_id: object.reload.project_id,
        id: object.id,
        iid: object.iid,
        root_namespace_id: object.namespace.root_ancestor.id,
        hashed_root_namespace_id: object.namespace.hashed_root_namespace_id,
        created_at: object.created_at,
        updated_at: object.updated_at,
        title: object.title,
        description: object.description,
        state: object.state,
        upvotes: object.upvotes_count,
        hidden: object.hidden?,
        work_item_type_id: object.work_item_type_id,
        confidential: object.confidential,
        author_id: object.author_id,
        label_ids: [label.id.to_s],
        assignee_id: object.issue_assignee_user_ids,
        due_date: object.due_date,
        traversal_ids: "#{object.namespace.id}-",
        schema_version: described_class::SCHEMA_VERSION,
        routing: object.es_parent,
        type: 'work_item',
        milestone_title: object.milestone&.title,
        milestone_id: object.milestone_id
      }
    end

    subject(:indexed_json) { described_class.new(object.id, object.es_parent).as_indexed_json.with_indifferent_access }

    describe 'user namespace work item' do
      let(:object) { user_work_item }
      let(:expected_hash) do
        base_work_item_hash.merge(
          archived: object.project.archived?,
          traversal_ids: object.namespace.elastic_namespace_ancestry,
          project_visibility_level: object.project.visibility_level,
          issues_access_level: object.project.issues_access_level
        )
      end

      it 'serializes work_item as a hash' do
        expect(indexed_json).to match(expected_hash)
      end
    end

    describe 'group namespace work item' do
      let(:object) { work_item }
      let(:expected_hash) do
        base_work_item_hash.merge(
          root_namespace_id: parent_group.id,
          traversal_ids: "#{parent_group.id}-#{group.id}-",
          namespace_visibility_level: group.visibility_level,
          namespace_id: group.id
        )
      end

      context 'when add_work_item_milestone_data migration has finished' do
        context 'when milestone is present' do
          it 'serializes work_item as a hash' do
            expect(indexed_json).to match(expected_hash)
          end
        end

        context 'when milestone is missing' do
          let_it_be(:work_item_without_milestone) do
            create(:work_item, :opened, labels: [label], namespace: group)
          end

          let(:object) { work_item_without_milestone }

          it 'serializes work_item as a hash without milestone references' do
            expect(indexed_json).to match(expected_hash.except(:milestone_title, :milestone_id))
          end
        end
      end

      context 'when add_work_item_milestone_data migration has not finished' do
        before do
          set_elasticsearch_migration_to(:add_work_item_milestone_data, including: false)
        end

        it 'serializes work_item as a hash without milestone references' do
          expect(indexed_json).to match(expected_hash.except(:milestone_title, :milestone_id))
        end
      end
    end

    describe 'project namespace work item' do
      let(:object) { project_work_item }
      let(:expected_hash) do
        base_work_item_hash.merge(
          root_namespace_id: project_work_item.namespace.root_ancestor.id,
          traversal_ids: project_work_item.namespace.elastic_namespace_ancestry,
          archived: project.archived?,
          project_visibility_level: project.visibility_level,
          issues_access_level: project.issues_access_level
        )
      end

      it 'serializes work_item as a hash' do
        expect(indexed_json).to match(expected_hash)
      end
    end
  end

  describe '#instantiate' do
    let(:work_item_ref) { described_class.new(work_item.id, work_item.es_parent) }

    it 'instantiates work item' do
      new_work_item = described_class.instantiate(work_item_ref.serialize)
      expect(new_work_item.routing).to eq(work_item.es_parent)
      expect(new_work_item.identifier).to eq(work_item.id)
    end
  end

  describe '#serialize' do
    it 'returns serialized string of work item record from class method' do
      expect(described_class.serialize(work_item)).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end

    it 'returns serialized string of work item record from instance method' do
      expect(described_class.new(work_item.id,
        work_item.es_parent).serialize).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end
  end

  describe '#model_klass' do
    it 'returns correct environment based index name from class' do
      expect(described_class.new(work_item.id, work_item.es_parent).model_klass).to eq(WorkItem)
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name from class method' do
      expect(described_class.index).to eq('gitlab-test-work_items')
    end

    it 'returns correct environment based index name from instance method' do
      expect(described_class.new(work_item.id, work_item.es_parent).index_name).to eq('gitlab-test-work_items')
    end
  end
end
