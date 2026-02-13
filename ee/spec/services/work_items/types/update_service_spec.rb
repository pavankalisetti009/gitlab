# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Types::UpdateService, feature_category: :team_planning do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:project) { create(:project, group: root_group) }
  let(:user) { create(:user, maintainer_of: root_group) }

  let_it_be(:work_item_type) { create(:work_item_type, :issue) }

  let(:container) { root_group }
  let(:params) do
    {
      id: work_item_type.to_global_id.to_s,
      name: 'Updated Work Item Type',
      icon_name: 'updated-icon-name'
    }
  end

  subject(:result) do
    described_class.new(container: container, current_user: user, params: params).execute
  end

  before do
    stub_feature_flags(work_item_configurable_types: true)
  end

  RSpec.shared_examples 'returns success response' do
    it 'returns success response' do
      expect(result).to be_success
    end

    it 'returns work item type' do
      expect(result.payload[:work_item_type]).to eq(work_item_type)
    end
  end

  RSpec.shared_examples 'returns error response' do
    it 'returns error response' do
      expect(result).to be_error
      expect(result.message).to eq(expected_error_message)
    end
  end

  RSpec.shared_examples 'returns feature not available error' do
    let(:expected_error_message) { 'Feature not available' }

    it_behaves_like 'returns error response'
  end

  RSpec.shared_examples 'returns invalid container error' do
    let(:expected_error_message) { 'Work item types can only be updated at the root group or organization level' }

    it_behaves_like 'returns error response'
  end

  describe '#execute' do
    context 'with valid container' do
      context 'when container is an organization' do
        let(:container) { organization }

        it_behaves_like 'returns success response'
      end

      context 'when container is a root group' do
        let(:container) { root_group }

        it_behaves_like 'returns success response'
      end
    end

    context 'with invalid container' do
      context 'when container is nil' do
        let(:container) { nil }

        it_behaves_like 'returns invalid container error'
      end

      context 'when container is a subgroup' do
        let(:container) { subgroup }

        it_behaves_like 'returns invalid container error'
      end

      context 'when container is a project' do
        let(:container) { project }

        it_behaves_like 'returns invalid container error'
      end
    end

    context 'when work item type ID is not provided' do
      let(:params) { super().except(:id) }
      let(:expected_error_message) { 'Work item type not found' }

      it_behaves_like 'returns error response'
    end

    context 'when work item type ID has invalid format' do
      let(:params) { super().merge(id: "invalid-global-id") }
      let(:expected_error_message) { 'Work item type not found' }

      it_behaves_like 'returns error response'
    end

    context 'when work item type does not exist' do
      let(:params) { super().merge(id: "gid://gitlab/WorkItems::Type/999") }
      let(:expected_error_message) { 'Work item type not found' }

      it_behaves_like 'returns error response'
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(work_item_configurable_types: false)
      end

      it_behaves_like 'returns feature not available error'
    end
  end
end
