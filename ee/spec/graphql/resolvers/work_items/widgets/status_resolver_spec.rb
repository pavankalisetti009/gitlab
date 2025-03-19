# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::WorkItems::Widgets::StatusResolver, feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:task_type) { create(:work_item_type, :task) }
  let_it_be(:widget_definition) do
    create(:widget_definition, widget_type: :status, work_item_type: task_type, name: 'TesT Widget')
  end

  shared_examples 'returns system defined statuses' do
    it 'fetches allowed statuses for a given work item type' do
      system_defined_statuses = ::WorkItems::Statuses::SystemDefined::Status.all

      expect(resolve_statuses.map(&:name)).to eq(system_defined_statuses.map(&:name))
    end
  end

  shared_examples 'does not return system defined statuses' do
    it 'returns an empty array' do
      expect(resolve_statuses).to eq([])
    end
  end

  describe '#resolve' do
    let(:resource_parent) { group }

    before do
      stub_licensed_features(work_item_status: true)
    end

    context 'with group' do
      it_behaves_like 'returns system defined statuses'
    end

    context 'with project' do
      let(:resource_parent) { project }

      it_behaves_like 'returns system defined statuses'
    end

    context 'with unsupported namespace' do
      let(:resource_parent) { current_user.namespace }

      it_behaves_like 'does not return system defined statuses'
    end

    context 'when work item type is not supported' do
      let_it_be(:epic_type) { create(:work_item_type, :epic) }
      let_it_be(:widget_definition) do
        create(:widget_definition, widget_type: :status, work_item_type: epic_type, name: 'TesT Widget')
      end

      it_behaves_like 'does not return system defined statuses'
    end

    context 'with work_item_status_feature_flag feature flag disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it_behaves_like 'does not return system defined statuses'
    end

    context 'with work_item_status licensed feature disabled' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like 'does not return system defined statuses'
    end
  end

  def resolve_statuses(args = {}, context = { current_user: current_user, resource_parent: resource_parent })
    resolve(described_class, obj: widget_definition, args: args, ctx: context)
  end
end
