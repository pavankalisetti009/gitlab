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

  describe '#get_groups_with_custom_roles' do
    let(:authorized_groups) { [1, 2, 3] }
    let(:user_abilities) { { 1 => ['read_repository'], 2 => ['read_repository'], 3 => [] } }
    let(:allowed_ids) { [1, 2] }
    let(:group_relation) { instance_double(ActiveRecord::Relation) }
    let(:authz_group) { instance_double(::Authz::Group, permitted: user_abilities) }

    before do
      allow(::Authz::Group).to receive(:new).with(current_user, scope: authorized_groups)
        .and_return(authz_group)
      allow(context).to receive(:allowed_ids_by_ability)
        .with(feature: 'repository', user_abilities: user_abilities)
        .and_return(allowed_ids)
      allow(Group).to receive(:id_in).with(allowed_ids).and_return(group_relation)
    end

    it 'returns empty relation if authorized_groups is empty' do
      expect(context.get_groups_with_custom_roles([])).to be_empty
    end

    it 'returns groups filtered by custom role permissions for repository feature' do
      expect(context.get_groups_with_custom_roles(authorized_groups)).to eq(group_relation)
    end

    it 'calls Authz::Group with current_user and authorized_groups scope' do
      expect(::Authz::Group).to receive(:new).with(current_user, scope: authorized_groups)
        .and_return(authz_group)

      context.get_groups_with_custom_roles(authorized_groups)
    end

    it 'filters groups by repository feature abilities' do
      expect(context).to receive(:allowed_ids_by_ability)
        .with(feature: 'repository', user_abilities: user_abilities)
        .and_return(allowed_ids)

      context.get_groups_with_custom_roles(authorized_groups)
    end
  end

  describe '#get_projects_with_custom_roles' do
    let(:authorized_projects) { [1, 2, 3] }
    let(:user_abilities) { { 1 => ['read_repository'], 2 => ['read_repository'], 3 => [] } }
    let(:allowed_ids) { [1, 2] }
    let(:project_relation) { instance_double(ActiveRecord::Relation) }
    let(:authz_project) { instance_double(::Authz::Project, permitted: user_abilities) }

    before do
      allow(::Authz::Project).to receive(:new).with(current_user, scope: authorized_projects)
        .and_return(authz_project)
      allow(context).to receive(:allowed_ids_by_ability)
        .with(feature: 'repository', user_abilities: user_abilities)
        .and_return(allowed_ids)
      allow(Project).to receive(:id_in).with(allowed_ids).and_return(project_relation)
    end

    it 'returns empty relation if authorized_groups is empty' do
      expect(context.get_projects_with_custom_roles([])).to be_empty
    end

    it 'returns projects filtered by custom role permissions for repository feature' do
      expect(context.get_projects_with_custom_roles(authorized_projects)).to eq(project_relation)
    end

    it 'calls Authz::Project with current_user and authorized_projects scope' do
      expect(::Authz::Project).to receive(:new).with(current_user, scope: authorized_projects)
        .and_return(authz_project)

      context.get_projects_with_custom_roles(authorized_projects)
    end

    it 'filters projects by repository feature abilities' do
      expect(context).to receive(:allowed_ids_by_ability)
        .with(feature: 'repository', user_abilities: user_abilities)
        .and_return(allowed_ids)

      context.get_projects_with_custom_roles(authorized_projects)
    end
  end

  describe '#admin_user?' do
    context 'when user is nil' do
      let(:current_user) { nil }

      it 'returns false' do
        expect(context.admin_user?).to be false
      end
    end

    context 'when user can read all resources' do
      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(true)
      end

      it 'returns true' do
        expect(context.admin_user?).to be true
      end
    end

    context 'when user cannot read all resources' do
      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(false)
      end

      it 'returns false' do
        expect(context.admin_user?).to be false
      end
    end
  end

  describe '#anonymous_user?' do
    context 'when user is nil' do
      let(:current_user) { nil }

      it 'returns true' do
        expect(context.anonymous_user?).to be true
      end
    end

    context 'when user is present' do
      it 'returns false' do
        expect(context.anonymous_user?).to be false
      end
    end
  end
end
