# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::AuthorizationContext, feature_category: :global_search do
  let(:current_user) { build(:user) }
  let(:context) { described_class.new(current_user) }

  describe '#get_access_levels_for_feature' do
    it 'returns role required to access the passed feature' do
      expect(context.get_access_levels_for_feature('repository'))
          .to eq({ project: ::Gitlab::Access::GUEST, private_project: ::Gitlab::Access::REPORTER })
    end
  end

  describe '#get_traversal_ids_for_group' do
    it 'returns elastic_namespace_ancestry for a group_id' do
      group = create(:group)

      expect(context.get_traversal_ids_for_group(group.id)).to eq(group.elastic_namespace_ancestry)
    end
  end

  describe '#get_groups_for_user' do
    let(:options) { { search_level: :project, project_ids: [1, 2], features: [:foo], min_access_level: 10 } }
    let(:stubbed_value) { %w[123-456- 789-012-] }

    it 'calls Elastic::Filters.groups_for_user with current_user and min_access_level' do
      expect(context).to receive(:groups_for_user)
        .with(user: current_user, min_access_level: 10).and_return(stubbed_value)
      expect(context.get_groups_for_user(options)).to eq(stubbed_value)
    end
  end

  describe '#get_projects_for_user' do
    let(:options) { { search_level: :project, project_ids: [1, 2], features: [:foo], min_access_level: 10 } }
    let(:stubbed_value) { [1, 2] }

    it 'calls Elastic::Filters.projects_for_user with current_user and options' do
      expect(context).to receive_message_chain(:projects_for_user, :where_exists).and_return(stubbed_value)
      expect(context.get_projects_for_user(options)).to eq(stubbed_value)
    end
  end
end
